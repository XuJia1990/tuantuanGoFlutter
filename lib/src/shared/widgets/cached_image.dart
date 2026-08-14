import 'package:flutter/material.dart';

class AppCachedNetworkImage extends StatelessWidget {
  const AppCachedNetworkImage({
    required this.imageUrl,
    super.key,
    this.width,
    this.height,
    this.fit,
    this.alignment = Alignment.center,
    this.placeholder,
    this.errorWidget,
  });

  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit? fit;
  final Alignment alignment;
  final Widget? placeholder;
  final Widget? errorWidget;

  @override
  Widget build(BuildContext context) {
    final fallback =
        errorWidget ??
        ColoredBox(
          color: const Color(0xFFF5F5F5),
          child: SizedBox(width: width, height: height),
        );
    if (imageUrl.isEmpty) return fallback;
    return Image.network(
      imageUrl,
      width: width,
      height: height,
      fit: fit,
      alignment: alignment,
      gaplessPlayback: true,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded || frame != null) return child;
        return placeholder ??
            ColoredBox(
              color: const Color(0xFFF5F5F5),
              child: SizedBox(width: width, height: height),
            );
      },
      errorBuilder: (_, _, _) => fallback,
    );
  }
}
