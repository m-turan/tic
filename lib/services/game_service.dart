import '../models/game_state.dart';
import '../models/player.dart';
import 'grid_service.dart';
import 'validation_service.dart';

class GameService {
  static final GameService _instance = GameService._internal();
  factory GameService() => _instance;
  GameService._internal();

  final GridService _gridService = GridService();
  final ValidationService _validationService = ValidationService();
  GameState? _currentGame;

  Future<GameState> startNewGame() async {
    final grid = await _gridService.generateSolvableGrid();
    final board = List.generate(3, (_) => List.generate(3, (_) => CellData()));

    _currentGame = GameState(
      grid: grid,
      board: board,
      currentPlayer: 1,
      player1Score: 0,
      player2Score: 0,
    );

    return _currentGame!;
  }

  Future<bool> makeMove(int row, int col, String playerName) async {
    if (_currentGame == null) return false;
    if (_currentGame!.board[row][col].isEmpty == false) return false;
    if (!_currentGame!.grid.isValidCell(row, col)) return false;

    final rowItem = _currentGame!.grid.rows[row];
    final colItem = _currentGame!.grid.cols[col];

    final player = await _validationService.findPlayer(playerName, rowItem, colItem);
    if (player == null) {
      // Yanlış cevap - sıra değişir
      _currentGame = _currentGame!.copyWith(
        currentPlayer: _currentGame!.currentPlayer == 1 ? 2 : 1,
      );
      return false;
    }

    return _processMove(row, col, player);
  }

  Future<bool> makeMoveWithPlayer(int row, int col, Player selectedPlayer) async {
    if (_currentGame == null) return false;
    if (_currentGame!.board[row][col].isEmpty == false) return false;
    if (!_currentGame!.grid.isValidCell(row, col)) return false;

    final rowItem = _currentGame!.grid.rows[row];
    final colItem = _currentGame!.grid.cols[col];

    // Seçilen oyuncunun kombinasyona uygun olup olmadığını kontrol et
    final isValid = await _validationService.validateSelectedPlayer(selectedPlayer, rowItem, colItem);
    if (!isValid) {
      // Yanlış cevap - sıra değişir
      _currentGame = _currentGame!.copyWith(
        currentPlayer: _currentGame!.currentPlayer == 1 ? 2 : 1,
      );
      return false;
    }

    return _processMove(row, col, selectedPlayer);
  }

  bool _processMove(int row, int col, Player player) {
    if (_currentGame == null) return false;

    // Doğru cevap - hücreyi doldur
    final newBoard = _currentGame!.board.map((r) => r.toList()).toList();
    newBoard[row][col] = CellData(
      player: _currentGame!.currentPlayer,
      playerData: player,
    );

    _currentGame = _currentGame!.copyWith(board: newBoard);

    // Kazanma kontrolü
    final winner = _checkWinner(newBoard);
    if (winner != null) {
      _currentGame = _currentGame!.copyWith(
        winner: winner['player'],
        winningCells: winner['cells'],
      );
      // Skor güncelle
      if (winner['player'] == 1) {
        _currentGame = _currentGame!.copyWith(
          player1Score: _currentGame!.player1Score + 1,
        );
      } else {
        _currentGame = _currentGame!.copyWith(
          player2Score: _currentGame!.player2Score + 1,
        );
      }
    } else if (_isBoardFull(newBoard)) {
      // Berabere
      _currentGame = _currentGame!.copyWith(winner: 0);
    } else {
      // Sıra değişir
      _currentGame = _currentGame!.copyWith(
        currentPlayer: _currentGame!.currentPlayer == 1 ? 2 : 1,
      );
    }

    return true;
  }

  GameState? getCurrentGame() => _currentGame;

  void updateCurrentPlayer(int player) {
    if (_currentGame != null) {
      _currentGame = _currentGame!.copyWith(currentPlayer: player);
    }
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

    // Çapraz kontrol (sol üst - sağ alt)
    if (board[0][0].player != null &&
        board[0][0].player == board[1][1].player &&
        board[1][1].player == board[2][2].player) {
      return {
        'player': board[0][0].player,
        'cells': [[0, 0], [1, 1], [2, 2]],
      };
    }

    // Çapraz kontrol (sağ üst - sol alt)
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

  bool _isBoardFull(List<List<CellData>> board) {
    for (int i = 0; i < 3; i++) {
      for (int j = 0; j < 3; j++) {
        if (board[i][j].isEmpty && _currentGame!.grid.isValidCell(i, j)) {
          return false;
        }
      }
    }
    return true;
  }
}

