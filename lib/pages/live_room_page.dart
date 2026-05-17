import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';
import '../models/model_data.dart';
import '../services/favorites_service.dart';

class LiveRoomPage extends StatefulWidget {
  final ModelData model;
  final List<ModelData> playlist;
  final int startIndex;

  const LiveRoomPage({
    super.key,
    required this.model,
    this.playlist = const [],
    this.startIndex = 0,
  });

  @override
  State<LiveRoomPage> createState() => _LiveRoomPageState();
}

class _LiveRoomPageState extends State<LiveRoomPage> {
  late final WebViewController _controller;
  late int _currentIndex;
  late ModelData _currentModel;
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

  bool get _hasPlaylist => widget.playlist.isNotEmpty;
  bool get _hasPrev => _hasPlaylist && _currentIndex > 0;
  bool get _hasNext =>
      _hasPlaylist && _currentIndex < widget.playlist.length - 1;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.startIndex;
    _currentModel = _hasPlaylist && _currentIndex < widget.playlist.length
        ? widget.playlist[_currentIndex]
        : widget.model;
    _initWebView();
  }

  void _initWebView() {
    final params = WebKitWebViewControllerCreationParams(
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
        Uri.parse('https://zh.stripchat.com/${_currentModel.username}'),
        headers: const {'Referer': 'https://zh.stripchat.com/'},
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

  void _switchTo(int index) {
    if (!_hasPlaylist) return;
    if (index < 0 || index >= widget.playlist.length) return;
    setState(() {
      _currentIndex = index;
      _currentModel = widget.playlist[index];
      _isLoading = true;
      _progress = 0;
    });
    _controller.loadRequest(
      Uri.parse('https://zh.stripchat.com/${_currentModel.username}'),
      headers: const {'Referer': 'https://zh.stripchat.com/'},
    );
  }

  void _prev() => _switchTo(_currentIndex - 1);
  void _next() => _switchTo(_currentIndex + 1);

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

  void _reload() => _controller.reload();

  void _handleHorizontalSwipe(DragEndDetails details) {
    final v = details.primaryVelocity ?? 0;
    if (v.abs() < 250) return;
    if (v < 0) {
      _next(); // 左滑下一个
    } else {
      _prev(); // 右滑上一个
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isFullscreen) return _buildFullscreen(context);
    return _buildNormal(context);
  }

  Widget _buildFullscreen(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(child: WebViewWidget(controller: _controller)),
          // 全屏下左右两个透明区域监听滑动切换
          if (_hasPlaylist)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 60,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onHorizontalDragEnd: _handleHorizontalSwipe,
              ),
            ),
          if (_hasPlaylist)
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              width: 60,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onHorizontalDragEnd: _handleHorizontalSwipe,
              ),
            ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 16,
            child: Row(
              children: [
                if (_hasPlaylist) ...[
                  _circleBtn(Icons.skip_previous, _hasPrev ? _prev : null),
                  const SizedBox(width: 8),
                  _circleBtn(Icons.skip_next, _hasNext ? _next : null),
                  const SizedBox(width: 8),
                ],
                _circleBtn(Icons.fullscreen_exit, _toggleFullscreen),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _circleBtn(IconData icon, VoidCallback? onPressed) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon,
            color:
                onPressed == null ? Colors.white38 : Colors.white,
            size: 26),
      ),
    );
  }

  Widget _buildNormal(BuildContext context) {
    final total = widget.playlist.length;
    final position = _hasPlaylist ? '${_currentIndex + 1}/$total' : '';
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
                _currentModel.username.isNotEmpty
                    ? _currentModel.username[0].toUpperCase()
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
                    _currentModel.username,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Row(
                    children: [
                      if (_currentModel.viewerCount > 0)
                        Text(
                          '${_currentModel.viewerCount} 观看',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.6),
                          ),
                        ),
                      if (_hasPlaylist) ...[
                        if (_currentModel.viewerCount > 0)
                          const SizedBox(width: 8),
                        Text(
                          position,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          Consumer<FavoritesService>(
            builder: (context, fav, _) {
              final isFav = fav.isFavorite(_currentModel.id);
              return IconButton(
                onPressed: () => fav.toggleFavorite(_currentModel),
                icon: Icon(
                  isFav ? Icons.favorite : Icons.favorite_border,
                  color:
                      isFav ? const Color(0xFFFF4081) : Colors.white,
                ),
              );
            },
          ),
          IconButton(
            onPressed: _toggleFullscreen,
            icon: const Icon(Icons.fullscreen, color: Colors.white),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                    child: WebViewWidget(controller: _controller)),
                // 屏幕左边缘 50 像素的透明区域接受滑动手势
                if (_hasPlaylist)
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    width: 50,
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onHorizontalDragEnd: _handleHorizontalSwipe,
                    ),
                  ),
                if (_hasPlaylist)
                  Positioned(
                    right: 0,
                    top: 0,
                    bottom: 0,
                    width: 50,
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onHorizontalDragEnd: _handleHorizontalSwipe,
                    ),
                  ),
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
                                  color: Colors.white70, fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          _buildControlBar(),
        ],
      ),
    );
  }

  Widget _buildControlBar() {
    return Container(
      color: const Color(0xFF1A1A2E),
      padding: EdgeInsets.fromLTRB(
        12,
        8,
        12,
        8 + MediaQuery.of(context).padding.bottom,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _ctrlButton(
            icon: Icons.skip_previous_rounded,
            label: '上一个',
            onPressed: _hasPrev ? _prev : null,
          ),
          _ctrlButton(
            icon: Icons.refresh_rounded,
            label: '刷新',
            onPressed: _reload,
          ),
          _ctrlButton(
            icon: Icons.shuffle_rounded,
            label: '随机',
            onPressed: _hasPlaylist
                ? () {
                    final randomIdx = (DateTime.now().millisecondsSinceEpoch %
                            widget.playlist.length)
                        .abs();
                    _switchTo(randomIdx);
                  }
                : null,
          ),
          _ctrlButton(
            icon: Icons.skip_next_rounded,
            label: '下一个',
            onPressed: _hasNext ? _next : null,
          ),
        ],
      ),
    );
  }

  Widget _ctrlButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
  }) {
    final enabled = onPressed != null;
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: enabled
                  ? const Color(0xFFFF4081)
                  : Colors.white.withValues(alpha: 0.2),
              size: 26,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: enabled
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.3),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
