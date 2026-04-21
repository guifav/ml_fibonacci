import 'dart:math';
import 'dart:ui';

import 'palette.dart';

/// Draws a procedural spiral shell centered at [center] with [radius].
/// [pulse] is 0..1 — amount of golden glow around a charged shell.
void paintShell(
  Canvas canvas, {
  required Offset center,
  required double radius,
  required int colorIdx,
  double pulse = 0.0,
  double scale = 1.0,
  double opacity = 1.0,
}) {
  if (opacity <= 0) return;
  final colors = shellColors[colorIdx];
  final r = radius * scale;
  final alpha = (opacity * 255).clamp(0, 255).toInt();

  // Soft drop shadow
  final shadow = Paint()
    ..color = Color.fromARGB((alpha * 0.45).toInt(), 0, 0, 0)
    ..maskFilter = MaskFilter.blur(BlurStyle.normal, 4);
  canvas.drawCircle(center + Offset(2, 4), r, shadow);

  // Charged glow — stacked halos pulsing outward
  if (pulse > 0.01) {
    for (final ring in [
      (pulse * 1.5, 0.55),
      (pulse * 1.1, 0.35),
      (pulse * 0.7, 0.22),
    ]) {
      final gp = Paint()
        ..color = Color.fromARGB(
          (alpha * ring.$2).toInt(),
          0xFF,
          0xE6,
          0x78,
        )
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 8 + ring.$1 * 4);
      canvas.drawCircle(center, r * (1.0 + ring.$1 * 0.15), gp);
    }
  }

  // Body
  canvas.drawCircle(
    center,
    r,
    Paint()..color = colors.base.withAlpha(alpha),
  );

  // Rim
  canvas.drawCircle(
    center,
    r,
    Paint()
      ..color = colors.shadow.withAlpha(alpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2,
  );

  // Highlight blob (upper-left)
  canvas.drawCircle(
    center + Offset(-r * 0.35, -r * 0.4),
    r * 0.22,
    Paint()..color = colors.highlight.withAlpha(alpha),
  );

  // Logarithmic (golden) spiral on top
  const phi = 1.618033988749895;
  final b = log(phi) / (pi / 2);
  const steps = 110;
  const maxTheta = 4 * pi; // two full turns
  final a = (r * 0.95) / exp(b * maxTheta);
  final path = Path();
  for (var i = 0; i <= steps; i++) {
    final theta = maxTheta * i / steps;
    final rr = a * exp(b * theta);
    final p = center + Offset(cos(theta) * rr, sin(theta) * rr);
    if (i == 0) {
      path.moveTo(p.dx, p.dy);
    } else {
      path.lineTo(p.dx, p.dy);
    }
  }
  canvas.drawPath(
    path,
    Paint()
      ..color = colors.shadow.withAlpha(alpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round,
  );

  // Tiny center dot
  canvas.drawCircle(
    center,
    2,
    Paint()..color = colors.shadow.withAlpha(alpha),
  );
}
