import 'package:flutter/foundation.dart';
import '../models/player.dart';
import 'player_service.dart';
import 'normalization_service.dart';

class ValidationService {
  static final ValidationService _instance = ValidationService._internal();
  factory ValidationService() => _instance;
  ValidationService._internal();

  final PlayerService _playerService = PlayerService();
  final NormalizationService _normalizer = NormalizationService();

  Future<bool> validatePlayer(String playerName, String rowItem, String colItem) async {
    final player = await findPlayer(playerName, rowItem, colItem);
    return player != null;
  }

  /// Seçilen Player objesinin kombinasyona uygun olup olmadığını kontrol eder
  Future<bool> validateSelectedPlayer(Player player, String rowItem, String colItem) async {
    // Ülke kontrolü
    const allowedCountries = [
      'Germany', 'England', 'Turkey', 'Netherlands', 'Nigeria',
      'France', 'Portugal', 'Spain', 'Argentina', 'Brazil',
      'Arjantin', 'Brazilya'
    ];

    final isRowCountry = allowedCountries.contains(rowItem);
    final isColCountry = allowedCountries.contains(colItem);

    bool result = false;

    if (isRowCountry && !isColCountry) {
      // Ülke × Takım: Oyuncu hem ülkede hem takımda olmalı
      // Veritabanından bu kombinasyon için oyuncuları kontrol et
      final validPlayers = await _playerService.getPlayersByTeamAndCountry(colItem, rowItem);
      final normalizedPlayerName = _normalizer.normalize(player.oyuncuAdi);
      
      for (var p in validPlayers) {
        if (_normalizer.matches(p.oyuncuAdi, normalizedPlayerName)) {
          result = true;
          break;
        }
      }
      
      if (kDebugMode) {
        debugPrint('Validation [Ülke × Takım]: Player=${player.oyuncuAdi}, '
            'Row=$rowItem, Col=$colItem, '
            'Found ${validPlayers.length} valid players, Result=$result');
      }
    } else if (!isRowCountry && isColCountry) {
      // Takım × Ülke: Oyuncu hem takımda hem ülkede olmalı
      // Veritabanından bu kombinasyon için oyuncuları kontrol et
      final validPlayers = await _playerService.getPlayersByTeamAndCountry(rowItem, colItem);
      final normalizedPlayerName = _normalizer.normalize(player.oyuncuAdi);
      
      for (var p in validPlayers) {
        if (_normalizer.matches(p.oyuncuAdi, normalizedPlayerName)) {
          result = true;
          break;
        }
      }
      
      if (kDebugMode) {
        debugPrint('Validation [Takım × Ülke]: Player=${player.oyuncuAdi}, '
            'Row=$rowItem, Col=$colItem, '
            'Found ${validPlayers.length} valid players, Result=$result');
      }
    } else if (!isRowCountry && !isColCountry) {
      // Takım × Takım: Oyuncu her iki takımda da oynamış olmalı
      // Veritabanından kontrol et
      final playersByTwoTeams = await _playerService.getPlayersByTwoTeams(rowItem, colItem);
      final normalizedPlayerName = _normalizer.normalize(player.oyuncuAdi);
      
      for (var p in playersByTwoTeams) {
        final normalizedPName = _normalizer.normalize(p.oyuncuAdi);
        if (normalizedPName == normalizedPlayerName) {
          result = true;
          break;
        }
      }
      
      if (kDebugMode) {
        debugPrint('Validation [Takım × Takım]: Player=${player.oyuncuAdi}, '
            'Row=$rowItem, Col=$colItem, '
            'Found ${playersByTwoTeams.length} players, Result=$result');
      }
    } else {
      // Ülke × Ülke - geçersiz
      result = false;
    }

    return result;
  }

  Future<Player?> findPlayer(String playerName, String rowItem, String colItem) async {
    // Ülke kontrolü
    const allowedCountries = [
      'Germany', 'England', 'Turkey', 'Netherlands', 'Nigeria',
      'France', 'Portugal', 'Spain', 'Argentina', 'Brazil',
      'Arjantin', 'Brazilya'
    ];

    final isRowCountry = allowedCountries.contains(rowItem);
    final isColCountry = allowedCountries.contains(colItem);

    List<Player> candidates = [];

    if (isRowCountry && !isColCountry) {
      // Ülke × Takım
      candidates = await _playerService.getPlayersByTeamAndCountry(colItem, rowItem);
    } else if (!isRowCountry && isColCountry) {
      // Takım × Ülke
      candidates = await _playerService.getPlayersByTeamAndCountry(rowItem, colItem);
    } else if (!isRowCountry && !isColCountry) {
      // Takım × Takım
      candidates = await _playerService.getPlayersByTwoTeams(rowItem, colItem);
    } else {
      // Ülke × Ülke - geçersiz
      return null;
    }

    // İsim eşleştirmesi
    final normalizedQuery = _normalizer.normalize(playerName);
    
    // Exact match
    for (var player in candidates) {
      if (_normalizer.matches(player.oyuncuAdi, playerName)) {
        return player;
      }
    }

    // Contains match (en az 3 karakter)
    if (normalizedQuery.length >= 3) {
      final queryWords = normalizedQuery.split(' ').where((w) => w.isNotEmpty).toList();
      
      for (var player in candidates) {
        final normalizedName = _normalizer.normalize(player.oyuncuAdi);
        final nameWords = normalizedName.split(' ').where((w) => w.isNotEmpty).toList();
        
        // Tüm query kelimeleri name'de TAM KELİME OLARAK veya BAŞLANGIÇTA geçmeli
        bool allWordsMatch = true;
        for (var queryWord in queryWords) {
          bool wordMatches = false;
          for (var nameWord in nameWords) {
            if (nameWord == queryWord || nameWord.startsWith(queryWord)) {
              wordMatches = true;
              break;
            }
          }
          if (!wordMatches) {
            allWordsMatch = false;
            break;
          }
        }
        
        if (allWordsMatch) {
          return player;
        }
      }
    }

    return null;
  }
}


