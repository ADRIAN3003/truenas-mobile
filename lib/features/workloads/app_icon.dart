import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// An app's catalog icon, or a generic icon when it has none or it can't
/// be loaded.
class AppIcon extends StatelessWidget {
  const AppIcon({super.key, required this.url, this.size = 40});

  final String? url;
  final double size;

  @override
  Widget build(BuildContext context) {
    final url = this.url;
    final fallback = SizedBox.square(
      dimension: size,
      child: Icon(Icons.apps, size: size * 0.6),
    );
    if (url == null || url.isEmpty) return fallback;
    final image = Uri.tryParse(url)?.path.toLowerCase().endsWith('.svg') == true
        ? SvgPicture.network(
            url,
            width: size,
            height: size,
            placeholderBuilder: (_) => fallback,
            errorBuilder: (_, _, _) => fallback,
          )
        : Image.network(
            url,
            width: size,
            height: size,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => fallback,
          );
    // Decorative: the app's name is always next to it.
    return ExcludeSemantics(
      child: ClipRRect(borderRadius: BorderRadius.circular(8), child: image),
    );
  }
}
