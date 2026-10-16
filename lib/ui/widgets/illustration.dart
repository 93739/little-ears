import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme.dart';

/// Small original vector illustrations. No network images or external fonts.
class CoverArt extends StatelessWidget {
  const CoverArt({
    super.key,
    this.scene = 'bunny',
    this.color = const Color(0xFFE6EADD),
    this.radius = 24,
    this.hero = false,
  });
  final String scene;
  final Color color;
  final double radius;
  final bool hero;
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(radius),
    child: ColoredBox(
      color: color,
      child: CustomPaint(
        painter: _ArtPainter(scene, hero),
        child: const SizedBox.expand(),
      ),
    ),
  );
}

class _ArtPainter extends CustomPainter {
  _ArtPainter(this.scene, this.hero);
  final String scene;
  final bool hero;
  void oval(Canvas c, double x, double y, double w, double h, Color color) =>
      c.drawOval(
        Rect.fromCenter(center: Offset(x, y), width: w, height: h),
        Paint()..color = color,
      );
  void line(Canvas c, Offset a, Offset b, Color color, double width) =>
      c.drawLine(
        a,
        b,
        Paint()
          ..color = color
          ..strokeWidth = width
          ..strokeCap = StrokeCap.round,
      );
  void star(Canvas c, double x, double y, double r, Color color) {
    final p = Path();
    for (var i = 0; i < 8; i++) {
      final angle = i * math.pi / 4;
      final distance = i.isEven ? r : r * .3;
      final dx = x + math.cos(angle) * distance,
          dy = y + math.sin(angle) * distance;
      if (i == 0) {
        p.moveTo(dx, dy);
      } else {
        p.lineTo(dx, dy);
      }
    }
    p.close();
    c.drawPath(p, Paint()..color = color);
  }

  void eyes(
    Canvas c,
    double x,
    double y,
    double spread, {
    bool sleepy = false,
  }) {
    for (final sign in [-1, 1]) {
      if (sleepy) {
        c.drawArc(
          Rect.fromCenter(
            center: Offset(x + spread * sign, y - 2),
            width: 9,
            height: 8,
          ),
          0,
          math.pi,
          false,
          Paint()
            ..color = ink
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.4
            ..strokeCap = StrokeCap.round,
        );
      } else {
        oval(c, x + spread * sign, y, 4.5, 6, ink);
      }
    }
  }

  void cloud(Canvas c, double x, double y, double scale) {
    oval(c, x, y, 65 * scale, 27 * scale, const Color(0xFFFFFCF2));
    oval(
      c,
      x - 12 * scale,
      y - 9 * scale,
      31 * scale,
      32 * scale,
      const Color(0xFFFFFCF2),
    );
    oval(
      c,
      x + 9 * scale,
      y - 15 * scale,
      36 * scale,
      42 * scale,
      const Color(0xFFFFFCF2),
    );
  }

