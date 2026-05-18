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

enum _DanmakuMode { off, third, full }

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
  _DanmakuMode _danmakuMode = _DanmakuMode.full;
  bool _isFullscreen = false;
  bool _showControls = true;
  bool _isLoading = true;
  double _progress = 0;
  String? _tip;

  @override
  void initState() {
    super.initState();
    _playlist = widget.playlist.isNotEmpty
        ? List.from(widget.playlist)
        : [widget.model];
    _currentIndex = widget.startIndex.clamp(0, _playlist.length - 1);
    _currentModel = _playlist[_currentIndex];
    _initController();
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
      // 单个主播且未开播，仍然加载页面（用户也许想看个人主页）
      _loadModel(_currentModel);
      setState(() => _tip = '${_currentModel.username} 当前未开播');
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
    _controller
        ?.loadRequest(Uri.parse('https://zh.stripchat.com/${model.username}'));
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
    final indexes = List<int>.generate(_playlist.length, (i) => i)
      ..shuffle(Random());
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
    setState(() {
      _isFullscreen = true;
      _showControls = true;
    });
    _startAutoHideControls();
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
        case _DanmakuMode.full:
          _danmakuMode = _DanmakuMode.third;
          break;
        case _DanmakuMode.third:
          _danmakuMode = _DanmakuMode.off;
          _danmakuKey.currentState?.clear();
          break;
        case _DanmakuMode.off:
          _danmakuMode = _DanmakuMode.full;
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

  void _onDoubleTapPortrait(Offset position) {
    final favorites = FavoritesService();
    if (!favorites.isFavorite(_currentModel.id)) {
      favorites.addFavorite(_currentModel);
    }
    final heart =
        _HeartAnim(DateTime.now().microsecondsSinceEpoch, position);
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
    // 弹幕只在全屏才用，竖屏不需要轮询
    if (!_isFullscreen || _danmakuMode == _DanmakuMode.off || !mounted) return;
    final messages = await _api.getChatMessages(_currentModel.id);
    if (!mounted) return;
    for (final msg in messages.take(8)) {
      final text = (msg['message'] ?? msg['text'] ?? '').toString().trim();
      if (text.isEmpty) continue;
      final user =
          (msg['username'] ?? msg['user']?['username'] ?? '').toString();
      final key = '$user|$text';
      if (!_seenMessages.add(key)) continue;
      _danmakuKey.currentState?.push(user.isEmpty ? text : '$user: $text');
    }
  }

  String get _danmakuLabel {
    switch (_danmakuMode) {
      case _DanmakuMode.full:
        return '全屏弹幕';
      case _DanmakuMode.third:
        return '弹幕1/3';
      case _DanmakuMode.off:
        return '关闭弹幕';
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
    return PopScope(
      canPop: !_isFullscreen,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _isFullscreen) _exitFullscreen();
      },
      child: _isFullscreen ? _buildFullscreen() : _buildPortrait(),
    );
  }

  // ====== 竖屏：原 stripchat 网页 + 浮动顶栏（返回/标题/全屏） + 实底底栏（操作按钮） ======
  Widget _buildPortrait() {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1F),
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            // 1. 原网页：占满整个 body，stripchat 自己布局视频和聊天
            Positioned.fill(
              child: _controller != null
                  ? WebViewWidget(controller: _controller!)
                  : const ColoredBox(color: Colors.black),
            ),
            // 2. 双击检测层（透明，不消费单击，让 WebView 仍可交互）
            Positioned.fill(
              child: _DoubleTapDetector(
                onDoubleTap: _onDoubleTapPortrait,
                child: const SizedBox.expand(),
              ),
            ),
            // 3. 心动画
            ..._hearts.map((h) => _HeartWidget(key: ValueKey(h.id), anim: h)),
            // 4. 顶部浮动控制栏（返回 / 用户名 / 全屏）
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _portraitTopBar(),
            ),
            // 5. 加载进度
            if (_isLoading)
              Positioned(
                top: 52,
                left: 0,
                right: 0,
                child: LinearProgressIndicator(
                  value: _progress > 0 ? _progress : null,
                  minHeight: 2,
                  backgroundColor: Colors.black.withValues(alpha: 0.2),
                  valueColor:
                      const AlwaysStoppedAnimation(Color(0xFFFF4081)),
                ),
              ),
            // 6. 提示
            if (_tip != null)
              Positioned(
                top: 60,
                left: 16,
                right: 16,
                child: _smallTip(),
              ),
          ],
        ),
      ),
      // 实底底栏：上一个/随机/下一个/刷新/收藏，独立空间不遮挡网页
      bottomNavigationBar: _portraitBottomBar(),
    );
  }

  Widget _portraitTopBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.65),
            Colors.transparent,
          ],
        ),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: '返回',
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: Text(
              _currentModel.username,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                shadows: [
                  Shadow(color: Colors.black54, blurRadius: 4),
                ],
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // 全屏按钮放在右上角
          Container(
            margin: const EdgeInsets.only(right: 4),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.45),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              tooltip: '全屏',
              icon: const Icon(Icons.fullscreen_rounded, color: Colors.white),
              onPressed: _enterFullscreen,
            ),
          ),
        ],
      ),
    );
  }

  Widget _portraitBottomBar() {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A2E),
        border: Border(
          top: BorderSide(color: Color(0xFF2A2A3E), width: 0.6),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 12,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _bottomAction(Icons.skip_previous_rounded, '上一个',
                  () => _goToNextLive(forward: false)),
              _bottomAction(Icons.shuffle_rounded, '随机', _goRandomLive),
              _bottomAction(Icons.skip_next_rounded, '下一个',
                  () => _goToNextLive(forward: true)),
              _bottomAction(Icons.refresh_rounded, '刷新',
                  () => _loadModel(_currentModel)),
              Consumer<FavoritesService>(
                builder: (context, fav, _) {
                  final liked = fav.isFavorite(_currentModel.id);
                  return _bottomAction(
                    liked ? Icons.favorite : Icons.favorite_border,
                    liked ? '已收藏' : '收藏',
                    () => fav.toggleFavorite(_currentModel),
                    activeColor: liked ? const Color(0xFFFF4081) : null,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bottomAction(IconData icon, String label, VoidCallback onTap,
      {Color? activeColor}) {
    final color = activeColor ?? Colors.white;
    final textColor =
        activeColor ?? Colors.white.withValues(alpha: 0.78);
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(color: textColor, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ====== 横屏全屏：WebView + 弹幕（仅此模式有）+ 浮动控制条 ======
  Widget _buildFullscreen() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. WebView 占满
          Positioned.fill(
            child: _controller != null
                ? WebViewWidget(controller: _controller!)
                : const ColoredBox(color: Colors.black),
          ),
          // 2. 弹幕层（仅在全屏才显示）
          if (_danmakuMode != _DanmakuMode.off)
            Positioned.fill(
              child: DanmakuLayer(
                key: _danmakuKey,
                trackCount: _danmakuMode == _DanmakuMode.third ? 3 : 8,
                speed: 130,
                opacity: 0.85,
                fontSize: 16,
                heightFraction:
                    _danmakuMode == _DanmakuMode.third ? 1 / 3 : 1,
                verticalAlign: -1,
              ),
            ),
          // 3. 手势层：单击切换控制条 + 横滑切换主播
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _toggleControls,
              onHorizontalDragEnd: (details) {
                final v = details.primaryVelocity;
                if (v == null) return;
                if (v < -300) _goToNextLive(forward: true);
                if (v > 300) _goToNextLive(forward: false);
              },
            ),
          ),
          // 4. 控制条
          if (_showControls) _fullscreenControls(),
          // 5. 加载进度
          if (_isLoading)
            const Positioned(
              top: 60,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(
                minHeight: 2,
                color: Color(0xFFFF4081),
                backgroundColor: Colors.black26,
              ),
            ),
          // 6. 提示
          if (_tip != null)
            Positioned(left: 20, bottom: 80, child: _smallTip()),
        ],
      ),
    );
  }

  Widget _fullscreenControls() {
    return Stack(
      children: [
        // 顶部
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.75),
                  Colors.transparent,
                ],
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: _exitFullscreen,
                ),
                Expanded(
                  child: Text(
                    _currentModel.username,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  tooltip: _danmakuLabel,
                  icon: Icon(
                    _danmakuIcon,
                    color: _danmakuMode == _DanmakuMode.off
                        ? Colors.white54
                        : const Color(0xFFFF4081),
                  ),
                  onPressed: _cycleDanmakuMode,
                ),
                Consumer<FavoritesService>(
                  builder: (context, fav, _) {
                    final liked = fav.isFavorite(_currentModel.id);
                    return IconButton(
                      icon: Icon(
                        liked ? Icons.favorite : Icons.favorite_border,
                        color: liked
                            ? const Color(0xFFFF4081)
                            : Colors.white,
                      ),
                      onPressed: () => fav.toggleFavorite(_currentModel),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        // 底部
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            padding: const EdgeInsets.fromLTRB(8, 24, 8, 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.75),
                  Colors.transparent,
                ],
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _miniControl(Icons.skip_previous_rounded, '上一个',
                    () => _goToNextLive(forward: false)),
                _miniControl(Icons.shuffle_rounded, '随机', _goRandomLive),
                _miniControl(Icons.skip_next_rounded, '下一个',
                    () => _goToNextLive(forward: true)),
                _miniControl(_danmakuIcon, _danmakuLabel, _cycleDanmakuMode),
                _miniControl(Icons.refresh_rounded, '刷新',
                    () => _loadModel(_currentModel)),
                _miniControl(Icons.fullscreen_exit_rounded, '退出全屏',
                    _exitFullscreen),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _miniControl(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(color: Colors.white70, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _smallTip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        _tip ?? '',
        style: const TextStyle(color: Colors.orangeAccent, fontSize: 13),
      ),
    );
  }
}

// ============== 心形动画 ==============
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

class _HeartWidgetState extends State<_HeartWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;
  late final Animation<Offset> _offset;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 850));
    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: 1.35), weight: 35),
      TweenSequenceItem(tween: Tween(begin: 1.35, end: 1.0), weight: 25),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.15), weight: 40),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _opacity = Tween<double>(begin: 1, end: 0).animate(CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.55, 1, curve: Curves.easeIn)));
    _offset = Tween<Offset>(begin: Offset.zero, end: const Offset(0, -72))
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
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
          child: IgnorePointer(
            child: Opacity(
              opacity: _opacity.value,
              child: Transform.scale(
                scale: _scale.value,
                child: const Icon(Icons.favorite,
                    color: Color(0xFFFF4081), size: 52),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ============== 双击检测：仅观察 PointerDown 时间戳，不消费事件 ==============
// 这样单击事件可以正常透传给底层 WebView，用户依然能与原网页交互
class _DoubleTapDetector extends StatefulWidget {
  final Widget child;
  final void Function(Offset position) onDoubleTap;
  const _DoubleTapDetector({required this.child, required this.onDoubleTap});
  @override
  State<_DoubleTapDetector> createState() => _DoubleTapDetectorState();
}

class _DoubleTapDetectorState extends State<_DoubleTapDetector> {
  DateTime? _lastTapTime;
  Offset? _lastTapPos;

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (event) {
        final now = DateTime.now();
        final last = _lastTapTime;
        final lastPos = _lastTapPos;
        if (last != null &&
            lastPos != null &&
            now.difference(last).inMilliseconds < 320 &&
            (event.localPosition - lastPos).distance < 36) {
          widget.onDoubleTap(event.localPosition);
          _lastTapTime = null;
          _lastTapPos = null;
        } else {
          _lastTapTime = now;
          _lastTapPos = event.localPosition;
        }
      },
      child: widget.child,
    );
  }
}
