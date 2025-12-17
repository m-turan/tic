import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_rest_service.dart';

class FirebaseRealtimeService {
  static final FirebaseRealtimeService _instance = FirebaseRealtimeService._internal();
  factory FirebaseRealtimeService() => _instance;
  FirebaseRealtimeService._internal();

  DatabaseReference? _databaseRef;
  final FirebaseRestService _restService = FirebaseRestService();
  bool _initialized = false;
  bool _useRestAPI = false; // Windows/Linux/macOS için REST API kullan

  Future<void> initialize() async {
    if (_initialized) return;

    // Windows/Linux/macOS için REST API kullan (Firebase Database plugin desteklemiyor)
    if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.macOS)) {
      _useRestAPI = true;
      _initialized = true;
      print('Using REST API for ${defaultTargetPlatform}');
      return;
    }

    // Android/iOS/Web için Firebase SDK kullan
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: const FirebaseOptions(
            apiKey: "AIzaSyB8tOSbM2gEiCv4P3hQJmV2GNIYPvZsXvI",
            appId: "1:81567451686:web:a6b4dd099611ad087cb4e7",
            messagingSenderId: "81567451686",
            projectId: "futbol-tic-tac-toe",
            databaseURL: "https://futbol-tic-tac-toe-default-rtdb.europe-west1.firebasedatabase.app",
            storageBucket: "futbol-tic-tac-toe.firebasestorage.app",
          ),
        );
        print('✅ [FirebaseRealtimeService] Firebase initialized successfully');
      } else {
        print('✅ [FirebaseRealtimeService] Firebase already initialized');
      }

      _databaseRef = FirebaseDatabase.instance.ref();
      _initialized = true;
      print('✅ [FirebaseRealtimeService] Using Firebase SDK for ${defaultTargetPlatform}');
    } catch (e, stackTrace) {
      print('❌ [FirebaseRealtimeService] Firebase initialization error: $e');
      print('   Stack trace: $stackTrace');
      // Hata durumunda REST API'ye geri dön
      _useRestAPI = true;
      _initialized = true;
      print('⚠️ [FirebaseRealtimeService] Falling back to REST API');
    }
  }

  DatabaseReference? _getRef(String path) {
    if (!_initialized) {
      throw Exception('Firebase not initialized. Call initialize() first.');
    }
    if (_useRestAPI) return null;
    return _databaseRef?.child(path);
  }

  Future<Map<String, dynamic>?> get(String path) async {
    if (_useRestAPI) {
      return await _restService.get(path);
    }

    try {
      final ref = _getRef(path);
      if (ref == null) return null;
      final snapshot = await ref.get();
      if (snapshot.exists) {
        final value = snapshot.value;
        if (value == null) return null;
        
        // Android'de Firebase SDK bazen _Map<Object?, Object?> döndürüyor
        // Bu durumda Map<String, dynamic>'e dönüştürmemiz gerekiyor
        if (value is Map) {
          return Map<String, dynamic>.from(value.map((key, val) => 
            MapEntry(key.toString(), val)
          ));
        }
        return null;
      }
      return null;
    } catch (e) {
      print('Firebase GET error: $e');
      return null;
    }
  }

  Future<bool> set(String path, Map<String, dynamic> data) async {
    if (_useRestAPI) {
      return await _restService.set(path, data);
    }

    try {
      final ref = _getRef(path);
      if (ref == null) return false;
      await ref.set(data);
      return true;
    } catch (e) {
      print('Firebase SET error: $e');
      return false;
    }
  }

  Future<bool> update(String path, Map<String, dynamic> data) async {
    if (_useRestAPI) {
      return await _restService.update(path, data);
    }

    try {
      final ref = _getRef(path);
      if (ref == null) return false;
      await ref.update(data);
      return true;
    } catch (e) {
      print('Firebase UPDATE error: $e');
      return false;
    }
  }

  Future<bool> delete(String path) async {
    if (_useRestAPI) {
      return await _restService.delete(path);
    }

    try {
      final ref = _getRef(path);
      if (ref == null) return false;
      await ref.remove();
      return true;
    } catch (e) {
      print('Firebase DELETE error: $e');
      return false;
    }
  }

  /// Gerçek zamanlı dinleme - WebSocket benzeri
  Stream<Map<String, dynamic>?> listen(String path) {
    final controller = StreamController<Map<String, dynamic>?>.broadcast();

    // Windows/Linux/macOS için REST API ile polling (daha sık)
    if (_useRestAPI) {
      return _restService.listen(path, interval: const Duration(milliseconds: 500));
    }

    // Android/iOS/Web için Firebase SDK ile gerçek zamanlı
    try {
      final ref = _getRef(path);
      if (ref == null) {
        // Fallback to REST API
        return _restService.listen(path, interval: const Duration(milliseconds: 500));
      }

      ref.onValue.listen((event) {
        if (event.snapshot.exists) {
          final data = event.snapshot.value;
          if (data is Map) {
            // Android'de Firebase SDK bazen _Map<Object?, Object?> döndürüyor
            // Bu durumda Map<String, dynamic>'e dönüştürmemiz gerekiyor
            try {
              final converted = Map<String, dynamic>.from(data.map((key, val) => 
                MapEntry(key.toString(), val)
              ));
              controller.add(converted);
            } catch (e) {
              print('Firebase listen conversion error: $e');
              controller.add(null);
            }
          } else {
            controller.add(null);
          }
        } else {
          controller.add(null);
        }
      }, onError: (error) {
        print('Firebase listen error: $error');
        controller.addError(error);
      });
    } catch (e) {
      print('Firebase listen setup error: $e');
      // Fallback to REST API
      return _restService.listen(path, interval: const Duration(milliseconds: 500));
    }

    return controller.stream;
  }

  /// Child ekleme/çıkarma dinleme
  Stream<Map<String, dynamic>?> listenChild(String path) {
    final controller = StreamController<Map<String, dynamic>?>.broadcast();

    if (_useRestAPI) {
      // REST API için listen kullan
      return listen(path);
    }

    try {
      final ref = _getRef(path);
      if (ref == null) {
        return listen(path); // Fallback
      }

      ref.onChildAdded.listen((event) {
        if (event.snapshot.exists) {
          final data = event.snapshot.value;
          if (data is Map) {
            controller.add(Map<String, dynamic>.from(data));
          }
        }
      }, onError: (error) {
        print('Firebase listenChild error: $error');
        controller.addError(error);
      });
    } catch (e) {
      print('Firebase listenChild setup error: $e');
      controller.addError(e);
    }

    return controller.stream;
  }
}

