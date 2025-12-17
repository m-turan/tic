import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode, defaultTargetPlatform;
import 'package:flutter/material.dart';
import '../models/player.dart';
import 'normalization_service.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  Database? _database;
  final NormalizationService _normalizer = NormalizationService();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path;
    if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.macOS)) {
      path = join(await getDatabasesPath(), 'players.db');
    } else {
      path = join(await getDatabasesPath(), 'players.db');
    }

    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE players (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        oyuncu_adi TEXT NOT NULL,
        takim TEXT NOT NULL,
        milli_takim TEXT NOT NULL,
        fotograf_url TEXT NOT NULL,
        normalized_name TEXT NOT NULL,
        normalized_team TEXT NOT NULL,
        normalized_country TEXT NOT NULL
      )
    ''');

    // Index'ler
    await db.execute('''
      CREATE INDEX idx_normalized_name ON players(normalized_name)
    ''');
    await db.execute('''
      CREATE INDEX idx_normalized_team ON players(normalized_team)
    ''');
    await db.execute('''
      CREATE INDEX idx_normalized_country ON players(normalized_country)
    ''');
    await db.execute('''
      CREATE INDEX idx_team_country ON players(normalized_team, normalized_country)
    ''');
  }

  Future<void> migrateFromJson({bool force = false}) async {
    final db = await database;
    final count = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM players'),
    );

    // Veritabanı boşsa veya force ise migration yap
    if (count == null || count == 0 || force) {
      if (force || count == 0) {
        debugPrint('Database is empty or force migration requested. Starting migration...');
        if (force) {
          debugPrint('Force migration: Dropping existing table...');
          await db.execute('DROP TABLE IF EXISTS players');
          await _onCreate(db, 1);
        }
      } else {
        debugPrint('Database already has data, skipping migration');
        return;
      }
    } else {
      // Veritabanında veri var ama takım isimleri boş mu kontrol et
      final teamCheckResult = await db.rawQuery(
        'SELECT COUNT(*) as count FROM players WHERE takim IS NOT NULL AND takim != ?',
        [''],
      );
      final hasValidTeams = (Sqflite.firstIntValue(teamCheckResult) ?? 0) > 0;
      
      if (!hasValidTeams) {
        debugPrint('Database has data but team names are empty. Re-migrating...');
        await db.execute('DROP TABLE IF EXISTS players');
        await _onCreate(db, 1);
      } else {
        debugPrint('Database already has data, skipping migration');
        return;
      }
    }

    try {
      final String jsonString = await rootBundle.loadString('assets/oyuncu.json');
      
      // JSON array formatını parse et
      final List<dynamic> jsonArray = json.decode(jsonString) as List<dynamic>;
      
      final List<Map<String, dynamic>> players = [];
      for (var item in jsonArray) {
        try {
          if (item is Map<String, dynamic>) {
            // Fotoğraf URL'ine assets/ prefix'i ekle
            String? fotografUrl = item['fotograf_url'] as String?;
            if (fotografUrl != null && 
                fotografUrl != 'Bilinmiyor' && 
                !fotografUrl.startsWith('assets/')) {
              fotografUrl = 'assets/$fotografUrl';
            } else if (fotografUrl == null) {
              fotografUrl = 'Bilinmiyor';
            }
            
            final player = Player(
              oyuncuAdi: item['oyuncu_adi'] as String? ?? '',
              takim: item['takim'] as String? ?? '',
              milliTakim: item['milli_takim'] as String? ?? '',
              fotografUrl: fotografUrl,
            );
            
            players.add({
              'oyuncu_adi': player.oyuncuAdi,
              'takim': player.takim,
              'milli_takim': player.milliTakim,
              'fotograf_url': player.fotografUrl,
              'normalized_name': _normalizer.normalize(player.oyuncuAdi),
              'normalized_team': _normalizer.normalize(player.takim),
              'normalized_country': _normalizer.normalize(player.milliTakim),
            });
          }
        } catch (e) {
          debugPrint('Error parsing player: $item - $e');
        }
      }

      // Batch insert
      final batch = db.batch();
      for (var player in players) {
        batch.insert('players', player);
      }
      await batch.commit(noResult: true);

      debugPrint('Migrated ${players.length} players to database');
    } catch (e) {
      debugPrint('Error migrating from JSON: $e');
      rethrow;
    }
  }

  Map<String, dynamic> _parseJsonLine(String line) {
    // Basit JSON parsing (gerçek formatına göre düzenlenebilir)
    final Map<String, dynamic> result = {};
    
    // Örnek: {"oyuncu_adi": "Messi", "takim": "Barcelona", ...}
    final regex = RegExp(r'"([^"]+)":\s*"([^"]+)"');
    final matches = regex.allMatches(line);
    
    for (var match in matches) {
      final key = match.group(1) ?? '';
      final value = match.group(2) ?? '';
      
      if (key == 'oyuncu_adi' || key == 'oyuncuAdi') {
        result['oyuncu_adi'] = value;
      } else if (key == 'takim') {
        result['takim'] = value;
      } else if (key == 'milli_takim' || key == 'milliTakim') {
        result['milli_takim'] = value;
      } else if (key == 'fotograf_url' || key == 'fotografUrl') {
        // Fotoğraf URL'ine assets/ prefix'i ekle
        if (value != 'Bilinmiyor' && !value.startsWith('assets/')) {
          result['fotograf_url'] = 'assets/$value';
        } else {
          result['fotograf_url'] = value;
        }
      }
    }
    
    return result;
  }

  Future<List<Player>> getAllPlayers() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('players');
    return maps.map((map) => Player.fromDatabase(map)).toList();
  }

  Future<List<Player>> searchPlayers(String query) async {
    final db = await database;
    
    if (query.isEmpty) {
      // Tüm oyuncuları getir (limit yok)
      final List<Map<String, dynamic>> maps = await db.query('players');
      return maps.map((map) => Player.fromDatabase(map)).toList();
    }
    
    final normalizedQuery = _normalizer.normalize(query);
    final List<Map<String, dynamic>> maps = await db.query(
      'players',
      where: 'normalized_name LIKE ?',
      whereArgs: ['%$normalizedQuery%'],
      limit: 500, // Arama için limit artırıldı
    );
    return maps.map((map) => Player.fromDatabase(map)).toList();
  }

  Future<List<Player>> getPlayersByTeam(String team) async {
    final db = await database;
    final normalizedTeam = _normalizer.normalize(team);
    final List<Map<String, dynamic>> maps = await db.query(
      'players',
      where: 'normalized_team = ?',
      whereArgs: [normalizedTeam],
    );
    
    if (kDebugMode && maps.isEmpty) {
      // Debug: Veritabanındaki tüm takımları göster
      final allTeams = await db.query(
        'players',
        columns: ['DISTINCT takim', 'normalized_team'],
        limit: 20,
      );
      debugPrint('No players found for team "$team" (normalized: "$normalizedTeam")');
      debugPrint('Available teams in DB (first 20): ${allTeams.map((t) => '${t['takim']} (${t['normalized_team']})').toList()}');
    }
    
    return maps.map((map) => Player.fromDatabase(map)).toList();
  }

  Future<List<Player>> getPlayersByCountry(String country) async {
    final db = await database;
    final normalizedCountry = _normalizer.normalize(country);
    final List<Map<String, dynamic>> maps = await db.query(
      'players',
      where: 'normalized_country = ?',
      whereArgs: [normalizedCountry],
    );
    return maps.map((map) => Player.fromDatabase(map)).toList();
  }

  Future<List<Player>> getPlayersByTeamAndCountry(String team, String country) async {
    final db = await database;
    final normalizedTeam = _normalizer.normalize(team);
    final normalizedCountry = _normalizer.normalize(country);
    
    if (kDebugMode) {
      debugPrint('getPlayersByTeamAndCountry: team="$team" (normalized: "$normalizedTeam"), country="$country" (normalized: "$normalizedCountry")');
    }
    
    final List<Map<String, dynamic>> maps = await db.query(
      'players',
      where: 'normalized_team = ? AND normalized_country = ?',
      whereArgs: [normalizedTeam, normalizedCountry],
    );
    
    if (kDebugMode) {
      debugPrint('Found ${maps.length} players for team="$team" × country="$country"');
      if (maps.isEmpty) {
        // Debug: Benzer takımları kontrol et
        final allTeams = await db.query(
          'players',
          columns: ['DISTINCT takim', 'normalized_team'],
          where: 'normalized_country = ?',
          whereArgs: [normalizedCountry],
          limit: 10,
        );
        debugPrint('Available teams for country "$country": ${allTeams.map((t) => t['takim']).toList()}');
      }
    }
    
    return maps.map((map) => Player.fromDatabase(map)).toList();
  }

  Future<List<Player>> getPlayersByTwoTeams(String team1, String team2) async {
    final db = await database;
    final normalizedTeam1 = _normalizer.normalize(team1);
    final normalizedTeam2 = _normalizer.normalize(team2);
    
    if (kDebugMode) {
      debugPrint('getPlayersByTwoTeams: team1="$team1" (normalized: "$normalizedTeam1"), team2="$team2" (normalized: "$normalizedTeam2")');
    }
    
    // Aynı oyuncunun her iki takımda da oynamış olması gerekiyor
    // Bu durumda iki ayrı sorgu yapıp kesişim alıyoruz
    final players1 = await getPlayersByTeam(team1);
    final players2 = await getPlayersByTeam(team2);
    
    if (kDebugMode) {
      debugPrint('Team1 "$team1": ${players1.length} players, Team2 "$team2": ${players2.length} players');
    }
    
    // İsim bazında kesişim
    final normalizedNames1 = players1.map((p) => _normalizer.normalize(p.oyuncuAdi)).toSet();
    final normalizedNames2 = players2.map((p) => _normalizer.normalize(p.oyuncuAdi)).toSet();
    final commonNames = normalizedNames1.intersection(normalizedNames2);
    
    if (kDebugMode) {
      debugPrint('Common players between "$team1" and "$team2": ${commonNames.length}');
    }
    
    // Ortak isimlere sahip oyuncuları döndür (team1'den)
    return players1.where((p) => commonNames.contains(_normalizer.normalize(p.oyuncuAdi))).toList();
  }
}

