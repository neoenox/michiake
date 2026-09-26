import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A browser-only walkthrough of the fog-clearing visual.
/// It does not read GPS or write to the Android database.
class WebPreviewScreen extends StatefulWidget {
  const WebPreviewScreen({super.key});

  @override
  State<WebPreviewScreen> createState() => _WebPreviewScreenState();
}

class _WebPreviewScreenState extends State<WebPreviewScreen> {
  Timer? _timer;
  double _progress = 0;
  bool _playing = false;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _play() {
    _timer?.cancel();
    var frame = 0;
    setState(() {
      _progress = 0;
      _playing = true;
    });
    _timer = Timer.periodic(const Duration(milliseconds: 35), (timer) {
      if (!mounted) return timer.cancel();
      frame++;
      setState(() => _progress = (frame / 85).clamp(0, 1));
      if (frame >= 85) {
        timer.cancel();
        setState(() => _playing = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xfff4f6f3),
    body: SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
            child: Row(
              children: [
                const Icon(Icons.explore, color: Color(0xff147968)),
                const SizedBox(width: 9),
                const Text(
                  'みちあけ',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const SizedBox(width: 12),
                const _PreviewPill(
                  icon: Icons.visibility_outlined,
                  text: '画面プレビュー',
                ),
                const Spacer(),
                IconButton(
                  tooltip: '履歴',
                  onPressed: () {},
                  icon: const Icon(Icons.calendar_month_outlined),
                ),
                IconButton(
                  tooltip: '設定',
                  onPressed: () {},
                  icon: const Icon(Icons.tune),
                ),
              ],
            ),
          ),
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                CustomPaint(painter: _FogMapPainter(progress: _progress)),
                Positioned(
                  top: 18,
                  left: 18,
                  child: _PreviewPill(
                    icon: Icons.cloud,
                    text: _progress == 1 ? '歩いた場所がひらきました' : '未探索エリア',
                    background: const Color(0xff273541),
                    foreground: Colors.white,
                  ),
                ),
                Positioned(
                  top: 18,
                  right: 18,
                  child: _Legend(
                    opened: _progress > 0,
                  ),
                ),
                Positioned(
                  right: 18,
                  bottom: 156,
                  child: FilledButton.icon(
                    onPressed: _playing ? null : _play,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xff147968),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 15,
                      ),
                      elevation: 3,
                    ),
                    icon: Icon(
                      _playing ? Icons.directions_walk : Icons.play_arrow,
                    ),
                    label: Text(
                      _playing ? 'ルートを探索中' : 'デモ移動を再生',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                Positioned(
                  left: 18,
                  right: 18,
                  bottom: 18,
                  child: _StatusCard(
                    progress: _progress,
                    playing: _playing,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _PreviewPill extends StatelessWidget {
  const _PreviewPill({
    required this.icon,
    required this.text,
    this.background = Colors.white,
    this.foreground = const Color(0xff25312d),
  });

  final IconData icon;
  final String text;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(22),
      boxShadow: const [BoxShadow(color: Color(0x16000000), blurRadius: 8)],
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: foreground),
          const SizedBox(width: 7),
          Text(
            text,
            style: TextStyle(
              color: foreground,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    ),
  );
}

class _Legend extends StatelessWidget {
  const _Legend({required this.opened});
  final bool opened;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      boxShadow: const [BoxShadow(color: Color(0x16000000), blurRadius: 8)],
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _LegendRow(
            color: const Color(0xff35424d),
            label: '未探索（霧）',
          ),
          const SizedBox(height: 7),
          _LegendRow(
            color: const Color(0xff48c4a2),
            label: opened ? '探索済み' : '歩いたルート',
          ),
        ],
      ),
    ),
  );
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 8),
      Text(label, style: const TextStyle(fontSize: 11)),
    ],
  );
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.progress, required this.playing});
  final double progress;
  final bool playing;

  @override
  Widget build(BuildContext context) => Card(
    elevation: 4,
    color: Colors.white,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                playing ? Icons.radar : Icons.cloud_outlined,
                color: const Color(0xff147968),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      playing
                          ? '通った道から霧が晴れています'
                          : progress == 1
                          ? 'このルートを探索しました'
                          : '地図はまだ霧におおわれています',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const Text(
                      'サンプル表示です。GPS記録や端末保存は行いません。',
                      style: TextStyle(fontSize: 11, color: Colors.black54),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: progress == 0 && !playing ? null : () {},
                icon: const Icon(Icons.pause, size: 16),
                label: const Text('探索中'),
              ),
            ],
          ),
          const Divider(height: 18),
          Row(
            children: [
              _Metric(label: '今日ひらいた面積', value: '${(progress * 460).round()}㎡'),
              _Metric(label: '累計探索面積', value: '${(progress * 3240).round()}㎡'),
              _Metric(label: '今日の移動', value: '${(progress * 1200).round()}m'),
            ],
          ),
        ],
      ),
    ),
  );
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: [
        Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 3),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 10, color: Colors.black54),
        ),
      ],
    ),
  );
}

