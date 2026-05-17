import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';
import '../models/model_data.dart';
import '../services/favorites_service.dart';

class LiveRoomPage extends StatefulWidget {
  final ModelData model;

  const LiveRoomPage({super.key, required this.model});

  @override
  State<LiveRoomPage> createState() => _LiveRoomPageState();
}

class _LiveRoomPageState extends State<LiveRoomPage> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _isFullscreen = false;
  double _progress = 0;

  static const String _hideUiJs = '''
    (function() {
      const style = document.createElement('style');
      style.innerHTML = `
        header, .header-container, .top-navigation,
        .footer, .footer-container, .promo-banner,
        .cookie-notice, .age-verification-modal,
        [data-test="header"], [data-test="footer"],
        .left-side-menu, .right-side-menu,
        .ad-banner, .advertisement,
        .install-app-banner, .download-app-banner {
          display: none !important;
        }
        body, html { background: #000 !important; margin: 0 !important; padding: 0 !important; }
        .video-player, .player-container, .stream-container {
          width: 100% !important;
          height: 100% !important;
        }
      `;
      document.head.appendChild(style);
    })();
  ''';

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  void _initWebView() {
    late final PlatformWebViewControllerCreationParams params;
    params = WebKitWebViewControllerCreationParams(
      allowsInlineMediaPlayback: true,
      mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
    );

    _controller = WebViewController.fromPlatformCreationParams(params)
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setUserAgent(
        'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) '
        'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 '
        'Mobile/15E148 Safari/604.1',
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (progress) {
            if (mounted) setState(() => _progress = progress / 100);
          },
          onPageStarted: (url) {
            if (mounted) setState(() => _isLoading = true);
          },
          onPageFinished: (url) async {
            await _controller.runJavaScript(_hideUiJs);
            if (mounted) setState(() => _isLoading = false);
          },
          onNavigationRequest: (request) {
            final url = request.url;
            if (url.contains('login') ||
                url.contains('signup') ||
                url.contains('billing') ||
                url.contains('account')) {
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(
        Uri.parse('https://zh.stripchat.com/${widget.model.username}'),
        headers: const {
          'Referer': 'https://zh.stripchat.com/',
        },
      );
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _toggleFullscreen() {
    setState(() => _isFullscreen = !_isFullscreen);
    if (_isFullscreen) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  void _reload() {
    _controller.reload();
  }

  @override
  Widget build(BuildContext context) {
    if (_isFullscreen) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            Positioned.fill(child: WebViewWidget(controller: _controller)),
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              right: 16,
              child: IconButton(
                onPressed: _toggleFullscreen,
                icon: const Icon(Icons.fullscreen_exit,
                    color: Colors.white, size: 30),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: const Color(0xFF2A2A3E),
              child: Text(
                widget.model.username.isNotEmpty
                    ? widget.model.username[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                  color: Color(0xFFFF4081),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.model.username,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (widget.model.viewerCount > 0)
                    Text(
                      '${widget.model.viewerCount} 观看',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          Consumer<FavoritesService>(
            builder: (context, fav, _) {
              final isFav = fav.isFavorite(widget.model.id);
              return IconButton(
                onPressed: () => fav.toggleFavorite(widget.model),
                icon: Icon(
                  isFav ? Icons.favorite : Icons.favorite_border,
                  color: isFav ? const Color(0xFFFF4081) : Colors.white,
                ),
              );
            },
          ),
          IconButton(
            onPressed: _reload,
            icon: const Icon(Icons.refresh, color: Colors.white),
          ),
          IconButton(
            onPressed: _toggleFullscreen,
            icon: const Icon(Icons.fullscreen, color: Colors.white),
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(child: WebViewWidget(controller: _controller)),
          if (_isLoading)
            Positioned.fill(
              child: Container(
                color: Colors.black,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(
                        color: Color(0xFFFF4081),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '加载直播中... ${(_progress * 100).toInt()}%',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
