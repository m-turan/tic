import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/game_state.dart';
import '../services/grid_service.dart';

class GameGrid extends StatelessWidget {
  final GameState gameState;
  final Function(int row, int col) onCellTap;

  const GameGrid({
    super.key,
    required this.gameState,
    required this.onCellTap,
  });

  @override
  Widget build(BuildContext context) {
    final gridService = GridService();
    
    return RepaintBoundary(
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Sütun başlıkları
            Row(
              children: [
                const SizedBox(width: 100), // Satır başlıkları için boşluk
                ...List.generate(3, (col) {
                  final colItem = gameState.grid.cols[col];
                  final isCountry = _isCountry(colItem);
                  return Expanded(
                    child: Container(
                      margin: const EdgeInsets.all(4),
                      height: 100,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: const Color(0xFF16213e),
                        border: Border.all(color: Colors.blue, width: 2),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Image.asset(
                                gridService.getImagePath(colItem, isCountry ? 'country' : 'team'),
                                errorBuilder: (context, error, stackTrace) {
                                  return const Icon(Icons.image, color: Colors.white70);
                                },
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              colItem,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
            const SizedBox(height: 8),
            // Grid satırları
            ...List.generate(3, (row) {
              final rowItem = gameState.grid.rows[row];
              final isRowCountry = _isCountry(rowItem);
              return Row(
                children: [
                  // Satır başlığı
                  Container(
                    width: 100,
                    height: 100,
                    margin: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: const Color(0xFF16213e),
                      border: Border.all(color: Colors.blue, width: 2),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Image.asset(
                              gridService.getImagePath(rowItem, isRowCountry ? 'country' : 'team'),
                              errorBuilder: (context, error, stackTrace) {
                                return const Icon(Icons.image, color: Colors.white70);
                              },
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            rowItem,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Grid hücreleri
                  ...List.generate(3, (col) {
                    final cell = gameState.board[row][col];
                    final isValid = gameState.grid.isValidCell(row, col);
                    final isWinning = gameState.winningCells?.any(
                          (c) => c[0] == row && c[1] == col,
                        ) ?? false;

                    return Expanded(
                      child: GestureDetector(
                        onTap: isValid && cell.isEmpty && gameState.winner == null
                            ? () => onCellTap(row, col)
                            : null,
                        child: Container(
                          margin: const EdgeInsets.all(4),
                          height: 100,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: !isValid
                                ? Colors.grey.withOpacity(0.3)
                                : isWinning
                                    ? Colors.green.withOpacity(0.3)
                                    : cell.isEmpty
                                        ? const Color(0xFF16213e)
                                        : cell.player == 1
                                            ? Colors.blue.withOpacity(0.3)
                                            : Colors.red.withOpacity(0.3),
                            border: Border.all(
                              color: !isValid
                                  ? Colors.grey
                                  : isWinning
                                      ? Colors.green
                                      : cell.isEmpty
                                          ? Colors.blue
                                          : cell.player == 1
                                              ? Colors.blue
                                              : Colors.red,
                              width: cell.isEmpty ? 2 : 3,
                            ),
                          ),
                          child: cell.isEmpty
                              ? isValid
                                  ? null
                                  : const Center(
                                      child: Icon(Icons.block, color: Colors.grey),
                                    )
                              : Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    if (cell.playerData?.fotografUrl != null &&
                                        cell.playerData!.fotografUrl != 'Bilinmiyor')
                                      Expanded(
                                        child: Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(8),
                                            child: Image.asset(
                                              cell.playerData!.fotografUrl,
                                              fit: BoxFit.cover,
                                              errorBuilder: (context, error, stackTrace) {
                                                debugPrint('Image load error: ${cell.playerData!.fotografUrl} - $error');
                                                return const Icon(Icons.person, color: Colors.white);
                                              },
                                            ),
                                          ),
                                        ),
                                      ),
                                    if (cell.playerData?.oyuncuAdi != null)
                                      Padding(
                                        padding: const EdgeInsets.only(bottom: 4),
                                        child: Text(
                                          cell.playerData!.oyuncuAdi,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            fontFamily: 'Roboto', // Unicode desteği için
                                          ),
                                          textAlign: TextAlign.center,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                  ],
                                ),
                        ),
                      ),
                    );
                  }),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  bool _isCountry(String item) {
    const allowedCountries = [
      'Germany', 'England', 'Turkey', 'Netherlands', 'Nigeria',
      'France', 'Portugal', 'Spain', 'Argentina', 'Brazil',
      'Arjantin', 'Brazilya'
    ];
    return allowedCountries.contains(item);
  }
}

