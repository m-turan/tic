import '../models/player.dart';
import 'database_service.dart';
import 'normalization_service.dart';

class PlayerService {
  static final PlayerService instance = PlayerService._internal();
  factory PlayerService() => instance;
  PlayerService._internal();

  final DatabaseService _dbService = DatabaseService();
  final NormalizationService _normalizer = NormalizationService();

  List<Player>? _allPlayers;
  final Map<String, List<Player>> _searchCache = {};
  final Map<String, List<Player>> _teamCache = {};
  final Map<String, List<Player>> _countryCache = {};

  /// Cache'leri temizler (yeni veri yüklendiğinde kullanılabilir)
  void clearCache() {
    _searchCache.clear();
    _teamCache.clear();
    _countryCache.clear();
  }

  Future<void> initialize({bool forceMigration = false}) async {
    await _dbService.migrateFromJson(force: forceMigration);
    await loadPlayers();
  }

  Future<void> loadPlayers() async {
    _allPlayers = await _dbService.getAllPlayers();
  }

  Future<List<Player>> searchPlayers(String query) async {
    if (query.isEmpty) {
      // İlk yüklemede tüm oyuncuları yükle ama unique yap
      if (_allPlayers == null) {
        await loadPlayers();
      }
      // Performans için ilk 500 oyuncuyu göster, arama yapıldığında tüm sonuçlar gösterilecek
      final limitedPlayers = (_allPlayers ?? []).take(500).toList();
      return _makeUniqueByName(limitedPlayers);
    }

    if (_searchCache.containsKey(query)) {
      return _searchCache[query]!;
    }

    final results = await _dbService.searchPlayers(query);
    final uniqueResults = _makeUniqueByName(results);
    _searchCache[query] = uniqueResults;
    return uniqueResults;
  }

  /// Aynı isimli oyuncuları tek bir sonuç olarak döndürür
  List<Player> _makeUniqueByName(List<Player> players) {
    final Map<String, Player> uniquePlayers = {};
    
    for (var player in players) {
      final normalizedName = _normalizer.normalize(player.oyuncuAdi);
      
      // Eğer bu isim daha önce eklenmemişse ekle
      if (!uniquePlayers.containsKey(normalizedName)) {
        uniquePlayers[normalizedName] = player;
      }
    }
    
    return uniquePlayers.values.toList();
  }

  Future<List<Player>> getPlayersByTeam(String team) async {
    final normalizedTeam = _normalizer.normalize(team);
    if (_teamCache.containsKey(normalizedTeam)) {
      return _teamCache[normalizedTeam]!;
    }

    final results = await _dbService.getPlayersByTeam(team);
    final uniqueResults = _makeUniqueByName(results);
    _teamCache[normalizedTeam] = uniqueResults;
    return uniqueResults;
  }

  Future<List<Player>> getPlayersByCountry(String country) async {
    final normalizedCountry = _normalizer.normalize(country);
    if (_countryCache.containsKey(normalizedCountry)) {
      return _countryCache[normalizedCountry]!;
    }

    final results = await _dbService.getPlayersByCountry(country);
    final uniqueResults = _makeUniqueByName(results);
    _countryCache[normalizedCountry] = uniqueResults;
    return uniqueResults;
  }

  Future<List<Player>> getPlayersByTeamAndCountry(String team, String country) async {
    final results = await _dbService.getPlayersByTeamAndCountry(team, country);
    return _makeUniqueByName(results);
  }

  Future<List<Player>> getPlayersByTwoTeams(String team1, String team2) async {
    final results = await _dbService.getPlayersByTwoTeams(team1, team2);
    return _makeUniqueByName(results);
  }
}

