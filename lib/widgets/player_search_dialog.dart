import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../models/player.dart';
import '../services/player_service.dart';

class PlayerSearchDialog extends StatefulWidget {
  final String rowItem;
  final String colItem;
  final Function(Player) onPlayerSelected;

  const PlayerSearchDialog({
    super.key,
    required this.rowItem,
    required this.colItem,
    required this.onPlayerSelected,
  });

  @override
  State<PlayerSearchDialog> createState() => _PlayerSearchDialogState();
}

class _PlayerSearchDialogState extends State<PlayerSearchDialog> {
  final TextEditingController _searchController = TextEditingController();
  final PlayerService _playerService = PlayerService();
  List<Player> _players = [];
  List<Player> _filteredPlayers = [];
  bool _isLoading = false;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _loadPlayers();
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _loadPlayers(); // Arama değiştiğinde tüm oyuncuları yeniden yükle
    });
  }

  Future<void> _loadPlayers() async {
    setState(() {
      _isLoading = true;
    });

    // Tüm oyuncuları yükle (kombinasyon filtresi yok)
    final query = _searchController.text.trim();
    _players = await _playerService.searchPlayers(query);
    
    if (kDebugMode) {
      debugPrint('Loaded ${_players.length} total players (query: "$query")');
    }

    _filterPlayers();
    
    setState(() {
      _isLoading = false;
    });
  }

  void _filterPlayers() {
    // Artık filtreleme _loadPlayers içinde yapılıyor (searchPlayers zaten filtreliyor)
    _filteredPlayers = _players;
    
    if (kDebugMode) {
      final query = _searchController.text.trim();
      debugPrint('Filtered players (query="$query"): ${_filteredPlayers.length}');
    }
    
    setState(() {});
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: const Color(0xFF1a1a2e),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.purple, width: 2),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.purple, width: 1)),
              ),
              child: Column(
                children: [
                  // Kombinasyon bilgisi
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      '${widget.rowItem} × ${widget.colItem}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'Oyuncu ara...',
                            hintStyle: TextStyle(color: Colors.white70),
                            prefixIcon: const Icon(Icons.search, color: Colors.purple),
                            filled: true,
                            fillColor: Colors.black26,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Colors.purple),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Colors.purple),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Colors.purple, width: 2),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Colors.purple))
                  : _filteredPlayers.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.search_off, color: Colors.white70, size: 48),
                              const SizedBox(height: 16),
                              Text(
                                _searchController.text.isEmpty
                                    ? 'Oyuncu aramak için yukarıdaki kutuya yazın'
                                    : 'Arama sonucu bulunamadı',
                                style: const TextStyle(color: Colors.white70),
                                textAlign: TextAlign.center,
                              ),
                              if (_searchController.text.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    '"${_searchController.text}" için sonuç yok',
                                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                                  ),
                                ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemExtent: 80,
                          cacheExtent: 200,
                          itemCount: _filteredPlayers.length,
                          itemBuilder: (context, index) {
                            final player = _filteredPlayers[index];
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              leading: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: player.fotografUrl != 'Bilinmiyor'
                                    ? Image.asset(
                                        player.fotografUrl,
                                        width: 50,
                                        height: 50,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) {
                                          debugPrint('Image load error in dialog: ${player.fotografUrl} - $error');
                                          return Container(
                                            width: 50,
                                            height: 50,
                                            color: Colors.grey,
                                            child: const Icon(Icons.person, color: Colors.white),
                                          );
                                        },
                                      )
                                    : Container(
                                        width: 50,
                                        height: 50,
                                        color: Colors.grey,
                                        child: const Icon(Icons.person, color: Colors.white),
                                      ),
                              ),
                              title: Text(
                                player.oyuncuAdi,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontFamily: 'Roboto', // Unicode desteği için
                                ),
                              ),
                              onTap: () {
                                widget.onPlayerSelected(player);
                                Navigator.of(context).pop();
                              },
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

