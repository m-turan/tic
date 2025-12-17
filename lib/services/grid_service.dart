import 'dart:math';
import '../models/grid.dart';
import 'player_service.dart';
import 'normalization_service.dart';

class GridService {
  static final GridService _instance = GridService._internal();
  factory GridService() => _instance;
  GridService._internal();

  final PlayerService _playerService = PlayerService();
  final NormalizationService _normalizer = NormalizationService();
  final Random _random = Random();

  // İzin verilen takımlar
  static const List<String> allowedTeams = [
    'PSG',
    'Real Madrid',
    'Atletico Madrid',
    'Barcelona',
    'Bayern München',
    'Borussia Dortmund',
    'Arsenal',
    'Chelsea',
    'Man United',
    'Man City',
    'Tottenham',
    'Ajax',
    'Benfica',
    'Galatasaray',
    'Fenerbahçe',
    'Beşiktaş',
    'Juventus',
    'Milan',
    'Inter',
    'Liverpool',
    'Marseille',
  ];

  // İzin verilen ülkeler
  static const List<String> allowedCountries = [
    'Germany',
    'England',
    'Turkey',
    'Netherlands',
    'Nigeria',
    'France',
    'Portugal',
    'Spain',
    'Argentina',
    'Brazil',
    'Arjantin',
    'Brazilya',
  ];

  Future<Grid> generateSolvableGrid() async {
    // 1. Rastgele bir ülke seç
    final country = allowedCountries[_random.nextInt(allowedCountries.length)];

    // 2. Bu ülkenin oyuncularını bul
    final countryPlayers = await _playerService.getPlayersByCountry(country);

    // 3. Bu oyuncuların oynadığı takımları bul
    final Set<String> availableTeams = {};
    for (var player in countryPlayers) {
      final normalizedTeam = _normalizer.normalize(player.takim);
      // Normalize edilmiş takımı geri çevir
      for (var team in allowedTeams) {
        if (_normalizer.matches(team, player.takim)) {
          availableTeams.add(team);
          break;
        }
      }
    }

    // 4. En az 3 takım yoksa rastgele takımlar ekle
    final List<String> selectedTeams = availableTeams.toList();
    while (selectedTeams.length < 5) {
      final randomTeam = allowedTeams[_random.nextInt(allowedTeams.length)];
      if (!selectedTeams.contains(randomTeam)) {
        selectedTeams.add(randomTeam);
      }
    }

    // 5. 5 takım seç
    selectedTeams.shuffle(_random);
    final teams = selectedTeams.take(5).toList();

    // 6. Ülkeyi satır veya sütuna yerleştir (rastgele)
    final isCountryInRows = _random.nextBool();
    final List<String> rows = [];
    final List<String> cols = [];

    if (isCountryInRows) {
      rows.add(country);
      rows.addAll(teams.take(2));
      cols.addAll(teams.skip(2).take(3));
    } else {
      cols.add(country);
      cols.addAll(teams.take(2));
      rows.addAll(teams.skip(2).take(3));
    }

    return Grid(
      rows: rows,
      cols: cols,
      isCountryInRows: isCountryInRows,
    );
  }

  String getImagePath(String name, String type) {
    // Özel eşleştirmeler
    final Map<String, String> specialMappings = {
      'Bayern München': 'bayern_munih',
      'Man City': 'man_city',
      'Man United': 'man_united',
      'Atletico Madrid': 'atletico_madrid',
      'Borussia Dortmund': 'borussia_dortmund',
      'Real Madrid': 'real_madrid',
      'Marseille': 'marsilya',
    };

    String baseName = specialMappings[name] ?? _normalizer.slugify(name);

    if (type == 'team') {
      return 'assets/team_images/$baseName.png';
    } else if (type == 'country') {
      return 'assets/country_images/$baseName.png';
    } else {
      return 'assets/player_images/$baseName.webp';
    }
  }
}

