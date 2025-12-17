import 'package:flutter/foundation.dart';
import 'player.dart';
import 'grid.dart';

class CellData {
  final int? player; // 1 veya 2
  final Player? playerData;

  CellData({
    this.player,
    this.playerData,
  });

  bool get isEmpty => player == null;

  Map<String, dynamic> toJson() {
    return {
      'player': player,
      'playerData': playerData?.toJson(),
    };
  }

  factory CellData.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return CellData();
    }
    return CellData(
      player: json['player'] as int?,
      playerData: json['playerData'] != null
          ? Player.fromJson(json['playerData'] as Map<String, dynamic>)
          : null,
    );
  }
}

class GameState {
  final Grid grid;
  final List<List<CellData>> board; // 3x3
  final int currentPlayer; // 1 veya 2
  final int player1Score;
  final int player2Score;
  final int? winner; // 1, 2 veya null
  final List<List<int>>? winningCells; // [[row, col], ...]

  GameState({
    required this.grid,
    required this.board,
    required this.currentPlayer,
    this.player1Score = 0,
    this.player2Score = 0,
    this.winner,
    this.winningCells,
  });

  GameState copyWith({
    Grid? grid,
    List<List<CellData>>? board,
    int? currentPlayer,
    int? player1Score,
    int? player2Score,
    int? winner,
    List<List<int>>? winningCells,
  }) {
    return GameState(
      grid: grid ?? this.grid,
      board: board ?? this.board,
      currentPlayer: currentPlayer ?? this.currentPlayer,
      player1Score: player1Score ?? this.player1Score,
      player2Score: player2Score ?? this.player2Score,
      winner: winner ?? this.winner,
      winningCells: winningCells ?? this.winningCells,
    );
  }

  Map<String, dynamic> toJson() {
    // Board'u Map formatına çevir (Firebase için)
    Map<String, dynamic> boardMap = {};
    for (int i = 0; i < board.length; i++) {
      Map<String, dynamic> rowMap = {};
      for (int j = 0; j < board[i].length; j++) {
        rowMap[j.toString()] = board[i][j].toJson();
      }
      boardMap[i.toString()] = rowMap;
    }

    return {
      'grid': grid.toJson(),
      'board': boardMap,
      'currentPlayer': currentPlayer,
      'player1Score': player1Score,
      'player2Score': player2Score,
      'winner': winner,
      'winningCells': winningCells,
    };
  }

  factory GameState.fromJson(Map<String, dynamic> json) {
    // Board'u Map'ten veya List'ten List'e çevir
    // Firebase bazen Map, bazen List formatında gönderiyor
    List<List<CellData>> board = [];
    final boardDataRaw = json['board'];
    
    if (kDebugMode) {
      print('📋 [GameState.fromJson] Board data type: ${boardDataRaw.runtimeType}');
      print('📋 [GameState.fromJson] Board data: $boardDataRaw');
    }
    
    if (boardDataRaw is List) {
      // Firebase tamamen List formatına çevirmiş: [null, [{...}], ...]
      for (int i = 0; i < 3; i++) {
        List<CellData> rowList = [];
        if (i < boardDataRaw.length && boardDataRaw[i] != null) {
          final row = boardDataRaw[i];
          if (row is List) {
            // List formatı: [{...}, {...}, {...}]
            for (int j = 0; j < 3; j++) {
              if (j < row.length && row[j] != null) {
                final cellData = row[j];
                if (cellData is Map) {
                  rowList.add(CellData.fromJson(cellData as Map<String, dynamic>?));
                } else {
                  rowList.add(CellData.fromJson(null));
                }
              } else {
                rowList.add(CellData());
              }
            }
          } else if (row is Map) {
            // Map formatı: {0: {...}, 1: {...}, 2: {...}}
            for (int j = 0; j < 3; j++) {
              final colKey = j.toString();
              if (row.containsKey(colKey) && row[colKey] != null) {
                final cellData = row[colKey];
                if (cellData is Map) {
                  rowList.add(CellData.fromJson(cellData as Map<String, dynamic>?));
                } else {
                  rowList.add(CellData.fromJson(null));
                }
              } else {
                rowList.add(CellData());
              }
            }
          } else {
            // null veya başka bir tip
            rowList = [CellData(), CellData(), CellData()];
          }
        } else {
          // null satır
          rowList = [CellData(), CellData(), CellData()];
        }
        board.add(rowList);
      }
    } else if (boardDataRaw is Map) {
      // Map formatı: {0: {...}, 1: {...}, 2: {...}}
      final sortedKeys = boardDataRaw.keys.toList()
        ..sort((a, b) => int.parse(a.toString()).compareTo(int.parse(b.toString())));
      for (var rowKey in sortedKeys) {
        final row = boardDataRaw[rowKey];
        List<CellData> rowList = [];
        
        if (row is Map) {
          // Map formatı: {0: {...}, 1: {...}, 2: {...}}
          final colKeys = row.keys.toList()
            ..sort((a, b) => int.parse(a.toString()).compareTo(int.parse(b.toString())));
          for (var colKey in colKeys) {
            final cellData = row[colKey];
            if (cellData is Map) {
              rowList.add(CellData.fromJson(cellData as Map<String, dynamic>?));
            } else {
              rowList.add(CellData.fromJson(null));
            }
          }
        } else if (row is List) {
          // List formatı: [{...}, {...}, {...}] - Firebase'in otomatik dönüşümü
          for (var cellData in row) {
            if (cellData is Map) {
              rowList.add(CellData.fromJson(cellData as Map<String, dynamic>?));
            } else {
              rowList.add(CellData.fromJson(null));
            }
          }
        }
        
        // 3x3 garantisi için eksik hücreleri doldur
        while (rowList.length < 3) {
          rowList.add(CellData());
        }
        board.add(rowList);
      }
    }
    
    // 3x3 garantisi için eksik satırları doldur
    while (board.length < 3) {
      board.add([CellData(), CellData(), CellData()]);
    }

    if (kDebugMode) {
      print('📋 [GameState.fromJson] Parsed board:');
      for (int i = 0; i < 3; i++) {
        for (int j = 0; j < 3; j++) {
          if (!board[i][j].isEmpty) {
            print('   Board[$i][$j]: player=${board[i][j].player}, name=${board[i][j].playerData?.oyuncuAdi}');
          }
        }
      }
    }

    return GameState(
      grid: Grid.fromJson(json['grid'] as Map<String, dynamic>),
      board: board,
      currentPlayer: json['currentPlayer'] as int? ?? 1,
      player1Score: json['player1Score'] as int? ?? 0,
      player2Score: json['player2Score'] as int? ?? 0,
      winner: json['winner'] as int?,
      winningCells: json['winningCells'] != null
          ? (json['winningCells'] as List)
              .map((e) => List<int>.from(e))
              .toList()
          : null,
    );
  }
}

