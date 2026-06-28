import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants.dart';
import '../core/navigation.dart';
import '../models/models.dart';
import '../screens/login_screen.dart';

String get _baseUrl {
  const env = String.fromEnvironment('API_BASE_URL');
  if (env.isNotEmpty) return env;
  // return Platform.isAndroid ? 'http://192.168.0.39:8000' : 'http://192.168.0.39:8000';
  return Platform.isAndroid ? 'http://10.0.2.2:8000' : 'http://192.168.0.39:8000';
}
class AuthTokens {
  static const _key = 'auth_token';
  static Future<void> save(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, token);
  }
  static Future<String?> load() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key);
  }
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  const ApiException(this.message, [this.statusCode]);
  @override
  String toString() => message;
}
Uri _uri(String path) => Uri.parse('$_baseUrl$path');
Future<Map<String, String>> _headers({bool auth = true}) async {
  final h = <String, String>{
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };
  if (auth) {
    final token = await AuthTokens.load();
    if (token != null) h['Authorization'] = 'Bearer $token';
  }
  return h;
}

Future<void> _handleUnauthorized() async {
  await AuthTokens.clear();
  navigatorKey.currentState?.pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => const LoginScreen()),
    (route) => false,
  );
}

Map<String, dynamic> _parse(http.Response resp) {
  if (resp.statusCode == 401) {
    _handleUnauthorized();
    throw const ApiException('Сессия истекла. Войдите снова.', 401);
  }
  final body = json.decode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
  if (resp.statusCode < 200 || resp.statusCode >= 300 || body['success'] != true) {
    throw ApiException(
      (body['error'] ?? body['message'] ?? 'HTTP ${resp.statusCode}').toString(),
      resp.statusCode,
    );
  }
  return body['data'] as Map<String, dynamic>? ?? {};
}

List<dynamic> _parseList(http.Response resp) {
  if (resp.statusCode == 401) {
    _handleUnauthorized();
    throw const ApiException('Сессия истекла. Войдите снова.', 401);
  }
  final body = json.decode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
  if (resp.statusCode < 200 || resp.statusCode >= 300 || body['success'] != true) {
    throw ApiException(
      (body['error'] ?? body['message'] ?? 'HTTP ${resp.statusCode}').toString(),
      resp.statusCode,
    );
  }
  return body['data'] as List<dynamic>? ?? [];
}


class Api {
  static Future<void> register({
    required String email,
    required String password,
    required String name,
  }) async {
    final body = <String, dynamic>{
      'email': email,
      'password': password,
      'name': name,
    };

    final resp = await http.post(
      _uri('/api/v1/auth/register'),
      headers: await _headers(auth: false),
      body: json.encode(body),
    );
    final data = _parse(resp);
    await AuthTokens.save(data['access_token'] as String);
  }

  static Future<void> login({
    required String email,
    required String password,
  }) async {
    final resp = await http.post(
      _uri('/api/v1/auth/login'),
      headers: await _headers(auth: false),
      body: json.encode({'email': email, 'password': password}),
    );
    final data = _parse(resp);
    await AuthTokens.save(data['access_token'] as String);
  }

  static Future<void> logout() => AuthTokens.clear();

