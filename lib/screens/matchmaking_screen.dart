import 'dart:async';
import 'package:flutter/material.dart';
import '../services/online_matchmaking_service.dart';
import 'game_screen.dart';
import '../screens/mode_selection_screen.dart';

class MatchmakingScreen extends StatefulWidget {
  const MatchmakingScreen({super.key});

  @override
  State<MatchmakingScreen> createState() => _MatchmakingScreenState();
}

class _MatchmakingScreenState extends State<MatchmakingScreen> {
  final OnlineMatchmakingService _matchmakingService = OnlineMatchmakingService();
  StreamSubscription? _matchSubscription;
  bool _isSearching = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _startSearch();
  }

  void _startSearch() async {
    try {
      _matchSubscription = _matchmakingService.searchMatch().listen(
        (matchData) {
          if (matchData != null && mounted) {
            final matchId = matchData['matchId'] as String;
            final player1 = matchData['player1'] as String;
            final player2 = matchData['player2'] as String;
            
            // Current player ID'yi al (matchmaking service'den)
            final currentPlayerId = _matchmakingService.currentPlayerId;
            if (currentPlayerId == null) {
              print('❌ [MatchmakingScreen] Current player ID is null');
              return;
            }
            
            // Player number'ı belirle
            final playerNumber = (currentPlayerId == player1) ? 1 : 2;
            print('🎮 [MatchmakingScreen] Match found!');
            print('   Match ID: $matchId');
            print('   Player1: $player1');
            print('   Player2: $player2');
            print('   Current Player ID: $currentPlayerId');
            print('   Player Number: $playerNumber');

            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => GameScreen(
                  gameMode: GameMode.onlineRandom,
                  roomId: matchId,
                  playerId: currentPlayerId,
                  playerNumber: playerNumber,
                ),
              ),
            );
          }
        },
        onError: (error) {
          if (mounted) {
            setState(() {
              _isSearching = false;
              _errorMessage = 'Eşleştirme hatası: $error';
            });
          }
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSearching = false;
          _errorMessage = 'Hata: $e';
        });
      }
    }
  }

  @override
  void dispose() {
    _matchSubscription?.cancel();
    _matchmakingService.stopSearching();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_isSearching) ...[
                  const CircularProgressIndicator(color: Colors.purple),
                  const SizedBox(height: 24),
                  const Text(
                    'Eşleşme aranıyor...',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                    ),
                  ),
                ] else if (_errorMessage != null) ...[
                  const Icon(Icons.error, color: Colors.red, size: 64),
                  const SizedBox(height: 24),
                  Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: const Text('Geri Dön'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

