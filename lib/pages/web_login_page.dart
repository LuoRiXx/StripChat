import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';
import '../services/web_data_fetcher.dart';

class WebLoginPage extends StatefulWidget {
  const WebLoginPage({super.key});

  @override
  State<WebLoginPage> createState() => _WebLoginPageState();
}

class _WebLoginPageState extends State<WebLoginPage> {
  late final WebViewController _controller;
  bool _isLoading = true;
  double _progress = 0;

  static const String _autoCloseJs = '''
    (function() {
      const style = document.createElement('style');
      style.innerHTML = `
        header, .header-container, .top-navigation,
        .footer, .footer-container, .install-app-banner,
        .download-app-banner, .promo-banner, .cookie-notice {
          display: none !important;
        }
        body, html { background: #121212 !important; }
      `;
      document.head.appendChild(style);

      // 轮询检测登录成功
      const checker = setInterval(function(){
        try {
          if (window.__stripchat && window.__stripchat.user && window.__stripchat.user.id) {
            FlutterLoginBridge.postMessage('logged_in');
            clearInterval(checker);
            return;
          }
          const dataEl = document.querySelector('[data-user-id]');
          if (dataEl && dataEl.getAttribute('data-user-id')) {
            FlutterLoginBridge.postMessage('logged_in');
            clearInterval(checker);
            return;
          }
          if (document.cookie.indexOf('stripchat_com_sessionId') !== -1 &&
              document.cookie.indexOf('SessionRemember') === -1 &&
              window.location.pathname !== '/auth/login') {
            FlutterLoginBridge.postMessage('maybe_logged_in');
          }
        } catch(e){}
      }, 1500);
    })();
  ''';

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  void _initWebView() {
    final params = WebKitWebViewControllerCreationParams(
      allowsInlineMediaPlayback: true,
      mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
    );

    _controller = WebViewController.fromPlatformCreationParams(params)
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF121212))
      ..setUserAgent(
        'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) '
        'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 '
        'Mobile/15E148 Safari/604.1',
      )
      ..addJavaScriptChannel(
        'FlutterLoginBridge',
        onMessageReceived: (msg) async {
          if (msg.message == 'logged_in') {
            await _onLoginSuccess();
          }
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (p) {
            if (mounted) setState(() => _progress = p / 100);
          },
          onPageStarted: (_) {
            if (mounted) setState(() => _isLoading = true);
          },
          onPageFinished: (url) async {
            await _controller.runJavaScript(_autoCloseJs);
            if (mounted) setState(() => _isLoading = false);
            // 登录成功后通常会跳转到首页
            if (!url.contains('/auth/') && !url.contains('/login')) {
              await _checkLogin();
            }
          },
        ),
      )
      ..loadRequest(
        Uri.parse('https://zh.stripchat.com/auth/login'),
      );
  }

  Future<void> _checkLogin() async {
    final isLoggedIn = await WebDataFetcher().isLoggedIn();
    if (isLoggedIn) await _onLoginSuccess();
  }

  Future<void> _onLoginSuccess() async {
    // 重新加载后台 fetcher 让它读取最新 cookie
    await WebDataFetcher().reloadSession();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('登录成功！'),
        backgroundColor: Color(0xFFFF4081),
        duration: Duration(seconds: 1),
      ),
    );
    await Future.delayed(const Duration(milliseconds: 600));
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('登录 / 注册',
            style: TextStyle(color: Colors.white, fontSize: 18)),
        actions: [
          IconButton(
            onPressed: () => _controller.reload(),
            icon: const Icon(Icons.refresh, color: Colors.white),
          ),
        ],
        bottom: _isLoading
            ? PreferredSize(
                preferredSize: const Size.fromHeight(2),
                child: LinearProgressIndicator(
                  value: _progress,
                  backgroundColor: Colors.black,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFFFF4081)),
                ),
              )
            : null,
      ),
      body: WebViewWidget(controller: _controller),
    );
  }
}
