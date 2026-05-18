import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';
import '../models/model_data.dart';
import '../services/api_service.dart';
import '../services/favorites_service.dart';
import '../widgets/danmaku_layer.dart';

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
  final ApiService _api = ApiService();
  final GlobalKey<DanmakuLayerState> _danmakuKey = GlobalKey();
  final List<_HeartAnim> _hearts = [];
  final Set<String> _seenMessages = {};
  late final List<ModelData> _playlist;
  late int _currentIndex;
  late ModelData _currentModel;
  WebViewController? _controller;
  Timer? _chatTimer;
  Timer? _hideControlsTimer;
  _DanmakuMode _danmakuMode = _DanmakuMode.third;
  bool _isFullscreen = false;
  bool _showControls = true;
  bool _isLoading = true;
  double _progress = 0;
  String? _tip;

  @override
  void initState() {
    super.initState();
    _playlist = widget.playlist.isNotEmpty ? List.from(widget.playlist) : [widget.model];
    _currentIndex = widget.startIndex.clamp(0, _playlist.length - 1);
    _currentModel = _playlist[_currentIndex];
    _initController();
    _startAutoHideControls();
    Future.microtask(_ensureCurrentLiveAndLoad);
  }

  @override
  void dispose() {
    _chatTimer?.cancel();
    _hideControlsTimer?.cancel();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _initController() {
    final params = WebKitWebViewControllerCreationParams(
      allowsInlineMediaPlayback: true,
      mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
    );
    _controller = WebViewController.fromPlatformCreationParams(params)
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setUserAgent(
        'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 '
        '(KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1',
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (value) {
            if (mounted) setState(() => _progress = value / 100);
          },
          onPageFinished: (_) {
            _injectPlayerStyle();
            if (mounted) setState(() => _isLoading = false);
            _startChatPolling();
          },
        ),
      );
  }

  Future<void> _ensureCurrentLiveAndLoad() async {
    final live = await _isLive(_currentModel);
    if (!mounted) return;
    if (live) {
      _loadModel(_currentModel);
      return;
    }
    if (_playlist.length > 1) {
      setState(() => _tip = '${_currentModel.username} 未开播，已跳过');
      await _goToNextLive(forward: true);
    } else {
      setState(() {
        _isLoading = false;
        _tip = '${_currentModel.username} 当前未开播';
      });
    }
  }

  Future<bool> _isLive(ModelData model) async {
    if (model.isCurrentlyLive) return true;
    try {
      final info = await _api.getBroadcastInfo(model.username);
      final status = info?['status']?.toString() ?? '';
      return info?['isLive'] == true ||
          status == 'public' ||
          status == 'private' ||
          status == 'p2p' ||
          status == 'groupShow' ||
          status == 'virtualPrivate';
    } catch (_) {
      return false;
    }
  }

  void _loadModel(ModelData model) {
    _chatTimer?.cancel();
    _seenMessages.clear();
    _danmakuKey.currentState?.clear();
    setState(() {
      _currentModel = model;
      _isLoading = true;
      _progress = 0;
      _tip = null;
    });
    _controller?.loadRequest(Uri.parse('https://zh.stripchat.com/${model.username}'));
  }

  void _injectPlayerStyle() {
    _controller?.runJavaScript('''
      (function(){
        var style = document.createElement('style');
        style.innerHTML = 'header,footer,nav,.header,.footer,.sidebar,.model-list,.categories-bar,.bottom-bar,[class*=banner],[class*=Banner],[class*=promo],[class*=Promo]{display:none!important}body{margin:0!important;background:#000!important;overflow:hidden!important}video,[class*=player],[class*=Player],[class*=broadcast],[class*=Broadcast]{width:100vw!important;height:100vh!important;max-width:100vw!important;max-height:100vh!important;object-fit:contain!important;background:#000!important}';
        document.head.appendChild(style);
      })();
    ''');
  }

  Future<void> _goToNextLive({required bool forward}) async {
    if (_playlist.length <= 1) return;
    final step = forward ? 1 : -1;
    var idx = _currentIndex;
    for (var i = 0; i < _playlist.length - 1; i++) {
      idx = (idx + step) % _playlist.length;
      if (idx < 0) idx += _playlist.length;
      final model = _playlist[idx];
      if (await _isLive(model)) {
        if (!mounted) return;
        setState(() => _currentIndex = idx);
        _loadModel(model);
        return;
      }
      if (mounted) setState(() => _tip = '${model.username} 未开播，跳过...');
    }
    if (!mounted) return;
    setState(() => _tip = '列表中暂无正在直播的主播');
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _tip = null);
    });
  }

  Future<void> _goRandomLive() async {
    if (_playlist.length <= 1) return;
    final indexes = List<int>.generate(_playlist.length, (i) => i)..shuffle(Random());
    for (final idx in indexes.where((i) => i != _currentIndex)) {
      final model = _playlist[idx];
      if (await _isLive(model)) {
        if (!mounted) return;
        setState(() => _currentIndex = idx);
        _loadModel(model);
        return;
      }
    }
    if (mounted) setState(() => _tip = '列表中暂无正在直播的主播');
  }

  void _enterFullscreen() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    setState(() => _isFullscreen = true);
  }

  void _exitFullscreen() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    setState(() => _isFullscreen = false);
  }

  void _cycleDanmakuMode() {
    setState(() {
      switch (_danmakuMode) {
        case _DanmakuMode.third:
          _danmakuMode = _DanmakuMode.full;
          break;
        case _DanmakuMode.full:
          _danmakuMode = _DanmakuMode.off;
          _danmakuKey.currentState?.clear();
          break;
        case _DanmakuMode.off:
          _danmakuMode = _DanmakuMode.third;
          break;
      }
    });
  }

  void _startAutoHideControls() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _showControls = false);
    });
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) _startAutoHideControls();
  }

  void _onDoubleTap(TapDownDetails details) {
    final favorites = FavoritesService();
    if (!favorites.isFavorite(_currentModel.id)) {
      favorites.addFavorite(_currentModel);
    }
    final heart = _HeartAnim(DateTime.now().microsecondsSinceEpoch, details.localPosition);
    setState(() => _hearts.add(heart));
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _hearts.removeWhere((h) => h.id == heart.id));
    });
  }

  void _startChatPolling() {
    _chatTimer?.cancel();
    _chatTimer = Timer.periodic(const Duration(seconds: 5), (_) => _pollChat());
    _pollChat();
  }

  Future<void> _pollChat() async {
    if (_danmakuMode == _DanmakuMode.off || !mounted) return;
    final messages = await _api.getChatMessages(_currentModel.id);
    if (!mounted) return;
    for (final msg in messages.take(8)) {
      final text = (msg['message'] ?? msg['text'] ?? '').toString().trim();
      if (text.isEmpty) continue;
      final user = (msg['username'] ?? msg['user']?['username'] ?? '').toString();
      final key = '$user|$text';
      if (!_seenMessages.add(key)) continue;
      _danmakuKey.currentState?.push(user.isEmpty ? text : '$user: $text');
    }
  }

  String get _danmakuLabel {
    switch (_danmakuMode) {
      case _DanmakuMode.third:
        return '弹幕1/3';
      case _DanmakuMode.full:
        return '全屏弹幕';
      case _DanmakuMode.off:
        return '弹幕关闭';
    }
  }

  IconData get _danmakuIcon {
    switch (_danmakuMode) {
      case _DanmakuMode.off:
        return Icons.subtitles_off;
      case _DanmakuMode.third:
        return Icons.splitscreen;
      case _DanmakuMode.full:
        return Icons.subtitles;
    }
  }

  @override
  Widget build(BuildContext context) {
    return _isFullscreen ? _buildFullscreen() : _buildPortrait();
  }

  Widget _buildPortrait() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            _topBar(),
            _videoBox(aspectRatio: 16 / 9, fullscreen: false),
            if (_tip != null) _tipBar(),
            _controlBar(compact: false),
            Expanded(child: _modelInfo()),
          ],
        ),
      ),
    );
  }

  Widget _buildFullscreen() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(child: _videoContent(fullscreen: true)),
          Positioned.fill(child: _gestureLayer()),
          ..._hearts.map((h) => _HeartWidget(key: ValueKey(h.id), anim: h)),
          if (_showControls) _fullscreenControls(),
          if (_tip != null) Positioned(left: 20, bottom: 74, child: _smallTip()),
        ],
      ),
    );
  }

  Widget _videoBox({required double aspectRatio, required bool fullscreen}) {
    return AspectRatio(
      aspectRatio: aspectRatio,
      child: Stack(
        children: [
          Positioned.fill(child: _videoContent(fullscreen: fullscreen)),
          Positioned.fill(child: _gestureLayer()),
          ..._hearts.map((h) => _HeartWidget(key: ValueKey(h.id), anim: h)),
        ],
      ),
    );
  }

  Widget _videoContent({required bool fullscreen}) {
    return Stack(
      children: [
        if (_controller != null) Positioned.fill(child: WebViewWidget(controller: _controller!)),
        if (_danmakuMode != _DanmakuMode.off)
          Positioned.fill(
            child: DanmakuLayer(
              key: _danmakuKey,
              trackCount: _danmakuMode == _DanmakuMode.third ? 3 : (fullscreen ? 8 : 5),
              speed: fullscreen ? 125 : 105,
              opacity: 0.82,
              fontSize: fullscreen ? 16 : 14,
              heightFraction: _danmakuMode == _DanmakuMode.third ? 1 / 3 : 1,
              verticalAlign: -1,
            ),
          ),
        if (_isLoading)
          Center(
            child: CircularProgressIndicator(
              value: _progress > 0 ? _progress : null,
              color: const Color(0xFFFF4081),
            ),
          ),
      ],
    );
  }

  Widget _gestureLayer() {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: _toggleControls,
      onDoubleTapDown: _onDoubleTap,
      onDoubleTap: () {},
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity;
        if (velocity == null) return;
        if (velocity < -300) _goToNextLive(forward: true);
        if (velocity > 300) _goToNextLive(forward: false);
      },
    );
  }

  Widget _topBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: Text(
              _currentModel.username,
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: Icon(_danmakuIcon, color: _danmakuMode == _DanmakuMode.off ? Colors.white54 : const Color(0xFFFF4081)),
            onPressed: _cycleDanmakuMode,
          ),
          Consumer<FavoritesService>(
            builder: (context, fav, _) {
              final liked = fav.isFavorite(_currentModel.id);
              return IconButton(
                icon: Icon(liked ? Icons.favorite : Icons.favorite_border, color: liked ? const Color(0xFFFF4081) : Colors.white),
                onPressed: () => fav.toggleFavorite(_currentModel),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _controlBar({required bool compact}) {
    return Container(
      color: const Color(0xFF1A1A2E),
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _controlButton(Icons.skip_previous_rounded, '上一个', () => _goToNextLive(forward: false)),
          _controlButton(Icons.shuffle_rounded, '随机', _goRandomLive),
          _controlButton(Icons.skip_next_rounded, '下一个', () => _goToNextLive(forward: true)),
          _controlButton(_danmakuIcon, _danmakuLabel, _cycleDanmakuMode),
          _controlButton(Icons.refresh_rounded, '刷新', () => _loadModel(_currentModel)),
          _controlButton(Icons.fullscreen_rounded, '全屏', _enterFullscreen),
        ],
      ),
    );
  }

  Widget _fullscreenControls() {
    return Stack(
      children: [
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 26),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.black.withValues(alpha: 0.75), Colors.transparent],
              ),
            ),
            child: Row(
              children: [
                IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: _exitFullscreen),
                Expanded(
                  child: Text(
                    _currentModel.username,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(icon: Icon(_danmakuIcon, color: _danmakuMode == _DanmakuMode.off ? Colors.white54 : const Color(0xFFFF4081)), onPressed: _cycleDanmakuMode),
                Consumer<FavoritesService>(
                  builder: (context, fav, _) {
                    final liked = fav.isFavorite(_currentModel.id);
                    return IconButton(
                      icon: Icon(liked ? Icons.favorite : Icons.favorite_border, color: liked ? const Color(0xFFFF4081) : Colors.white),
                      onPressed: () => fav.toggleFavorite(_currentModel),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            padding: const EdgeInsets.fromLTRB(8, 24, 8, 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Colors.black.withValues(alpha: 0.75), Colors.transparent],
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _miniControl(Icons.skip_previous_rounded, '上一个', () => _goToNextLive(forward: false)),
                _miniControl(Icons.shuffle_rounded, '随机', _goRandomLive),
                _miniControl(Icons.skip_next_rounded, '下一个', () => _goToNextLive(forward: true)),
                _miniControl(_danmakuIcon, _danmakuLabel, _cycleDanmakuMode),
                _miniControl(Icons.fullscreen_exit_rounded, '退出', _exitFullscreen),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _controlButton(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 21),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _miniControl(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 22),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _tipBar() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: Colors.orange.withValues(alpha: 0.18),
      child: Text(_tip!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.orangeAccent, fontSize: 13)),
    );
  }

  Widget _smallTip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(8)),
      child: Text(_tip!, style: const TextStyle(color: Colors.orangeAccent, fontSize: 12)),
    );
  }

  Widget _modelInfo() {
    return Container(
      width: double.infinity,
      color: const Color(0xFF121212),
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: const Color(0xFF2A2A3E),
                  backgroundImage: _currentModel.fullAvatarUrl.isNotEmpty ? NetworkImage(_currentModel.fullAvatarUrl) : null,
                  child: _currentModel.fullAvatarUrl.isEmpty ? const Icon(Icons.person, color: Colors.white54) : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_currentModel.username, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(
                        '${_currentModel.viewerCount} 观看  ${_currentIndex + 1}/${_playlist.length}',
                        style: const TextStyle(color: Colors.white54, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (_currentModel.isCurrentlyLive) _tag('正在直播', Colors.redAccent),
                if (_currentModel.isHd) _tag('HD', Colors.blueAccent),
                if (_currentModel.isNew) _tag('新人', Colors.greenAccent),
                if (_currentModel.isMobile) _tag('手机直播', Colors.orangeAccent),
                if (_currentModel.isLovense) _tag('Lovense', Colors.pinkAccent),
                _tag(_danmakuLabel, const Color(0xFFFF4081)),
              ],
            ),
            const SizedBox(height: 16),
            Text('竖屏双击视频可快速收藏，左右滑动可切换主播。', style: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _tag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(text, style: TextStyle(color: color, fontSize: 12)),
    );
  }
}

