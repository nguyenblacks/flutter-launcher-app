import 'package:flutter/material.dart';

/// Wraps any widget (typically an app icon) with the user-selected icon shape clip.
class IconShapeClipper extends StatelessWidget {
  final Widget child;
  final String shape;
  final double size;

  const IconShapeClipper({
    super.key,
    required this.child,
    required this.shape,
    this.size = 48,
  });

  @override
  Widget build(BuildContext context) {
    if (shape == 'Circle') {
      return ClipOval(
        child: SizedBox(width: size, height: size, child: child),
      );
    }
    if (shape == 'Squircle') {
      return ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.28),
        child: SizedBox(width: size, height: size, child: child),
      );
    }
    if (shape == 'Rounded Rectangle') {
      return ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.2),
        child: SizedBox(width: size, height: size, child: child),
      );
    }
    if (shape == 'Teardrop') {
      return ClipPath(
        clipper: _TeardropClipper(),
        child: SizedBox(width: size, height: size, child: child),
      );
    }
    // Default — no clip
    return SizedBox(width: size, height: size, child: child);
  }
}

class _TeardropClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final r = size.width * 0.45;
    final path = Path();
    path.moveTo(size.width * 0.5, 0);
    path.cubicTo(
      size.width * 0.95,
      0,
      size.width,
      size.height * 0.05,
      size.width,
      r,
    );
    path.arcToPoint(Offset(0, r), radius: Radius.circular(r), clockwise: false);
    path.cubicTo(
      0,
      size.height * 0.05,
      size.width * 0.05,
      0,
      size.width * 0.5,
      0,
    );
    path.close();
    return path;
  }

  @override
  bool shouldReclip(_TeardropClipper old) => false;
}
