import 'dart:async';
import 'dart:convert';
import 'dart:ui' show Color;
import 'package:flutter/foundation.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

/// 后台隐藏的 WebView，用于绕过 Cloudflare 拿到 stripchat 的真实 API 数据。
/// 同时所有 WebViewWidget 共享同一个 cookie store，用户在直播间登录后
/// 这里的请求自动是已登录态。
class WebDataFetcher extends ChangeNotifier {
  static final WebDataFetcher _instance = WebDataFetcher._();
  factory WebDataFetcher() => _instance;
  WebDataFetcher._();

  WebViewController? _controller;
  bool _isReady = false;
  Completer<void> _readyCompleter = Completer<void>();
  final Map<String, Completer<String?>> _pending = {};
  int _seq = 0;

  bool get isReady => _isReady;
  WebViewController? get controller => _controller;

  WebViewController initController() {
    if (_controller != null) return _controller!;

    final params = WebKitWebViewControllerCreationParams(
      allowsInlineMediaPlayback: true,
      mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
    );

    _controller = WebViewController.fromPlatformCreationParams(params)
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color.fromARGB(0, 0, 0, 0))
      ..setUserAgent(
        'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) '
        'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 '
        'Mobile/15E148 Safari/604.1',
      )
      ..addJavaScriptChannel(
        'FlutterBridge',
        onMessageReceived: _onMessage,
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (url) async {
            if (url.contains('stripchat.com')) {
              await Future.delayed(const Duration(milliseconds: 800));
              if (!_isReady) {
                _isReady = true;
                if (!_readyCompleter.isCompleted) {
                  _readyCompleter.complete();
                }
                notifyListeners();
              }
            }
          },
          onWebResourceError: (err) {
            // ignore
          },
        ),
      )
      ..loadRequest(Uri.parse('https://zh.stripchat.com/girls'));

    return _controller!;
  }

  void _onMessage(JavaScriptMessage msg) {
    try {
      final data = jsonDecode(msg.message) as Map<String, dynamic>;
      final id = data['id'] as String;
      final body = data['body'] as String?;
      _pending[id]?.complete(body);
      _pending.remove(id);
    } catch (_) {
      // ignore malformed
    }
  }

  Future<void> waitReady({Duration timeout = const Duration(seconds: 25)}) {
    if (_isReady) return Future.value();
    return _readyCompleter.future.timeout(timeout, onTimeout: () {});
  }

  Future<String?> fetchJson(String url) async {
    if (_controller == null) initController();
    if (!_isReady) {
      await waitReady();
      if (!_isReady) return null;
    }

    final id = 'r${++_seq}_${DateTime.now().millisecondsSinceEpoch}';
    final completer = Completer<String?>();
    _pending[id] = completer;

    final escaped = url
        .replaceAll('\\', '\\\\')
        .replaceAll('"', '\\"');

    final js = '''
      (function(){
        try {
          fetch("$escaped", {
            credentials: 'include',
            headers: { 'Accept': 'application/json, text/plain, */*' }
          })
          .then(function(r){ return r.text(); })
          .then(function(t){
            FlutterBridge.postMessage(JSON.stringify({id:"$id", body:t}));
          })
          .catch(function(e){
            FlutterBridge.postMessage(JSON.stringify({id:"$id", body:null}));
          });
        } catch(e) {
          FlutterBridge.postMessage(JSON.stringify({id:"$id", body:null}));
        }
      })();
    ''';

    try {
      await _controller!.runJavaScript(js);
    } catch (_) {
      _pending.remove(id);
      return null;
    }

    return completer.future.timeout(
      const Duration(seconds: 12),
      onTimeout: () {
        _pending.remove(id);
        return null;
      },
    );
  }

  Future<bool> isLoggedIn() async {
    final raw = await fetchJson(
        'https://zh.stripchat.com/api/front/v3/config/initial-dynamic?requestPath=%2F');
    if (raw == null) return false;
    try {
      final data = jsonDecode(raw);
      final cfg = data['initialDynamic'] ?? data;
      final userId = cfg['userId'] ?? cfg['user']?['id'];
      return userId != null && userId is int && userId > 0;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>?> getCurrentUser() async {
    final raw = await fetchJson(
        'https://zh.stripchat.com/api/front/v3/config/initial-dynamic?requestPath=%2F');
    if (raw == null) return null;
    try {
      final data = jsonDecode(raw);
      final cfg = data['initialDynamic'] ?? data;
      final user = cfg['user'];
      if (user is Map<String, dynamic>) return user;
      return null;
    } catch (_) {
      return null;
    }
  }

  /// 强制重新加载，重置 ready 状态（用户登录后调用）
  Future<void> reloadSession() async {
    _isReady = false;
    _readyCompleter = Completer<void>();
    await _controller?.reload();
  }
}
