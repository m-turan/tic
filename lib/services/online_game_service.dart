import 'dart:async';
import '../models/game_state.dart';
import '../models/grid.dart';
import '../models/player.dart';
import 'firebase_realtime_service.dart';
import 'grid_service.dart';
import 'validation_service.dart';

class OnlineGameService {
  static final OnlineGameService _instance = OnlineGameService._internal();
  factory OnlineGameService() => _instance;
  OnlineGameService._internal();

  final FirebaseRealtimeService _firebase = FirebaseRealtimeService();
  final GridService _gridService = GridService();
  final ValidationService _validationService = ValidationService();
  StreamSubscription<Map<String, dynamic>?>? _gameStateSubscription;
  Function(GameState)? _gameStateUpdateCallback;

  Future<void> startOnlineGame(String matchId, String playerId, int playerNumber) async {
    await _initializeGameState(matchId, playerNumber);
    // Real-time dinleme başlat
    _listenToGameState(matchId);
  }

  Future<void> _initializeGameState(String matchId, int playerNumber) async {
    if (playerNumber == 1) {
      // Player1: Grid oluştur
      final grid = await _gridService.generateSolvableGrid();
      final board = List.generate(3, (_) => List.generate(3, (_) => CellData()));

      final gameState = GameState(
        grid: grid,
        board: board,
        currentPlayer: 1,
        player1Score: 0,
        player2Score: 0,
      );

      await _firebase.set('matches/$matchId/gameState', gameState.toJson());
    } else {
      // Player2: Grid'in oluşturulmasını bekle
      while (true) {
        final gameStateData = await _firebase.get('matches/$matchId/gameState');
        if (gameStateData != null) {
          break;
        }
        await Future.delayed(const Duration(seconds: 1));
      }
    }
  }

  Future<void> startNewGame(String matchId, int playerNumber) async {
    print('🎮 [OnlineGameService] Starting new game: matchId=$matchId, playerNumber=$playerNumber');
    
    // Yeni grid ile oyunu başlat
    if (playerNumber == 1) {
      // Player1: Yeni grid oluştur
      print('🎲 [OnlineGameService] Player1 generating new grid...');
      
      // Yeni oyun = yeni grid + sıfırlanmış board + sıfırlanmış winner
      // Skorlar korunuyor (oyun devam ediyor)
      final currentGameState = await getGameState(matchId);
      final currentPlayer1Score = currentGameState?.player1Score ?? 0;
      final currentPlayer2Score = currentGameState?.player2Score ?? 0;
      
      final grid = await _gridService.generateSolvableGrid();
      final board = List.generate(3, (_) => List.generate(3, (_) => CellData()));

      final gameState = GameState(
        grid: grid, // YENİ GRID
        board: board, // SIFIRLANMIŞ BOARD
        currentPlayer: 1,
        player1Score: currentPlayer1Score, // Skorlar korunuyor
        player2Score: currentPlayer2Score,
        winner: null, // Winner sıfırlanıyor
        winningCells: null,
      );

      print('💾 [OnlineGameService] Saving new gameState to Firebase...');
      final success = await _firebase.set('matches/$matchId/gameState', gameState.toJson());
      if (success) {
        print('✅ [OnlineGameService] New gameState saved successfully');
      } else {
        print('❌ [OnlineGameService] Failed to save new gameState');
      }
    } else {
      // Player2: Sadece bekliyor, Player1 yeni grid oluşturduğunda callback tetiklenecek
      print('⏳ [OnlineGameService] Player2 waiting for new grid from Player1...');
      await Future.delayed(const Duration(milliseconds: 500));
    }
  }

  Future<bool> makeMove(String matchId, int row, int col, String playerName, int playerNumber) async {
    final gameStateData = await _firebase.get('matches/$matchId/gameState');
    if (gameStateData == null) return false;

    final gameState = GameState.fromJson(gameStateData);
    if (gameState.currentPlayer != playerNumber) return false;
    if (gameState.board[row][col].isEmpty == false) return false;
    if (!gameState.grid.isValidCell(row, col)) return false;

    final rowItem = gameState.grid.rows[row];
    final colItem = gameState.grid.cols[col];

    final player = await _validationService.findPlayer(playerName, rowItem, colItem);
    if (player == null) {
      // Yanlış cevap - sıra değişir
      await switchTurn(matchId);
      return false;
    }

    return _processMove(matchId, gameState, row, col, player, playerNumber);
  }

