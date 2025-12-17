import 'dart:async';
import 'package:flutter/material.dart';
import '../models/game_state.dart';
import '../models/player.dart';
import '../services/game_service.dart';
import '../services/online_game_service.dart';
import '../widgets/game_grid.dart';
import '../widgets/player_search_dialog.dart';
import '../widgets/timer_widget.dart';
import '../widgets/custom_snackbar.dart';
import '../screens/mode_selection_screen.dart';

class GameScreen extends StatefulWidget {
  final GameMode gameMode;
  final String? roomId;
  final String? playerId;
  final int? playerNumber;

  const GameScreen({
    super.key,
    required this.gameMode,
    this.roomId,
    this.playerId,
    this.playerNumber,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  final GameService _gameService = GameService();
  final OnlineGameService _onlineGameService = OnlineGameService();
  GameState? _gameState;
  final GlobalKey<TimerWidgetState> _timerKey1 = GlobalKey<TimerWidgetState>();
  final GlobalKey<TimerWidgetState> _timerKey2 = GlobalKey<TimerWidgetState>();

  @override
  void initState() {
    super.initState();
    _startNewGame();
  }

  Future<void> _startNewGame() async {
    if (widget.gameMode == GameMode.local) {
      final gameState = await _gameService.startNewGame();
      setState(() {
        _gameState = gameState;
      });
      _resetTimer();
    } else if (widget.gameMode == GameMode.onlineRandom) {
      if (widget.roomId != null && widget.playerId != null && widget.playerNumber != null) {
        // Callback'i önce set et
        _onlineGameService.setGameStateUpdateCallback((gameState) {
          if (mounted) {
            print('🔄 [GameScreen] GameState updated from callback');
            final previousWinner = _gameState?.winner;
            setState(() {
              _gameState = gameState;
            });
            _resetTimer();
            
            // Oyun bitiş kontrolü (sadece yeni bitmişse)
            if (previousWinner == null && gameState.winner != null) {
              _showGameOverDialog();
            }
          }
        });
        
        // Oyunu başlat
        await _onlineGameService.startOnlineGame(
          widget.roomId!,
          widget.playerId!,
          widget.playerNumber!,
        );
        
        // İlk gameState'i yükle (Player2 için önemli, Player1 için de güvenlik için)
        final initialGameState = await _onlineGameService.getGameState(widget.roomId!);
        if (initialGameState != null && mounted) {
          print('✅ [GameScreen] Initial gameState loaded');
          setState(() {
            _gameState = initialGameState;
          });
          _resetTimer();
        } else {
          print('⚠️ [GameScreen] Initial gameState is null, waiting for callback...');
        }
      }
    }
  }

  void _resetTimer() {
    if (_gameState == null) return;
    _timerKey1.currentState?.reset();
    _timerKey2.currentState?.reset();
  }

  void _onCellTap(int row, int col) {
    if (_gameState == null) return;
    if (_gameState!.winner != null) return;
    if (_gameState!.board[row][col].isEmpty == false) return;

    // Online modda sadece aktif oyuncu hamle yapabilir
    if (widget.gameMode == GameMode.onlineRandom) {
      if (_gameState!.currentPlayer != widget.playerNumber) {
        CustomSnackBar.showInfoMessage(context, 'Sıra sizde değil!');
        return;
      }
    }

    _showPlayerSearchDialog(row, col);
  }

  void _showPlayerSearchDialog(int row, int col) {
    if (_gameState == null) return;

    final rowItem = _gameState!.grid.rows[row];
    final colItem = _gameState!.grid.cols[col];

    showDialog(
      context: context,
      builder: (context) => PlayerSearchDialog(
        rowItem: rowItem,
        colItem: colItem,
        onPlayerSelected: (player) {
          _makeMoveWithPlayer(row, col, player);
        },
      ),
    );
  }

  Future<void> _makeMoveWithPlayer(int row, int col, Player player) async {
    if (_gameState == null) return;

    bool success;
    if (widget.gameMode == GameMode.local) {
      success = await _gameService.makeMoveWithPlayer(row, col, player);
      setState(() {
        _gameState = _gameService.getCurrentGame();
      });
    } else {
      if (widget.playerNumber == null) return;
      success = await _onlineGameService.makeMoveWithPlayer(
        widget.roomId!,
        row,
        col,
        player,
        widget.playerNumber!,
      );
      // State güncellemesi callback'ten gelecek
    }

    if (!success) {
      CustomSnackBar.showErrorMessage(context, 'Yanlış oyuncu!');
    } else {
      _resetTimer();
      
      // Kazanma kontrolü
      if (_gameState?.winner != null) {
        _showGameOverDialog();
      }
    }
  }

  void _onTimeout() {
    if (_gameState == null) return;
    
    CustomSnackBar.showTimeoutMessage(context, 'Süre doldu!');
    
    if (widget.gameMode == GameMode.local) {
      _gameService.updateCurrentPlayer(
        _gameState!.currentPlayer == 1 ? 2 : 1,
      );
      setState(() {
        _gameState = _gameService.getCurrentGame();
      });
    } else {
      _onlineGameService.switchTurn(widget.roomId!);
    }
    
    _resetTimer();
  }

  void _showGameOverDialog() {
    if (_gameState == null) return;

    String message;
    if (_gameState!.winner == 0) {
      message = 'Berabere!';
    } else if (_gameState!.winner == 1) {
      message = 'Oyuncu 1 Kazandı!';
    } else {
      message = 'Oyuncu 2 Kazandı!';
    }

    if (widget.gameMode == GameMode.onlineRandom) {
      // Online mod: Yeni Oyun ve Ayrıl seçenekleri
      _showOnlineGameOverDialog(message);
    } else {
      // Local mod: Basit dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF1a1a2e),
          title: Text(
            message,
            style: const TextStyle(color: Colors.white),
          ),
          content: Text(
            'Oyuncu 1: ${_gameState!.player1Score} - Oyuncu 2: ${_gameState!.player2Score}',
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _startNewGame();
              },
              child: const Text('Yeni Oyun'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              child: const Text('Ana Menü'),
            ),
          ],
        ),
      );
    }
  }

  void _showOnlineGameOverDialog(String message) {
    if (widget.roomId == null) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a2e),
        title: Text(
          message,
          style: const TextStyle(color: Colors.white, fontSize: 20),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Oyuncu 1: ${_gameState!.player1Score} - Oyuncu 2: ${_gameState!.player2Score}',
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 16),
            const Text(
              'Ne yapmak istersiniz?',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _requestNewGame();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
            ),
            child: const Text('Yeni Oyun', style: TextStyle(color: Colors.white)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _leaveGame();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Ayrıl', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _requestNewGame() async {
    if (widget.roomId == null || widget.playerId == null || widget.playerNumber == null) return;
    
    // Firebase'e yeni oyun isteği gönder
    await _onlineGameService.requestNewGame(widget.roomId!, widget.playerId!, widget.playerNumber!);
    
    // Diğer oyuncunun isteğini bekle
    _waitForNewGameResponse();
  }

  void _waitForNewGameResponse() {
    if (widget.roomId == null) return;
    
    print('👂 [GameScreen] Player${widget.playerNumber} listening for new game request...');
    
    // Firebase'den yeni oyun isteğini dinle
    _onlineGameService.listenForNewGameRequest(widget.roomId!, (bothReady) {
      print('📢 [GameScreen] Player${widget.playerNumber} received callback: bothReady=$bothReady');
      if (bothReady && mounted) {
        // Her iki oyuncu da hazır - yeni oyun başlat (yeni grid ile)
        print('✅ [GameScreen] Player${widget.playerNumber} starting new game...');
        _startNewGameWithNewGrid();
      } else if (mounted) {
        // Diğer oyuncu ayrıldı
        print('❌ [GameScreen] Player${widget.playerNumber} opponent left');
        _showOpponentLeftDialog();
      }
    });
  }

  Future<void> _startNewGameWithNewGrid() async {
    if (widget.roomId == null || widget.playerId == null || widget.playerNumber == null) return;
    
    print('🔄 [GameScreen] _startNewGameWithNewGrid called for Player${widget.playerNumber}');
    
    // Sadece Player1 flags'leri sıfırlasın (race condition'ı önlemek için)
    if (widget.playerNumber == 1) {
      await _onlineGameService.resetNewGameFlags(widget.roomId!);
    }
    
    // Yeni grid ile oyunu başlat
    await _onlineGameService.startNewGame(widget.roomId!, widget.playerNumber!);
    
    // Yeni gameState'i yükle
    // Player1 için hemen, Player2 için kısa bir gecikme ile (Player1'in grid'i oluşturması için)
    if (widget.playerNumber == 1) {
      // Player1: Yeni grid oluşturuldu, hemen yükle
      print('📥 [GameScreen] Player1 loading new gameState...');
      final newGameState = await _onlineGameService.getGameState(widget.roomId!);
      if (newGameState != null && mounted) {
        print('✅ [GameScreen] Player1 new gameState loaded successfully');
        print('📊 [GameScreen] Player1 new grid - rows: ${newGameState.grid.rows}, cols: ${newGameState.grid.cols}');
        setState(() {
          _gameState = newGameState;
        });
        _resetTimer();
      } else {
        print('❌ [GameScreen] Player1 new gameState is null');
      }
    } else {
      // Player2: Player1'in grid'i oluşturmasını bekle, sonra yükle
      print('⏳ [GameScreen] Player2 waiting for new grid from Player1...');
      await Future.delayed(const Duration(milliseconds: 800));
      final newGameState = await _onlineGameService.getGameState(widget.roomId!);
      if (newGameState != null && mounted) {
        print('✅ [GameScreen] Player2 new gameState loaded after delay');
        print('📊 [GameScreen] Player2 new grid - rows: ${newGameState.grid.rows}, cols: ${newGameState.grid.cols}');
        setState(() {
          _gameState = newGameState;
        });
        _resetTimer();
      } else {
        print('❌ [GameScreen] Player2 new gameState is null after delay');
      }
    }
  }


  void _showOpponentLeftDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a2e),
        title: const Text(
          'Rakip Oyundan Ayrıldı',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Rakibiniz oyundan ayrıldı. Ana menüye yönlendiriliyorsunuz.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Tamam'),
          ),
        ],
      ),
    );
  }

  Future<void> _leaveGame() async {
    if (widget.roomId == null || widget.playerId == null || widget.playerNumber == null) return;
    
    // Firebase'e ayrılma bildirimi gönder
    await _onlineGameService.leaveGame(widget.roomId!, widget.playerId!, widget.playerNumber!);
    
    // Ana menüye dön
    if (mounted) {
      Navigator.pop(context);
    }
  }

  Future<void> _changeBoard() async {
    if (widget.gameMode == GameMode.onlineRandom) {
      CustomSnackBar.showInfoMessage(context, 'Online modda tablo değiştirilemez');
      return;
    }

    await _startNewGame();
    _resetTimer();
  }

  @override
  void dispose() {
    if (widget.gameMode == GameMode.onlineRandom) {
      _onlineGameService.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_gameState == null) {
      return Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF0f0c29),
                const Color(0xFF302b63),
                const Color(0xFF24243e),
              ],
            ),
          ),
          child: const Center(
            child: CircularProgressIndicator(color: Colors.purple),
          ),
        ),
      );
    }

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF0f0c29),
              const Color(0xFF302b63),
              const Color(0xFF24243e),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Skor ve butonlar
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Oyuncu 1 Skor
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue, width: 2),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'Oyuncu 1',
                            style: TextStyle(color: Colors.white, fontSize: 12),
                          ),
                          Text(
                            '${_gameState!.player1Score}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Timer'lar
                    Row(
                      children: [
                        TimerWidget(
                          key: _timerKey1,
                          isActive: _gameState!.currentPlayer == 1,
                          onTimeout: _onTimeout,
                        ),
                        const SizedBox(width: 16),
                        TimerWidget(
                          key: _timerKey2,
                          isActive: _gameState!.currentPlayer == 2,
                          onTimeout: _onTimeout,
                        ),
                      ],
                    ),
                    // Oyuncu 2 Skor
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red, width: 2),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'Oyuncu 2',
                            style: TextStyle(color: Colors.white, fontSize: 12),
                          ),
                          Text(
                            '${_gameState!.player2Score}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Tabloyu Değiştir butonu
              if (widget.gameMode == GameMode.local)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: ElevatedButton.icon(
                    onPressed: _changeBoard,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Tabloyu Değiştir'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple.withOpacity(0.3),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: Colors.purple, width: 2),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              // Grid
              Expanded(
                child: SingleChildScrollView(
                  child: GameGrid(
                    gameState: _gameState!,
                    onCellTap: _onCellTap,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