  static Future<Map<String, dynamic>> updateProfile({
    String? name,
    String? profession,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (profession != null) body['profession'] = profession;
    final resp = await http.patch(
      _uri('/api/v1/user/me'),
      headers: await _headers(),
      body: json.encode(body),
    );
    return _parse(resp);
  }


  static Future<Map<String, dynamic>> getMe() async {
    final resp = await http.get(_uri('/api/v1/user/me'), headers: await _headers());
    return _parse(resp);
  }

  static Future<Map<String, dynamic>> getProfile() async {
    final resp = await http.get(_uri('/api/v1/user/profile'), headers: await _headers());
    return _parse(resp);
  }
  static Future<Map<String, dynamic>> getGoals() async {
    final resp = await http.get(_uri('/api/v1/user/goals'), headers: await _headers());
    return _parse(resp);
  }
  static Future<Map<String, dynamic>> getWeekly() async {
    final resp = await http.get(_uri('/api/v1/user/weekly'), headers: await _headers());
    return _parse(resp);
  }

  static Future<List<String>> getCustomFillers() async {
    final resp = await http.get(_uri('/api/v1/user/fillers'), headers: await _headers());
    final data = _parse(resp);
    return List<String>.from(data['fillers'] as List? ?? []);
  }

  static Future<List<String>> addCustomFiller(String word) async {
    final resp = await http.post(
      _uri('/api/v1/user/fillers'),
      headers: await _headers(),
      body: json.encode({'word': word}),
    );
    final data = _parse(resp);
    return List<String>.from(data['fillers'] as List? ?? []);
  }

  static Future<List<String>> removeCustomFiller(String word) async {
    final resp = await http.delete(
      _uri('/api/v1/user/fillers/${Uri.encodeComponent(word)}'),
      headers: await _headers(),
    );
    final data = _parse(resp);
    return List<String>.from(data['fillers'] as List? ?? []);
  }

  static Future<Map<String, dynamic>> getDashboard({String period = '30d'}) async {
    final resp = await http.get(
      _uri('/api/v1/dashboard?period=$period'),
      headers: await _headers(),
    );
    return _parse(resp);
  }

  static Future<List<dynamic>> getRecordings({int limit = 20, int offset = 0}) async {
    final resp = await http.get(
      _uri('/api/v1/recordings?limit=$limit&offset=$offset'),
      headers: await _headers(),
    );
    return _parseList(resp);
  }

  static Future<Map<String, dynamic>> compareRecordings(int idA, int idB) async {
    final resp = await http.get(
      _uri('/api/v1/recordings/compare?recording_a=$idA&recording_b=$idB'),
      headers: await _headers(),
    );
    return _parse(resp);
  }

  static Future<Map<String, dynamic>> uploadRecording(File file) async {
    final token = await AuthTokens.load();
    final req = http.MultipartRequest('POST', _uri('/api/v1/recordings/upload'));
    if (token != null) req.headers['Authorization'] = 'Bearer $token';

    final ext = file.path.split('.').last.toLowerCase();
    req.files.add(await http.MultipartFile.fromPath(
      'file',
      file.path,
      filename: 'audio.$ext',
    ));
    req.headers['Accept'] = 'application/json';

    final streamed = await req.send().timeout(const Duration(seconds: 60));
    final resp = await http.Response.fromStream(streamed);
    if (resp.statusCode == 401) {
      _handleUnauthorized();
      throw const ApiException('Сессия истекла. Войдите снова.', 401);
    }
    final body = json.decode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
    if (resp.statusCode < 200 || resp.statusCode >= 300 || body['success'] != true) {
      throw ApiException(
        (body['error'] ?? 'HTTP ${resp.statusCode}').toString(),
        resp.statusCode,
      );
    }
    return body['data'] as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> getTaskStatus(String taskId) async {
    final resp = await http.get(
      _uri('/api/v1/recordings/status/$taskId'),
      headers: await _headers(),
    );
    return _parse(resp);
  }

  static Future<AnalysisResult> uploadAndAnalyze(
    File file, {
    void Function(String message, int pct)? onProgress,
  }) async {
    onProgress?.call('Загрузка аудио...', 5);
    final upload = await uploadRecording(file);
    final taskId = upload['task_id'] as String;
    for (int i = 0; i < kAnalysisPollMaxAttempts; i++) {
      await Future.delayed(kAnalysisPollInterval);
      final status = await getTaskStatus(taskId);
      final st = status['status'] as String;
      final pct = (status['progress_pct'] as int?) ?? 0;
      final msg = (status['message'] as String?) ?? 'Обработка...';
      onProgress?.call(msg, pct);
      if (st == 'done') {
        final analysisId = (status['analysis_id'] as num?)?.toInt();
        if (analysisId == null) throw const ApiException('Анализ завершён, но ID не получен');
        return getAnalysis(analysisId);
      }
      if (st == 'error') {
        throw ApiException(status['error'] as String? ?? 'Ошибка анализа');
      }
    }
    throw const ApiException('Превышено время ожидания анализа');
  }
  static Future<AnalysisResult> getAnalysis(int id) async {
    final resp = await http.get(_uri('/api/v1/analysis/$id'), headers: await _headers());
    final data = _parse(resp);
    _patchAudioUrl(data);
    return AnalysisResult.fromApi(data);
  }
  static void _patchAudioUrl(Map<String, dynamic> data) {
    final url = data['audio_url'];
    if (url is String && url.isNotEmpty && !url.startsWith('http')) {
      data['audio_url'] = '$_baseUrl$url';
    }
  }

  static Future<String?> downloadAudioToTemp(String url) async {
    try {
      final token = await AuthTokens.load();
      final resp = await http.get(
        Uri.parse(url),
        headers: {
          if (token != null) 'Authorization': 'Bearer $token',
          'Accept': 'audio/mpeg, audio/*',
        },
      ).timeout(const Duration(seconds: 60));
      if (resp.statusCode != 200) return null;
      final dir = await getTemporaryDirectory();
      final file = File(
          '${dir.path}/rech_${DateTime.now().millisecondsSinceEpoch}.mp3');
      await file.writeAsBytes(resp.bodyBytes);
      return file.path;
    } catch (e) {
      debugPrint('Api.downloadAudioToTemp failed: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>> getProgressOverview({String period = '30d'}) async {
    final resp = await http.get(
      _uri('/api/v1/progress/overview?period=$period'),
      headers: await _headers(),
    );
    return _parse(resp);
  }

  static Future<Map<String, dynamic>> getDynamics({String period = '30d'}) async {
    final resp = await http.get(
      _uri('/api/v1/progress/dynamics?period=$period'),
      headers: await _headers(),
    );
    return _parse(resp);
  }

  static Future<Map<String, dynamic>> getActivity() async {
    final resp = await http.get(_uri('/api/v1/progress/activity'), headers: await _headers());
    return _parse(resp);
  }

  static Future<Map<String, dynamic>> getParameterDynamics(
      {String period = '30d'}) async {
    final resp = await http.get(
      _uri('/api/v1/progress/parameter_dynamics?period=$period'),
      headers: await _headers(),
    );
    return _parse(resp);
  }


  static Future<Map<String, dynamic>> getTips() async {
    final resp = await http.get(_uri('/api/v1/tips'), headers: await _headers());
    return _parse(resp);
  }
}
class AuthService {
  static Future<bool> isLoggedIn() async {
    final token = await AuthTokens.load();
    return token != null && token.isNotEmpty;
  }

  static Future<void> logout() async {
    await AuthTokens.clear();
  }
}
