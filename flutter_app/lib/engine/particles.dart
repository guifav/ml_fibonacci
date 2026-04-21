import 'dart:math';
import 'dart:ui';

import 'package:flutter/painting.dart';

import 'palette.dart';

class Particle {
  Offset position;
  Offset velocity;
  double life; // seconds remaining
  final double initialLife;
  double size;
  int colorIdx;
  double rotation;
  double angularVelocity;

  Particle({
    required this.position,
    required this.velocity,
    required this.life,
    required this.size,
    required this.colorIdx,
    this.rotation = 0,
    this.angularVelocity = 0,
  }) : initialLife = life;

  bool get isDead => life <= 0;

  void update(double dt) {
    position += velocity * dt;
    velocity += const Offset(0, 620) * dt; // gravity
    velocity = velocity * (1.0 - 1.4 * dt).clamp(0.0, 1.0); // drag
    rotation += angularVelocity * dt;
    life -= dt;
  }

  void render(Canvas canvas) {
    final t = (life / initialLife).clamp(0.0, 1.0);
    final alpha = (t * 255).toInt();
    canvas.save();
    canvas.translate(position.dx, position.dy);
    canvas.rotate(rotation);
    final shell = shellColors[colorIdx];
    // Shell fragment: small triangle wedge
    final path = Path()
      ..moveTo(0, -size)
      ..lineTo(size * 0.9, size * 0.6)
      ..lineTo(-size * 0.9, size * 0.6)
      ..close();
    canvas.drawPath(path, Paint()..color = shell.base.withAlpha(alpha));
    canvas.drawPath(
      path,
      Paint()
        ..color = shell.shadow.withAlpha(alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    canvas.restore();
  }
}

class Sparkle {
  Offset position;
  Offset velocity;
  double life;
  final double initialLife;
  double size;

  Sparkle({
    required this.position,
    required this.velocity,
    required this.life,
    required this.size,
  }) : initialLife = life;

  bool get isDead => life <= 0;

  void update(double dt) {
    position += velocity * dt;
    velocity = velocity * (1.0 - 0.9 * dt).clamp(0.0, 1.0);
    life -= dt;
  }

  void render(Canvas canvas) {
    final t = (life / initialLife).clamp(0.0, 1.0);
    final alpha = (t * 255).toInt();
    final paint = Paint()
      ..color = Color.fromARGB(alpha, 0xFF, 0xF0, 0xA0)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 2);
    canvas.drawCircle(position, size * t, paint);
    canvas.drawCircle(
      position,
      size * t * 0.5,
      Paint()..color = Color.fromARGB(alpha, 255, 255, 255),
    );
  }
}

class ShockRing {
  Offset center;
  double radius = 0;
  final double maxRadius;
  double life;
  final double initialLife;
  final int tierSize;

  ShockRing({
    required this.center,
    required this.maxRadius,
    required this.life,
    required this.tierSize,
  }) : initialLife = life;

  bool get isDead => life <= 0;

  void update(double dt) {
    final t = 1.0 - (life / initialLife).clamp(0.0, 1.0);
    radius = maxRadius * t;
    life -= dt;
  }

  void render(Canvas canvas) {
    final t = (life / initialLife).clamp(0.0, 1.0);
    final alpha = (t * 220).toInt();
    final paint = Paint()
      ..color = Color.fromARGB(alpha, 0xFF, 0xE6, 0x78)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3 + 2 * t;
    canvas.drawCircle(center, radius, paint);
  }
}

class ParticleSystem {
  final List<Particle> particles = [];
  final List<Sparkle> sparkles = [];
  final List<ShockRing> shockRings = [];
  final Random _rng = Random();

  void spawnExplosion(
    Offset center, {
    required int colorIdx,
    required int tierSize,
  }) {
    final intensity = (tierSize / 5.0).clamp(0.6, 3.0);
    final nFragments = (14 * intensity).toInt();
    for (var i = 0; i < nFragments; i++) {
      final angle = (i / nFragments) * 2 * pi + _rng.nextDouble() * 0.4;
      final speed = 160 + _rng.nextDouble() * 200 * intensity;
      particles.add(
        Particle(
          position: center,
          velocity: Offset(cos(angle) * speed, sin(angle) * speed),
          life: 0.7 + _rng.nextDouble() * 0.4,
          size: 5 + _rng.nextDouble() * 4,
          colorIdx: colorIdx,
          rotation: _rng.nextDouble() * 2 * pi,
          angularVelocity: (_rng.nextDouble() - 0.5) * 12,
        ),
      );
    }
    final nSparkles = (18 * intensity).toInt();
    for (var i = 0; i < nSparkles; i++) {
      final angle = _rng.nextDouble() * 2 * pi;
      final speed = 60 + _rng.nextDouble() * 260 * intensity;
      sparkles.add(
        Sparkle(
          position: center,
          velocity: Offset(cos(angle) * speed, sin(angle) * speed),
          life: 0.5 + _rng.nextDouble() * 0.5,
          size: 3 + _rng.nextDouble() * 3,
        ),
      );
    }
    shockRings.add(
      ShockRing(
        center: center,
        maxRadius: 40 + 14 * tierSize.toDouble(),
        life: 0.45,
        tierSize: tierSize,
      ),
    );
  }

  void update(double dt) {
    for (final p in particles) {
      p.update(dt);
    }
    for (final s in sparkles) {
      s.update(dt);
    }
    for (final s in shockRings) {
      s.update(dt);
    }
    particles.removeWhere((p) => p.isDead);
    sparkles.removeWhere((s) => s.isDead);
    shockRings.removeWhere((s) => s.isDead);
  }

  void render(Canvas canvas) {
    for (final s in shockRings) {
      s.render(canvas);
    }
    for (final p in particles) {
      p.render(canvas);
    }
    for (final s in sparkles) {
      s.render(canvas);
    }
  }
}

/// Floating score popup ("+160 F₅!") that rises and fades.
class ScorePopup {
  Offset position;
  final String text;
  double life;
  final double initialLife;
  final bool isLarge;

  ScorePopup({
    required this.position,
    required this.text,
    this.life = 1.3,
    this.isLarge = false,
  }) : initialLife = 1.3;

  bool get isDead => life <= 0;

  void update(double dt) {
    position += const Offset(0, -70) * dt;
    life -= dt;
  }

  void render(Canvas canvas) {
    final t = (life / initialLife).clamp(0.0, 1.0);
    final alpha = (t * 255).toInt();
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: isLarge ? 28 : 22,
          fontWeight: FontWeight.bold,
          color: Color.fromARGB(alpha, 0xFF, 0xE6, 0x78),
          shadows: [
            Shadow(
              color: Color.fromARGB((alpha * 0.8).toInt(), 0, 0, 0),
              blurRadius: 6,
              offset: Offset(1, 1),
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    painter.layout();
    painter.paint(
      canvas,
      position - Offset(painter.width / 2, painter.height / 2),
    );
  }
}
