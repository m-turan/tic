import 'dart:async';
import 'package:http/http.dart' as http;
import 'dart:convert';

class FirebaseRestService {
  static final FirebaseRestService _instance = FirebaseRestService._internal();
  factory FirebaseRestService() => _instance;
  FirebaseRestService._internal();

  final String baseUrl =
      'https://futbol-tic-tac-toe-default-rtdb.europe-west1.firebasedatabase.app';

  Future<Map<String, dynamic>?> get(String path) async {
    try {
      final url = Uri.parse('$baseUrl/$path.json');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data == null ? null : data as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print('Firebase GET error: $e');
      return null;
    }
  }

  Future<bool> set(String path, Map<String, dynamic> data) async {
    try {
      final url = Uri.parse('$baseUrl/$path.json');
      final response = await http.put(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(data),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Firebase SET error: $e');
      return false;
    }
  }

  Future<bool> update(String path, Map<String, dynamic> data) async {
    try {
      final url = Uri.parse('$baseUrl/$path.json');
      final response = await http.patch(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(data),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Firebase UPDATE error: $e');
      return false;
    }
  }

  Future<bool> delete(String path) async {
    try {
      final url = Uri.parse('$baseUrl/$path.json');
      final response = await http.delete(url);

      return response.statusCode == 200;
    } catch (e) {
      print('Firebase DELETE error: $e');
      return false;
    }
  }

  Stream<Map<String, dynamic>?> listen(String path, {Duration interval = const Duration(seconds: 1)}) {
    final controller = StreamController<Map<String, dynamic>?>.broadcast();
    String? lastDataString; // JSON string olarak karşılaştırma için

    Timer? timer;
    timer = Timer.periodic(interval, (timer) async {
      final data = await get(path);
      final dataString = data != null ? json.encode(data) : null;
      
      // Sadece gerçekten değiştiyse stream'e ekle
      if (dataString != lastDataString) {
        lastDataString = dataString;
        controller.add(data);
      }
    });

    controller.onCancel = () {
      timer?.cancel();
    };

    return controller.stream;
  }
}