  Future<bool> makeMoveWithPlayer(String matchId, int row, int col, Player selectedPlayer, int playerNumber) async {
    final gameStateData = await _firebase.get('matches/$matchId/gameState');
    if (gameStateData == null) return false;

    final gameState = GameState.fromJson(gameStateData);
    if (gameState.currentPlayer != playerNumber) return false;
    if (gameState.board[row][col].isEmpty == false) return false;
    if (!gameState.grid.isValidCell(row, col)) return false;

    final rowItem = gameState.grid.rows[row];
    final colItem = gameState.grid.cols[col];

    // Seçilen oyuncunun kombinasyona uygun olup olmadığını kontrol et
    final isValid = await _validationService.validateSelectedPlayer(selectedPlayer, rowItem, colItem);
    if (!isValid) {
      // Yanlış cevap - sıra değişir
      await switchTurn(matchId);
      return false;
    }

    return _processMove(matchId, gameState, row, col, selectedPlayer, playerNumber);
  }

  Future<bool> _processMove(String matchId, GameState gameState, int row, int col, Player player, int playerNumber) async {
    // Doğru cevap - hücreyi doldur
    final newBoard = gameState.board.map((r) => r.toList()).toList();
    newBoard[row][col] = CellData(
      player: playerNumber,
      playerData: player,
    );

    // Kazanma kontrolü
    final winner = _checkWinner(newBoard);
    int? newWinner;
    List<List<int>>? winningCells;
    int newPlayer1Score = gameState.player1Score;
    int newPlayer2Score = gameState.player2Score;

    if (winner != null) {
      newWinner = winner['player'];
      winningCells = winner['cells'];
      if (newWinner == 1) {
        newPlayer1Score++;
      } else {
        newPlayer2Score++;
      }
    } else if (_isBoardFull(newBoard, gameState.grid)) {
      newWinner = 0; // Berabere
    }

    // Firebase'e kaydet
    final updatedGameState = GameState(
      grid: gameState.grid,
      board: newBoard,
      currentPlayer: newWinner == null ? (playerNumber == 1 ? 2 : 1) : gameState.currentPlayer,
      player1Score: newPlayer1Score,
      player2Score: newPlayer2Score,
      winner: newWinner,
      winningCells: winningCells,
    );

    final gameStateJson = updatedGameState.toJson();
    print('💾 [OnlineGameService] Saving to Firebase:');
    print('   Board JSON: ${gameStateJson['board']}');
    print('   CurrentPlayer: ${gameStateJson['currentPlayer']}');
    
    final success = await _firebase.set('matches/$matchId/gameState', gameStateJson);
    if (success) {
      print('✅ [OnlineGameService] Move saved to Firebase successfully');
    } else {
      print('❌ [OnlineGameService] Failed to save move to Firebase');
    }
    return success;
  }

  Future<void> switchTurn(String matchId) async {
    final gameStateData = await _firebase.get('matches/$matchId/gameState');
    if (gameStateData == null) return;

    final gameState = GameState.fromJson(gameStateData);
    final newCurrentPlayer = gameState.currentPlayer == 1 ? 2 : 1;

    await _firebase.update('matches/$matchId/gameState', {
      'currentPlayer': newCurrentPlayer,
    });
  }

  void _listenToGameState(String matchId) {
    _gameStateSubscription?.cancel();
    // Gerçek zamanlı dinleme - WebSocket benzeri (polling yok!)
    _gameStateSubscription = _firebase.listen('matches/$matchId/gameState').listen((data) {
      if (data != null && _gameStateUpdateCallback != null) {
        try {
          print('📥 [OnlineGameService] Received gameState update from Firebase');
          print('   Board data: ${data['board']}');
          final gameState = GameState.fromJson(data);
          
          // Board'u kontrol et
          int filledCells = 0;
          for (int i = 0; i < 3; i++) {
            for (int j = 0; j < 3; j++) {
              if (!gameState.board[i][j].isEmpty) {
                filledCells++;
                print('   Board[$i][$j]: player=${gameState.board[i][j].player}, name=${gameState.board[i][j].playerData?.oyuncuAdi}');
              }
            }
          }
          print('   Total filled cells: $filledCells');
          
          _gameStateUpdateCallback!(gameState);
        } catch (e, stackTrace) {
          print('❌ [OnlineGameService] Error parsing game state: $e');
          print('   Stack trace: $stackTrace');
        }
      }
    }, onError: (error) {
      print('❌ [OnlineGameService] Game state listen error: $error');
    });
  }

