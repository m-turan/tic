import 'package:flutter/material.dart';
import 'matchmaking_screen.dart';
import 'game_screen.dart';

enum GameMode {
  local,
  onlineRandom,
  onlineRoom,
}

class ModeSelectionScreen extends StatelessWidget {
  const ModeSelectionScreen({super.key});

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
                const Text(
                  'Futbol Tic Tac Toe',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 60),
                _buildModeButton(
                  context,
                  'Yan Yana',
                  Icons.people,
                  Colors.blue,
                  () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const GameScreen(
                          gameMode: GameMode.local,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),
                _buildModeButton(
                  context,
                  'Rastgele Çevrimiçi',
                  Icons.shuffle,
                  Colors.purple,
                  () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const MatchmakingScreen(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),
                _buildModeButton(
                  context,
                  'Oda Kur/Katıl',
                  Icons.meeting_room,
                  Colors.pink,
                  () {
                    // TODO: Implement room system
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Oda sistemi yakında eklenecek'),
                        backgroundColor: Colors.pink,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModeButton(
    BuildContext context,
    String text,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Container(
      width: MediaQuery.of(context).size.width * 0.7,
      height: 70,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: color.withOpacity(0.2),
        border: Border.all(color: color, width: 2),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(width: 16),
              Text(
                text,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

