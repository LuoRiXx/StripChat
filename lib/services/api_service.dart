import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import '../models/model_data.dart';
import 'web_data_fetcher.dart';

class ApiService {
  static const String baseUrl = 'https://zh.stripchat.com';
  static const String apiBase = '$baseUrl/api/front';
  static const String imageBase = 'https://static-proxy.strpst.com';

  String? _jwtToken;
  String? _csrfToken;
  String? _sessionId;
  int? _userId;

  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  String _generateUniq() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final rng = Random();
    return List.generate(16, (_) => chars[rng.nextInt(chars.length)]).join();
  }

  Map<String, String> get _headers => {
        'Accept': 'application/json, text/plain, */*',
        'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
        'User-Agent':
            'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1',
        'Referer': '$baseUrl/',
        'Origin': baseUrl,
        'Sec-Fetch-Dest': 'empty',
        'Sec-Fetch-Mode': 'cors',
        'Sec-Fetch-Site': 'same-origin',
        'X-Requested-With': 'XMLHttpRequest',
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
    cookies.add('isRecommendationDisabled=false');
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

  String fixImageUrl(String url) {
    if (url.isEmpty) return '';
    if (url.startsWith('http')) return url;
    return '$imageBase$url';
  }

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
    int limit = 60,
    int offset = 0,
    String sortBy = 'recommendedScore',
    String primaryTag = 'girls',
  }) async {
    final uniq = _generateUniq();
    final apiUrl =
        '$apiBase/models?limit=$limit&offset=$offset&primaryTag=$primaryTag'
        '&filterGroupTags=%5B%5B%22recommended%22%5D%5D'
        '&sortBy=$sortBy&userRole=user&nic=true&rcmGrp=A'
        '&rbCnGr=true&iem=true&decMb=true&ctryTop=true'
        '&mlfv=false&rectf=false&uniq=$uniq';

    // 1) 优先用后台 WebView 拉（绕过 CF）
    final viaWeb = await _fetchModelsViaWebView(apiUrl);
    if (viaWeb.isNotEmpty) return viaWeb;

    // 2) 尝试直接 HTTP
    try {
      final response = await http
          .get(Uri.parse(apiUrl), headers: _headers)
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> models = data['models'] ?? [];
        final parsed = models
            .map((m) => ModelData.fromJson(m as Map<String, dynamic>))
            .where((m) => m.status == 'public' || m.isLive)
            .toList();
        if (parsed.isNotEmpty) return parsed;
      }
    } catch (_) {}

    // 3) V2 端点
    try {
      final v2 = await _getModelsV2(limit: limit, primaryTag: primaryTag);
      if (v2.isNotEmpty) return v2;
    } catch (_) {}

    // 4) 兜底
    return await _getModelsFromAsset();
  }

  Future<List<ModelBlock>> getModelBlocks({
    String primaryTag = 'girls',
    int limit = 24,
  }) async {
    final uniq = _generateUniq();
    final url = '$apiBase/v2/models?primaryTag=$primaryTag&limit=$limit'
        '&topLimit=61&favoritesLimit=24&removeShows=true'
        '&msBlock=true&byw=false&flags=0&srwm=false'
        '&rcmGrp=A&rbCnGr=true&iem=true&decMb=true'
        '&ctryTop=true&mlfv=false&rectf=false&nic=true&uniq=$uniq';

    // 1) WebView 优先
    try {
      final raw = await WebDataFetcher().fetchJson(url);
      if (raw != null && raw.isNotEmpty && !raw.trimLeft().startsWith('<')) {
        final data = jsonDecode(raw);
        final blocks = _parseBlocks(data);
        if (blocks.isNotEmpty) return blocks;
      }
    } catch (_) {}

    // 2) 直接 HTTP
    try {
      final response = await http
          .get(Uri.parse(url), headers: _headers)
          .timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final blocks = _parseBlocks(data);
        if (blocks.isNotEmpty) return blocks;
      }
    } catch (_) {}

    // 3) 兜底：用普通 getModels 包装成一个 block
    final fallback = await getModels(
      limit: 60,
      primaryTag: primaryTag,
      sortBy: 'recommendedScore',
    );
    if (fallback.isEmpty) return [];
    return [
      ModelBlock(
        id: 'fallback',
        title: '推荐主播',
        models: fallback,
      ),
    ];
  }

  List<ModelBlock> _parseBlocks(dynamic data) {
    if (data is! Map<String, dynamic>) return [];
    final List<dynamic> raw = data['blocks'] ?? [];
    final blocks = <ModelBlock>[];
    for (final b in raw) {
      if (b is Map<String, dynamic>) {
        final block = ModelBlock.fromJson(b);
        if (block.models.isNotEmpty) blocks.add(block);
      }
    }
    return blocks;
  }

  Future<List<ModelData>> _fetchModelsViaWebView(String url) async {
    try {
      final raw = await WebDataFetcher().fetchJson(url);
      if (raw == null || raw.isEmpty) return [];
      // CF challenge 返回 HTML，不是 JSON
      if (raw.trimLeft().startsWith('<')) return [];
      final data = jsonDecode(raw);
      final List<dynamic> models = data['models'] ?? [];
      return models
          .map((m) => ModelData.fromJson(m as Map<String, dynamic>))
          .where((m) => m.status == 'public' || m.isLive)
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<ModelData>> _getModelsFromAsset() async {
    try {
      final raw =
          await rootBundle.loadString('assets/sample_data/models.json');
      final data = jsonDecode(raw);
      final List<dynamic> models = data['models'] ?? [];
      return models
          .map((m) => ModelData.fromJson(m as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<ModelData>> _getModelsV2({
    int limit = 24,
    String primaryTag = 'girls',
  }) async {
    try {
      final uniq = _generateUniq();
      final uri = Uri.parse(
          '$apiBase/v2/models?primaryTag=$primaryTag&limit=$limit'
          '&topLimit=61&favoritesLimit=24&removeShows=true'
          '&msBlock=true&byw=false&flags=0&srwm=false'
          '&rcmGrp=A&rbCnGr=true&iem=true&decMb=true'
          '&ctryTop=true&mlfv=false&rectf=false&nic=true&uniq=$uniq');
      final response = await http
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<ModelData> allModels = [];

        if (data['blocks'] != null) {
          for (final block in data['blocks']) {
            final List<dynamic> models = block['models'] ?? [];
            allModels.addAll(
              models
                  .map((m) => ModelData.fromJson(m as Map<String, dynamic>))
                  .where((m) => m.status == 'public' || m.isLive),
            );
          }
        }
        return allModels;
      }
    } catch (e) {
      // Silently fail
    }
    return [];
  }

  Future<List<ModelData>> searchModels(String query) async {
    final uniq = _generateUniq();
    final url =
        '$apiBase/models?limit=50&offset=0&primaryTag=girls'
        '&sortBy=recommendedScore&q=${Uri.encodeQueryComponent(query)}'
        '&userRole=user&nic=true&uniq=$uniq';

    final viaWeb = await _fetchModelsViaWebView(url);
    if (viaWeb.isNotEmpty) return viaWeb;

    try {
      final response = await http
          .get(Uri.parse(url), headers: _headers)
          .timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> models = data['models'] ?? [];
        final parsed = models
            .map((m) => ModelData.fromJson(m as Map<String, dynamic>))
            .toList();
        if (parsed.isNotEmpty) return parsed;
      }
    } catch (_) {}

    final all = await _getModelsFromAsset();
    final q = query.toLowerCase();
    return all
        .where((m) => m.username.toLowerCase().contains(q))
        .toList();
  }

  Future<Map<String, dynamic>?> getBroadcastInfo(String username) async {
    final uniq = _generateUniq();
    final url = '$apiBase/v1/broadcasts/$username?uniq=$uniq';

    // WebView 优先
    try {
      final raw = await WebDataFetcher().fetchJson(url);
      if (raw != null && raw.isNotEmpty && !raw.trimLeft().startsWith('<')) {
        final data = jsonDecode(raw);
        final item = data['item'];
        if (item is Map<String, dynamic>) return item;
      }
    } catch (_) {}

    try {
      final response = await http
          .get(Uri.parse(url), headers: _headers)
          .timeout(const Duration(seconds: 6));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['item'] as Map<String, dynamic>?;
      }
    } catch (_) {}
    return null;
  }

  Future<String?> getLiveHlsUrl(String username, {String? fallbackStreamName}) async {
    final info = await getBroadcastInfo(username);
    if (info != null) {
      final isLive = info['isLive'] == true || info['status'] == 'public';
      final streamName = info['streamName']?.toString() ?? '';
      if (isLive && streamName.isNotEmpty) {
        return 'https://edge-hls.doppiocdn.com/hls/$streamName/master/$streamName.m3u8';
      }
    }
    if (fallbackStreamName != null && fallbackStreamName.isNotEmpty) {
      return 'https://edge-hls.doppiocdn.com/hls/$fallbackStreamName/master/$fallbackStreamName.m3u8';
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> getChatMessages(int modelId) async {
    try {
      final uniq = _generateUniq();
      final uri = Uri.parse(
          '$apiBase/v2/models/$modelId/chat?source=regular&uniq=$uniq');
      final response = await http.get(uri, headers: _headers);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> messages = data['messages'] ?? [];
        return messages.cast<Map<String, dynamic>>();
      }
    } catch (e) {
      // Silently fail
    }
    return [];
  }

  String getHlsUrl(int modelId, {String quality = 'auto'}) {
    return 'https://edge-hls.doppiocdn.com/hls/$modelId/master/${modelId}_auto.m3u8';
  }

  String getHlsHighestUrl(int modelId, List<String> presets) {
    if (presets.isEmpty) {
      return getHlsUrl(modelId);
    }
    final best = presets.first;
    return 'https://edge-hls.doppiocdn.com/hls/$modelId/master/${modelId}_$best.m3u8';
  }

  String getWebSocketUrl() {
    final auth = _sessionId ?? '';
    return 'wss://comet.stripchat.com/comet2?auth=$auth&host=stripchat.com';
  }
}
