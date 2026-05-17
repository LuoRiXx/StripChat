import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import '../models/model_data.dart';
import '../services/favorites_service.dart';
import '../widgets/chat_widget.dart';

class LiveRoomPage extends StatefulWidget {
  final ModelData model;

  const LiveRoomPage({super.key, required this.model});

  @override
  State<LiveRoomPage> createState() => _LiveRoomPageState();
}

class _LiveRoomPageState extends State<LiveRoomPage> {
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  bool _isLoading = true;
  bool _hasError = false;
  bool _isFullscreen = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  @override
  void dispose() {
    _chewieController?.dispose();
    _videoController?.dispose();
    // Restore portrait orientation when leaving
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  Future<void> _initPlayer() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    final hlsUrl = widget.model.hlsBestUrl.isNotEmpty
        ? widget.model.hlsBestUrl
        : widget.model.hlsUrl;

    try {
      _videoController = VideoPlayerController.networkUrl(
        Uri.parse(hlsUrl),
        httpHeaders: {
          'User-Agent':
              'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15',
          'Referer': 'https://zh.stripchat.com/',
        },
      );

      await _videoController!.initialize();

      _chewieController = ChewieController(
        videoPlayerController: _videoController!,
        autoPlay: true,
        looping: false,
        showControls: true,
        showOptions: false,
        allowFullScreen: true,
        allowPlaybackSpeedChanging: false,
        placeholder: Container(
          color: Colors.black,
          child: const Center(
            child: CircularProgressIndicator(color: Color(0xFFFF4081)),
          ),
        ),
        errorBuilder: (context, errorMessage) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.white54, size: 42),
                const SizedBox(height: 8),
                Text(
                  '视频加载失败',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: _retryPlayer,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF4081),
                  ),
                  child: const Text('重试'),
                ),
              ],
            ),
          );
        },
        fullScreenByDefault: false,
        routePageBuilder: (context, animation, secondaryAnimation, controllerProvider) {
          return _buildFullscreenPlayer(controllerProvider);
        },
      );

      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = '无法加载直播流';
        });
      }
    }
  }

  Widget _buildFullscreenPlayer(Widget controllerProvider) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(child: controllerProvider),
    );
  }

  void _retryPlayer() {
    _chewieController?.dispose();
    _videoController?.dispose();
    _initPlayer();
  }

  void _toggleFullscreen() {
    setState(() {
      _isFullscreen = !_isFullscreen;
    });

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

  @override
  Widget build(BuildContext context) {
    if (_isFullscreen) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: GestureDetector(
          onTap: () {},
          onDoubleTap: _toggleFullscreen,
          child: Stack(
            children: [
              Center(
                child: _buildVideoPlayer(),
              ),
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
                onPressed: () {
                  fav.toggleFavorite(widget.model);
                },
                icon: Icon(
                  isFav ? Icons.favorite : Icons.favorite_border,
                  color: isFav ? const Color(0xFFFF4081) : Colors.white,
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
          // Video player area
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Container(
              color: Colors.black,
              child: _buildVideoPlayer(),
            ),
          ),
          // Info bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A2E),
              border: Border(
                bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
              ),
            ),
            child: Row(
              children: [
                if (widget.model.age > 0) ...[
                  _buildInfoChip(Icons.cake, '${widget.model.age}岁'),
                  const SizedBox(width: 12),
                ],
                if (widget.model.country.isNotEmpty) ...[
                  _buildInfoChip(Icons.location_on, widget.model.country),
                  const SizedBox(width: 12),
                ],
                if (widget.model.isHd)
                  _buildInfoChip(Icons.hd, 'HD'),
                const Spacer(),
                Consumer<FavoritesService>(
                  builder: (context, fav, _) {
                    final isFav = fav.isFavorite(widget.model.id);
                    return TextButton.icon(
                      onPressed: () => fav.toggleFavorite(widget.model),
                      icon: Icon(
                        isFav ? Icons.favorite : Icons.favorite_border,
                        size: 18,
                        color: isFav
                            ? const Color(0xFFFF4081)
                            : Colors.white70,
                      ),
                      label: Text(
                        isFav ? '已收藏' : '收藏',
                        style: TextStyle(
                          color: isFav
                              ? const Color(0xFFFF4081)
                              : Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          // Chat area
          Expanded(
            child: ChatWidget(model: widget.model),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoPlayer() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFFFF4081)),
            SizedBox(height: 12),
            Text(
              '正在加载直播...',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ],
        ),
      );
    }

    if (_hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.white54, size: 48),
            const SizedBox(height: 12),
            Text(
              _errorMessage,
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _retryPlayer,
              icon: const Icon(Icons.refresh),
              label: const Text('重试'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF4081),
              ),
            ),
          ],
        ),
      );
    }

    if (_chewieController != null) {
      return Chewie(controller: _chewieController!);
    }

    return const SizedBox.shrink();
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.white.withValues(alpha: 0.6)),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }
}
