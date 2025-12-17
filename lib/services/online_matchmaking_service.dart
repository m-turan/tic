import 'dart:async';
import 'dart:math';
import 'firebase_realtime_service.dart';

class OnlineMatchmakingService {
  static final OnlineMatchmakingService _instance = OnlineMatchmakingService._internal();
  factory OnlineMatchmakingService() => _instance;
  OnlineMatchmakingService._internal();

  final FirebaseRealtimeService _firebase = FirebaseRealtimeService();
  final Random _random = Random();
  StreamSubscription<Map<String, dynamic>?>? _queueSubscription;
  String? _currentPlayerId;
  
  String? get currentPlayerId => _currentPlayerId;

  String _generatePlayerId() {
    return 'player_${DateTime.now().millisecondsSinceEpoch}_${_random.nextInt(10000)}';
  }

  Stream<Map<String, dynamic>?> searchMatch() {
    _currentPlayerId = _generatePlayerId();
    final playerId = _currentPlayerId!;
    final controller = StreamController<Map<String, dynamic>?>.broadcast();
    StreamSubscription? matchesSubscription;

    _startSearch(playerId, controller, (sub) {
      matchesSubscription = sub;
    });

    controller.onCancel = () {
      matchesSubscription?.cancel();
      stopSearching();
    };

    return controller.stream;
  }

  Future<void> _startSearch(
    String playerId,
    StreamController<Map<String, dynamic>?> controller,
    Function(StreamSubscription) setMatchesSubscription,
  ) async {
    print('🔍 [Matchmaking] Player $playerId searching for match...');
    
    // Önce kuyruğu kontrol et
    final queueData = await _firebase.get('matchmaking/queue');
    print('🔍 [Matchmaking] Current queue: ${queueData?.keys.toList()}');
    
    if (queueData != null && queueData.isNotEmpty) {
      // Bekleyen oyuncu var - eşleştir
      for (var waitingPlayerId in queueData.keys) {
        if (waitingPlayerId != playerId) {
          print('✅ [Matchmaking] Found waiting player: $waitingPlayerId');
          final matchId = 'match_${DateTime.now().millisecondsSinceEpoch}_${_random.nextInt(10000)}';
          await _createMatch(waitingPlayerId, playerId, matchId);
          print('🎮 [Matchmaking] Match created: $matchId');
          controller.add({'matchId': matchId, 'player1': waitingPlayerId, 'player2': playerId});
          return;
        }
      }
    }

    // Kendini kuyruğa ekle
    print('⏳ [Matchmaking] No waiting players, adding $playerId to queue...');
    await _firebase.set('matchmaking/queue/$playerId', {
      'joinedAt': DateTime.now().millisecondsSinceEpoch,
    });
    print('✅ [Matchmaking] Added to queue, waiting for another player...');

    // Matches'i gerçek zamanlı dinle (eğer başka biri eşleştirdiyse)
    final matchesSub = _firebase.listen('matches').listen((matchesData) {
      if (matchesData != null) {
        for (var matchEntry in matchesData.entries) {
          final matchData = matchEntry.value as Map<String, dynamic>;
          if (matchData['player1'] == playerId || matchData['player2'] == playerId) {
            print('🎮 [Matchmaking] Match found in matches: ${matchEntry.key}');
            controller.add({
              'matchId': matchEntry.key,
              'player1': matchData['player1'],
              'player2': matchData['player2'],
            });
            return;
          }
        }
      }
    }, onError: (error) {
      print('❌ [Matchmaking] Matches listen error: $error');
      controller.addError(error);
    });
    
    setMatchesSubscription(matchesSub);

    // Kuyruğu da gerçek zamanlı dinle
    Set<String> lastQueuePlayers = {};
    _queueSubscription = _firebase.listen('matchmaking/queue').listen((data) async {
      if (data != null && data.isNotEmpty) {
        final currentQueuePlayers = data.keys.toSet();
        
        // Sadece queue değiştiğinde log bas (yeni oyuncu geldiğinde)
        if (currentQueuePlayers != lastQueuePlayers) {
          lastQueuePlayers = currentQueuePlayers;
          print('👀 [Matchmaking] Queue updated: ${data.keys.toList()}');
        }
        
        // Kendisi hariç başka bir oyuncu var mı kontrol et
        for (var waitingPlayerId in data.keys) {
          if (waitingPlayerId != playerId) {
            print('✅ [Matchmaking] Found new player in queue: $waitingPlayerId');
            final matchId = 'match_${DateTime.now().millisecondsSinceEpoch}_${_random.nextInt(10000)}';
            await _createMatch(waitingPlayerId, playerId, matchId);
            print('🎮 [Matchmaking] Match created: $matchId');
            await stopSearching();
            matchesSub.cancel();
            controller.add({'matchId': matchId, 'player1': waitingPlayerId, 'player2': playerId});
            return;
          }
        }
      } else {
        lastQueuePlayers = {};
      }
    }, onError: (error) {
      print('❌ [Matchmaking] Queue listen error: $error');
      controller.addError(error);
    });
  }

  Future<void> _createMatch(String player1Id, String player2Id, String matchId) async {
    print('🔨 [Matchmaking] Creating match: $matchId');
    print('   Player1: $player1Id');
    print('   Player2: $player2Id');
    
    // Her iki oyuncuyu da kuyruktan çıkar
    await _firebase.delete('matchmaking/queue/$player1Id');
    await _firebase.delete('matchmaking/queue/$player2Id');
    print('✅ [Matchmaking] Removed players from queue');

    // Match oluştur
    final success = await _firebase.set('matches/$matchId', {
      'player1': player1Id,
      'player2': player2Id,
      'player1Ready': false,
      'player2Ready': false,
      'createdAt': DateTime.now().millisecondsSinceEpoch,
    });
    
    if (success) {
      print('✅ [Matchmaking] Match created successfully');
    } else {
      print('❌ [Matchmaking] Failed to create match');
    }
  }

  Future<void> stopSearching() async {
    _queueSubscription?.cancel();
    if (_currentPlayerId != null) {
      await _firebase.delete('matchmaking/queue/$_currentPlayerId');
      _currentPlayerId = null;
    }
  }
}