class _FogMapPainter extends CustomPainter {
  const _FogMapPainter({required this.progress});
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    canvas.drawRect(bounds, Paint()..color = const Color(0xffe9eee9));
    _drawMap(canvas, size);

    final points = <Offset>[
      Offset(size.width * .12, size.height * .74),
      Offset(size.width * .29, size.height * .58),
      Offset(size.width * .46, size.height * .63),
      Offset(size.width * .64, size.height * .37),
      Offset(size.width * .87, size.height * .42),
    ];
    final route = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      route.lineTo(point.dx, point.dy);
    }
    final metrics = route.computeMetrics().first;
    final openedPath = metrics.extractPath(0, metrics.length * progress);

    // The opaque fog is composited separately. Clearing the walked corridor
    // reveals the bright street map beneath instead of merely tinting it.
    canvas.saveLayer(bounds, Paint());
    canvas.drawRect(bounds, Paint()..color = const Color(0xe6212d38));
    if (progress > 0) {
      canvas.drawPath(
        openedPath,
        Paint()
          ..blendMode = BlendMode.clear
          ..style = PaintingStyle.stroke
          ..strokeWidth = 64
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }
    canvas.restore();

    if (progress > 0) {
      canvas.drawPath(
        openedPath,
        Paint()
          ..color = const Color(0x5043c8a5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 52
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
      canvas.drawPath(
        openedPath,
        Paint()
          ..color = const Color(0xff13a884)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
      final marker = metrics.getTangentForOffset(metrics.length * progress);
      if (marker != null) {
        canvas.drawCircle(
          marker.position,
          10,
          Paint()..color = const Color(0xff087762),
        );
        canvas.drawCircle(
          marker.position,
          5,
          Paint()..color = Colors.white,
        );
      }
    }
  }

  void _drawMap(Canvas canvas, Size size) {
    final parkPaint = Paint()..color = const Color(0xffc5dfc3);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * .57, size.height * .12, size.width * .31,
            size.height * .27),
        const Radius.circular(30),
      ),
      parkPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * .06, size.height * .64, size.width * .23,
            size.height * .24),
        const Radius.circular(26),
      ),
      parkPaint,
    );
    final road = Paint()
      ..color = const Color(0xfffbfcf8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 13
      ..strokeCap = StrokeCap.round;
    for (var i = -2; i < 8; i++) {
      final x = size.width * i / 5;
      canvas.drawLine(Offset(x, 0), Offset(x + size.height * .42, size.height), road);
      final y = size.height * i / 5;
      canvas.drawLine(Offset(0, y), Offset(size.width, y + size.width * .17), road);
    }
    final minorRoad = Paint()
      ..color = const Color(0xffdce5dc)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (var i = 0; i < 7; i++) {
      final x = size.width * (i + .3) / 7;
      canvas.drawLine(Offset(x, 0), Offset(x + size.height * .18, size.height), minorRoad);
    }
    for (var i = 0; i < 6; i++) {
      final y = size.height * (i + .2) / 6;
      canvas.drawLine(Offset(0, y), Offset(size.width, y + size.width * .08), minorRoad);
    }
    final river = Path()
      ..moveTo(size.width * .89, 0)
      ..cubicTo(size.width * .77, size.height * .24, size.width * .98,
          size.height * .57, size.width * .81, size.height);
    canvas.drawPath(
      river,
      Paint()
        ..color = const Color(0xffb8dce2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(14, size.width * .035),
    );
  }

  @override
  bool shouldRepaint(covariant _FogMapPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
