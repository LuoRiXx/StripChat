import 'dart:math';
import 'package:flutter/material.dart';

class DanmakuItem {
  final String id;
  final String text;
  final Color color;
  final double fontSize;
  late int _trackIndex;
  late double _x;
  late double _width;
  DanmakuItem({
    required this.id,
    required this.text,
    this.color = Colors.white,
    this.fontSize = 18,
  });
}

class DanmakuLayer extends StatefulWidget {
  /// 弹幕轨道数（屏幕从上到下分几条线）
  final int trackCount;

  /// 弹幕滚动速度（像素/秒）
  final double speed;

  /// 透明度
  final double opacity;

  /// 字体大小
  final double fontSize;

  /// 弹幕区域占父容器高度比例（0.0 - 1.0），默认 1.0 全屏
  final double heightFraction;

  /// 弹幕区域垂直对齐：-1=顶部, 0=中间, 1=底部
  final double verticalAlign;

  const DanmakuLayer({
    super.key,
    this.trackCount = 6,
    this.speed = 100,
    this.opacity = 0.85,
    this.fontSize = 18,
    this.heightFraction = 1.0,
    this.verticalAlign = 0,
  });

  @override
  State<DanmakuLayer> createState() => DanmakuLayerState();
}

class DanmakuLayerState extends State<DanmakuLayer> {
  final List<DanmakuItem> _activeItems = [];
  late Ticker _ticker;
  int _lastFrameTime = 0;
  Size _size = Size.zero;
  final Map<int, int> _trackLastSpawn = {}; // 每条轨道上次生成时间，避免重叠
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _ticker = Ticker(_onTick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    if (_size == Size.zero) return;
    final now = elapsed.inMilliseconds;
    final dt = _lastFrameTime == 0 ? 16 : (now - _lastFrameTime);
    _lastFrameTime = now;
    final pxPerMs = widget.speed / 1000;

    bool changed = false;
    final toRemove = <DanmakuItem>[];
    for (final item in _activeItems) {
      item._x -= pxPerMs * dt;
      if (item._x + item._width < 0) {
        toRemove.add(item);
      }
      changed = true;
    }
    if (toRemove.isNotEmpty) {
      _activeItems.removeWhere(toRemove.contains);
    }
    if (changed && mounted) setState(() {});
  }

  /// 添加一条弹幕
  void push(String text, {Color? color}) {
    if (text.trim().isEmpty || _size == Size.zero) return;
    final colors = [
      Colors.white,
      const Color(0xFFFFEB3B),
      const Color(0xFFFF4081),
      const Color(0xFF80D8FF),
      const Color(0xFFB388FF),
      const Color(0xFF69F0AE),
    ];
    final picked = color ?? colors[_random.nextInt(colors.length)];
    final fontSize = widget.fontSize;
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(fontSize: fontSize),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final width = tp.width + 24;

    // 选轨道：找空闲最久的轨道
    final now = DateTime.now().millisecondsSinceEpoch;
    int bestTrack = 0;
    int bestAge = -1;
    for (int i = 0; i < widget.trackCount; i++) {
      final age = now - (_trackLastSpawn[i] ?? 0);
      if (age > bestAge) {
        bestAge = age;
        bestTrack = i;
      }
    }
    _trackLastSpawn[bestTrack] = now;

    final item = DanmakuItem(
      id: '${now}_${_random.nextInt(10000)}',
      text: text,
      color: picked,
      fontSize: fontSize,
    )
      .._trackIndex = bestTrack
      .._x = _size.width
      .._width = width;

    _activeItems.add(item);
    if (mounted) setState(() {});
  }

  void clear() {
    _activeItems.clear();
    _trackLastSpawn.clear();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final fullW = constraints.maxWidth;
        final fullH = constraints.maxHeight;
        final fraction = widget.heightFraction.clamp(0.1, 1.0);
        final areaH = fullH * fraction;
        // verticalAlign: -1=顶部 0=中间 1=底部
        final align = widget.verticalAlign.clamp(-1.0, 1.0);
        final top = (fullH - areaH) * (align + 1) / 2;
        // 用弹幕区域尺寸记录给 push() 算坐标
        _size = Size(fullW, areaH);
        final trackHeight = areaH / widget.trackCount;
        return IgnorePointer(
          child: Stack(
            children: [
              Positioned(
                top: top,
                left: 0,
                width: fullW,
                height: areaH,
                child: Opacity(
                  opacity: widget.opacity,
                  child: Stack(
                    children: _activeItems.map((item) {
                      return Positioned(
                        left: item._x,
                        top: item._trackIndex * trackHeight + 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            item.text,
                            style: TextStyle(
                              color: item.color,
                              fontSize: item.fontSize,
                              fontWeight: FontWeight.w600,
                              shadows: const [
                                Shadow(
                                  offset: Offset(1, 1),
                                  blurRadius: 2,
                                  color: Colors.black87,
                                ),
                              ],
                            ),
                            maxLines: 1,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// 用 SchedulerBinding 替代 Ticker 实现简单滚动
class Ticker {
  final TickerCallback onTick;
  bool _running = false;
  late int _start;

  Ticker(this.onTick);

  void start() {
    _running = true;
    _start = DateTime.now().millisecondsSinceEpoch;
    _scheduleNext();
  }

  void _scheduleNext() {
    if (!_running) return;
    Future.delayed(const Duration(milliseconds: 16), () {
      if (!_running) return;
      final elapsed =
          Duration(milliseconds: DateTime.now().millisecondsSinceEpoch - _start);
      onTick(elapsed);
      _scheduleNext();
    });
  }

  void dispose() {
    _running = false;
  }
}

typedef TickerCallback = void Function(Duration elapsed);