enum _DanmakuMode { off, third, full }

class _HeartAnim {
  final int id;
  final Offset position;
  const _HeartAnim(this.id, this.position);
}

class _HeartWidget extends StatefulWidget {
  final _HeartAnim anim;
  const _HeartWidget({super.key, required this.anim});

  @override
  State<_HeartWidget> createState() => _HeartWidgetState();
}

class _HeartWidgetState extends State<_HeartWidget> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;
  late final Animation<Offset> _offset;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 850));
    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: 1.35), weight: 35),
      TweenSequenceItem(tween: Tween(begin: 1.35, end: 1.0), weight: 25),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.15), weight: 40),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _opacity = Tween<double>(begin: 1, end: 0).animate(CurvedAnimation(parent: _controller, curve: const Interval(0.55, 1, curve: Curves.easeIn)));
    _offset = Tween<Offset>(begin: Offset.zero, end: const Offset(0, -72)).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Positioned(
          left: widget.anim.position.dx - 26,
          top: widget.anim.position.dy - 26 + _offset.value.dy,
          child: Opacity(
            opacity: _opacity.value,
            child: Transform.scale(
              scale: _scale.value,
              child: const Icon(Icons.favorite, color: Color(0xFFFF4081), size: 52),
            ),
          ),
        );
      },
    );
  }
}