  void setGameStateUpdateCallback(Function(GameState) callback) {
    _gameStateUpdateCallback = callback;
  }

  Future<GameState?> getGameState(String matchId) async {
    final gameStateData = await _firebase.get('matches/$matchId/gameState');
    if (gameStateData == null) return null;
    try {
      return GameState.fromJson(gameStateData);
    } catch (e) {
      print('Error parsing game state: $e');
      return null;
    }
  }

  Future<void> requestNewGame(String matchId, String playerId, int playerNumber) async {
    final playerKey = playerNumber == 1 ? 'player1Ready' : 'player2Ready';
    print('📝 [OnlineGameService] Requesting new game: $playerKey = true');
    final success = await _firebase.update('matches/$matchId', {
      playerKey: true,
    });
    if (success) {
      print('✅ [OnlineGameService] New game request sent successfully');
    } else {
      print('❌ [OnlineGameService] Failed to send new game request');
    }
  }

  StreamSubscription<Map<String, dynamic>?>? _newGameSubscription;
  
  void listenForNewGameRequest(String matchId, Function(bool bothReady) callback) {
    _newGameSubscription?.cancel();
    _newGameSubscription = _firebase.listen('matches/$matchId').listen((data) {
      if (data != null) {
        final player1Ready = data['player1Ready'] as bool? ?? false;
        final player2Ready = data['player2Ready'] as bool? ?? false;
        final player1Left = data['player1Left'] as bool? ?? false;
        final player2Left = data['player2Left'] as bool? ?? false;
        
        print('🔄 [OnlineGameService] New game request check: player1Ready=$player1Ready, player2Ready=$player2Ready');
        
        if (player1Left || player2Left) {
          print('❌ [OnlineGameService] Player left, not starting new game');
          callback(false); // Oyuncu ayrıldı
        } else if (player1Ready && player2Ready) {
          print('✅ [OnlineGameService] Both players ready, starting new game');
          callback(true); // Her iki oyuncu da hazır
        }
      }
    });
  }

  Future<void> leaveGame(String matchId, String playerId, int playerNumber) async {
    final playerKey = playerNumber == 1 ? 'player1Left' : 'player2Left';
    await _firebase.update('matches/$matchId', {
      playerKey: true,
    });
  }

  Future<void> resetNewGameFlags(String matchId) async {
    print('🔄 [OnlineGameService] Resetting new game flags...');
    final success = await _firebase.update('matches/$matchId', {
      'player1Ready': false,
      'player2Ready': false,
    });
    if (success) {
      print('✅ [OnlineGameService] New game flags reset successfully');
    } else {
      print('❌ [OnlineGameService] Failed to reset new game flags');
    }
  }

  void dispose() {
    _gameStateSubscription?.cancel();
    _newGameSubscription?.cancel();
    _gameStateUpdateCallback = null;
  }

  Map<String, dynamic>? _checkWinner(List<List<CellData>> board) {
    // Yatay kontrol
    for (int i = 0; i < 3; i++) {
      if (board[i][0].player != null &&
          board[i][0].player == board[i][1].player &&
          board[i][1].player == board[i][2].player) {
        return {
          'player': board[i][0].player,
          'cells': [[i, 0], [i, 1], [i, 2]],
        };
      }
    }

    // Dikey kontrol
    for (int j = 0; j < 3; j++) {
      if (board[0][j].player != null &&
          board[0][j].player == board[1][j].player &&
          board[1][j].player == board[2][j].player) {
        return {
          'player': board[0][j].player,
          'cells': [[0, j], [1, j], [2, j]],
        };
      }
    }

    // Çapraz kontrol
    if (board[0][0].player != null &&
        board[0][0].player == board[1][1].player &&
        board[1][1].player == board[2][2].player) {
      return {
        'player': board[0][0].player,
        'cells': [[0, 0], [1, 1], [2, 2]],
      };
    }

    if (board[0][2].player != null &&
        board[0][2].player == board[1][1].player &&
        board[1][1].player == board[2][0].player) {
      return {
        'player': board[0][2].player,
        'cells': [[0, 2], [1, 1], [2, 0]],
      };
    }

    return null;
  }

  bool _isBoardFull(List<List<CellData>> board, Grid grid) {
    for (int i = 0; i < 3; i++) {
      for (int j = 0; j < 3; j++) {
        if (board[i][j].isEmpty && grid.isValidCell(i, j)) {
          return false;
        }
      }
    }
    return true;
  }
}