  void bunny(Canvas c, {bool sleepy = false}) {
    const white = Color(0xFFFFFCF2), pink = Color(0xFFEBAA98);
    oval(c, 105, 163, 98, 110, white);
    c.save();
    c.translate(86, 65);
    c.rotate(-.18);
    oval(c, 0, 0, 26, 78, white);
    oval(c, 0, -4, 12, 51, pink);
    c.restore();
    c.save();
    c.translate(125, 65);
    c.rotate(.13);
    oval(c, 0, 0, 26, 78, white);
    oval(c, 0, -4, 12, 51, pink);
    c.restore();
    oval(c, 105, 111, 93, 81, white);
    oval(c, 74, 121, 15, 9, pink.withValues(alpha: .55));
    oval(c, 136, 121, 15, 9, pink.withValues(alpha: .55));
    eyes(c, 105, 112, 17, sleepy: sleepy);
    oval(c, 105, 122, 7, 5, pink);
    c.drawArc(
      const Rect.fromLTWH(98, 123, 14, 10),
      0,
      math.pi,
      false,
      Paint()
        ..color = ink
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke,
    );
    // Headphones.
    c.drawArc(
      const Rect.fromLTWH(55, 68, 100, 84),
      math.pi,
      math.pi,
      false,
      Paint()
        ..color = ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..strokeCap = StrokeCap.round,
    );
    for (final x in [58.0, 152.0]) {
      c.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(x, 111), width: 17, height: 33),
          const Radius.circular(8),
        ),
        Paint()..color = coral,
      );
    }
    oval(c, 81, 204, 42, 18, white);
    oval(c, 132, 204, 42, 18, white);
    oval(c, 72, 167, 24, 41, white);
    oval(c, 144, 167, 24, 41, white);
    oval(c, 105, 173, 33, 35, const Color(0xFFF3D5B6));
    star(c, 105, 173, 10, coral);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final scale = math.min(size.width / 220, size.height / 230);
    canvas.save();
    canvas.translate(
      (size.width - 220 * scale) / 2,
      (size.height - 230 * scale) / 2,
    );
    canvas.scale(scale);
    star(canvas, 32, 56, 7, const Color(0xFFE9AF55));
    star(canvas, 186, 82, 9, Colors.white.withValues(alpha: .8));
    if (hero || scene == 'bunny') {
      oval(canvas, 112, 212, 174, 17, ink.withValues(alpha: .07));
      cloud(canvas, 177, 38, .65);
      bunny(canvas, sleepy: false);
      star(canvas, 180, 155, 8, coral);
      line(canvas, const Offset(26, 144), const Offset(35, 140), ink, 3);
      line(canvas, const Offset(35, 140), const Offset(35, 160), ink, 3);
      oval(canvas, 30, 161, 11, 7, ink);
    } else if (scene == 'sun') {
      for (var i = 0; i < 12; i++) {
        final a = i * math.pi / 6;
        line(
          canvas,
          Offset(110 + math.cos(a) * 58, 108 + math.sin(a) * 58),
          Offset(110 + math.cos(a) * 72, 108 + math.sin(a) * 72),
          const Color(0xFFEAB75C),
          6,
        );
      }
      oval(canvas, 110, 108, 92, 92, const Color(0xFFF6C65F));
      eyes(canvas, 110, 105, 15);
      canvas.drawArc(
        const Rect.fromLTWH(101, 112, 18, 13),
        0,
        math.pi,
        false,
        Paint()
          ..color = ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5,
      );
      cloud(canvas, 58, 166, 1.2);
      cloud(canvas, 167, 161, .8);
    } else if (scene == 'moon') {
      oval(canvas, 112, 103, 108, 108, const Color(0xFFFFF2C5));
      oval(canvas, 137, 84, 92, 96, const Color(0xFFDFE3EF));
      eyes(canvas, 92, 111, 13, sleepy: true);
      star(canvas, 159, 149, 15, const Color(0xFFFFF2C5));
      star(canvas, 63, 54, 11, const Color(0xFFFFF2C5));
      cloud(canvas, 102, 184, 1.8);
    } else if (scene == 'rainbow') {
      const colors = [
        Color(0xFFDC8D71),
        Color(0xFFE5B771),
        Color(0xFF9CB59A),
        Color(0xFFA8B7C5),
      ];
      for (var i = 0; i < 4; i++) {
        final r = 76 - i * 16.0;
        canvas.drawArc(
          Rect.fromCircle(center: const Offset(110, 151), radius: r),
          math.pi,
          math.pi,
          false,
          Paint()
            ..color = colors[i]
            ..strokeWidth = 13
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round,
        );
      }
      cloud(canvas, 42, 158, .9);
      cloud(canvas, 178, 158, .9);
    } else if (scene == 'fruit') {
      oval(canvas, 89, 137, 83, 91, coral);
      oval(canvas, 126, 137, 81, 91, const Color(0xFFF1946C));
      line(canvas, const Offset(108, 97), const Offset(112, 76), ink, 6);
      canvas.save();
      canvas.translate(130, 82);
      canvas.rotate(-.5);
      oval(canvas, 0, 0, 36, 17, const Color(0xFF7B9C73));
      canvas.restore();
      eyes(canvas, 109, 137, 17);
      star(canvas, 172, 189, 9, const Color(0xFFFFFBEE));
    } else if (scene == 'flowers') {
      line(
        canvas,
        const Offset(110, 128),
        const Offset(110, 207),
        const Color(0xFF789572),
        7,
      );
      canvas.save();
      canvas.translate(91, 176);
      canvas.rotate(.6);
      oval(canvas, 0, 0, 45, 22, const Color(0xFF8FA882));
      canvas.restore();
      for (var i = 0; i < 6; i++) {
        final a = i * math.pi / 3;
        oval(
          canvas,
          110 + math.cos(a) * 30,
          105 + math.sin(a) * 30,
          42,
          42,
          const Color(0xFFFFF9E8),
        );
      }
      oval(canvas, 110, 105, 39, 39, const Color(0xFFF3C76B));
      eyes(canvas, 110, 104, 8);
      oval(canvas, 110, 213, 104, 12, ink.withValues(alpha: .06));
    } else {
      cloud(canvas, 110, 97, 2);
      eyes(canvas, 110, 94, 20);
      for (var i = 0; i < 4; i++) {
        line(
          canvas,
          Offset(62 + i * 32, 153),
          Offset(56 + i * 32, 172),
          const Color(0xFF8DAEB7),
          5,
        );
      }
      star(canvas, 172, 190, 9, const Color(0xFFEAB75C));
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ArtPainter oldDelegate) =>
      scene != oldDelegate.scene || hero != oldDelegate.hero;
}
