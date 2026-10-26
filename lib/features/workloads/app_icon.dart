import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;
import 'package:vector_graphics_compiler/vector_graphics_compiler.dart' as vgc;

import '../../shared/theme.dart';
import '../../shared/ui.dart';

/// An app's catalog icon, or a generic icon when it has none or it can't
/// be loaded.
class AppIcon extends StatelessWidget {
  const AppIcon({super.key, required this.url, this.size = 40});

  final String? url;
  final double size;

  @override
  Widget build(BuildContext context) {
    final url = this.url;
    final fallback = IconTile(
      Icons.widgets_rounded,
      AppPalette.tileBlue,
      size: size,
    );
    if (url == null || url.isEmpty) return fallback;
    final image = Uri.tryParse(url)?.path.toLowerCase().endsWith('.svg') == true
        ? FutureBuilder<BytesLoader?>(
            future: _svgIcon(url),
            builder: (context, snapshot) {
              final loader = snapshot.data;
              if (loader == null) return fallback;
              return SvgPicture(loader, width: size, height: size);
            },
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

/// SVG icons already turned into vector graphics, by URL; null for one that
/// could not be loaded. Kept for the life of the app, like images.
final _svgIcons = <String, Future<BytesLoader?>>{};

/// Fetches and compiles an SVG icon here rather than through
/// `SvgPicture.network`: flutter_svg reports an SVG it cannot read as an
/// uncaught error (its cache listens to the load without handling a failure)
/// even when an error builder shows something else, which filled the app log.
Future<BytesLoader?> _svgIcon(String url) =>
    _svgIcons.putIfAbsent(url, () => _loadSvgIcon(url));

Future<BytesLoader?> _loadSvgIcon(String url) async {
  final String xml;
  try {
    final response = await http
        .get(Uri.parse(url))
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) throw http.ClientException('no icon');
    xml = cleanSvg(utf8.decode(response.bodyBytes, allowMalformed: true));
  } catch (_) {
    // Offline or a server hiccup: try again the next time it is shown.
    _svgIcons.remove(url);
    return null;
  }
  try {
    return _EncodedSvg(await compute(_encodeSvg, xml));
  } catch (_) {
    // An SVG the parser cannot read stays the generic icon.
    return null;
  }
}

/// Removes what catalog icons use and the SVG parser refuses, such as
/// `transform="none"` (valid CSS, rejected as "unsupported transform").
@visibleForTesting
String cleanSvg(String xml) => xml
    .replaceAll(RegExp(r'''\stransform\s*=\s*(["'])\s*none\s*\1'''), '')
    .replaceAll(RegExp(r'transform\s*:\s*none\s*;?\s*'), '');

ByteData _encodeSvg(String xml) => vgc
    .encodeSvg(
      xml: xml,
      debugName: 'App icon',
      enableClippingOptimizer: false,
      enableMaskingOptimizer: false,
      enableOverdrawOptimizer: false,
    )
    .buffer
    .asByteData();

class _EncodedSvg extends BytesLoader {
  const _EncodedSvg(this.data);

  final ByteData data;

  @override
  Future<ByteData> loadBytes(BuildContext? context) => SynchronousFuture(data);
}
