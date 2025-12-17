import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'screens/mode_selection_screen.dart';
import 'services/player_service.dart';
import 'services/firebase_realtime_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Windows/Linux/macOS için FFI başlat
  if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.linux ||
      defaultTargetPlatform == TargetPlatform.macOS)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  
  // PlayerService'i başlat
  // Veritabanı boşsa veya veriler eksikse otomatik olarak yeniden oluşturulacak
  await PlayerService.instance.initialize();
  
  // Firebase Realtime Database'i başlat
  await FirebaseRealtimeService().initialize();
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Futbol Tic Tac Toe',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const ModeSelectionScreen(),
    );
  }
}

