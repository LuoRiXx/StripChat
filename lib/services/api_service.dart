import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/model_data.dart';

class ApiService {
  static const String baseUrl = 'https://zh.stripchat.com';
  static const String apiBase = '$baseUrl/api/front';

  String? _jwtToken;
  String? _csrfToken;
  String? _sessionId;
  int? _userId;

  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  Map<String, String> get _headers => {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'User-Agent':
            'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1',
        'Referer': '$baseUrl/',
        'Origin': baseUrl,
        if (_jwtToken != null) 'Authorization': 'Bearer $_jwtToken',
        if (_csrfToken != null) 'X-Csrf-Token': _csrfToken!,
        'Cookie': _buildCookie(),
      };

  String _buildCookie() {
    final cookies = <String>[];
    if (_sessionId != null) {
      cookies.add('stripchat_com_sessionId=$_sessionId');
      cookies.add('stripchat_com_sessionRemember=1');
    }
    cookies.add('localeDomain=zh');
    cookies.add('alreadyVisited=1');
    cookies.add('isVisitorsAgreementAccepted=1');
    return cookies.join('; ');
  }

  void setTokens({
    String? jwt,
    String? csrf,
    String? sessionId,
    int? userId,
  }) {
    _jwtToken = jwt;
    _csrfToken = csrf;
    _sessionId = sessionId;
    _userId = userId;
  }

  bool get isAuthenticated => _jwtToken != null && _jwtToken!.isNotEmpty;
  int? get userId => _userId;
  String? get jwtToken => _jwtToken;

  Future<Map<String, dynamic>?> login(
      String username, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$apiBase/v3/auth/login'),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'User-Agent':
              'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15',
          'Origin': baseUrl,
          'Referer': '$baseUrl/',
          'Cookie':
              'localeDomain=zh; alreadyVisited=1; isVisitorsAgreementAccepted=1',
        },
        body: jsonEncode({
          'login': username,
          'password': password,
          'remember': true,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final setCookie = response.headers['set-cookie'] ?? '';
        final sessionMatch =
            RegExp(r'stripchat_com_sessionId=([^;]+)').firstMatch(setCookie);
        if (sessionMatch != null) {
          _sessionId = sessionMatch.group(1);
        }
        return data;
      }

      // Try fetching initial dynamic config instead
      return await _fetchInitialConfig(username);
    } catch (e) {
      return await _fetchInitialConfig(username);
    }
  }

  Future<Map<String, dynamic>?> _fetchInitialConfig(String username) async {
    try {
      final response = await http.get(
        Uri.parse(
            '$apiBase/v3/config/initial-dynamic?requestPath=%2Fuser%2F$username'),
        headers: _headers,
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final dynamic config = data['initialDynamic'];
        if (config != null) {
          _jwtToken = config['jwtToken'];
          _csrfToken = config['csrfToken'];
          _userId = config['guestId'];
          _sessionId = config['sessionHash'];
          return config;
        }
      }
    } catch (e) {
      // Silently fail
    }
    return null;
  }

  Future<List<ModelData>> getModels({
    int limit = 50,
    int offset = 0,
    String sortBy = 'stripScore',
    String primaryTag = 'girls',
  }) async {
    try {
      final uri = Uri.parse(
          '$apiBase/v3/models?limit=$limit&offset=$offset&primaryTag=$primaryTag&sortBy=$sortBy&parentTag=$primaryTag');
      final response = await http.get(uri, headers: _headers);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> models =
            data['models'] ?? data['filteredModels'] ?? [];
        return models
            .map((m) => ModelData.fromJson(m as Map<String, dynamic>))
            .where((m) => m.status == 'public' || m.isLive)
            .toList();
      }
    } catch (e) {
      // Silently fail
    }
    return [];
  }

  Future<List<ModelData>> searchModels(String query) async {
    try {
      final uri = Uri.parse(
          '$apiBase/v3/models?limit=50&offset=0&q=$query&sortBy=stripScore');
      final response = await http.get(uri, headers: _headers);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> models =
            data['models'] ?? data['filteredModels'] ?? [];
        return models
            .map((m) => ModelData.fromJson(m as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      // Silently fail
    }
    return [];
  }

  Future<ModelData?> getModelDetail(String username) async {
    try {
      final uri = Uri.parse('$apiBase/models/$username');
      final response = await http.get(uri, headers: _headers);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final modelJson = data['model'] ?? data;
        return ModelData.fromJson(modelJson as Map<String, dynamic>);
      }
    } catch (e) {
      // Silently fail
    }
    return null;
  }

  String getHlsUrl(int modelId) {
    return 'https://edge-hls.doppiocdn.com/hls/$modelId/master/${modelId}_auto.m3u8';
  }

  String getHlsHighUrl(int modelId) {
    return 'https://edge-hls.doppiocdn.com/hls/$modelId/master/${modelId}.m3u8';
  }

  String getSnapshotUrl(int modelId) {
    return 'https://img.strpst.com/thumbs/$modelId/${modelId}_webp';
  }

  String getWebSocketUrl() {
    final auth = _sessionId ?? '';
    return 'wss://comet.stripchat.com/comet2?auth=$auth&host=stripchat.com';
  }

  Future<List<ModelData>> getFavorites() async {
    if (_userId == null) return [];
    try {
      final uri = Uri.parse('$apiBase/favorites?userId=$_userId');
      final response = await http.get(uri, headers: _headers);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> models = data['models'] ?? data['favorites'] ?? [];
        return models
            .map((m) => ModelData.fromJson(m as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      // Silently fail
    }
    return [];
  }
}
