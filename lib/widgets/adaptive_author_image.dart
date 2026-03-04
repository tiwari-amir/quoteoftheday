import 'package:flutter/material.dart';

class AdaptiveAuthorImage extends StatefulWidget {
  const AdaptiveAuthorImage({
    super.key,
    required this.imageUrl,
    required this.placeholder,
    this.error,
  });

  final String imageUrl;
  final Widget placeholder;
  final Widget? error;

  @override
  State<AdaptiveAuthorImage> createState() => _AdaptiveAuthorImageState();
}

class _AdaptiveAuthorImageState extends State<AdaptiveAuthorImage> {
  ImageStream? _stream;
  ImageStreamListener? _listener;
  String? _resolvedUrl;
  double? _aspectRatio;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolveImageIfNeeded();
  }

  @override
  void didUpdateWidget(covariant AdaptiveAuthorImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _aspectRatio = null;
      _resolveImageIfNeeded(force: true);
    }
  }

  @override
  void dispose() {
    _unsubscribe();
    super.dispose();
  }

  void _resolveImageIfNeeded({bool force = false}) {
    if (!force && _resolvedUrl == widget.imageUrl) return;
    _resolvedUrl = widget.imageUrl;

    _unsubscribe();
    final provider = NetworkImage(widget.imageUrl);
    final stream = provider.resolve(createLocalImageConfiguration(context));
    final listener = ImageStreamListener(
      (info, _) {
        final image = info.image;
        if (image.height <= 0) return;
        final ratio = image.width / image.height;
        if (!mounted) return;
        if (_aspectRatio == ratio) return;
        setState(() => _aspectRatio = ratio);
      },
      onError: (error, stackTrace) {
        if (!mounted) return;
        setState(() => _aspectRatio = null);
      },
    );
    _stream = stream;
    _listener = listener;
    _stream!.addListener(_listener!);
  }

  void _unsubscribe() {
    if (_stream != null && _listener != null) {
      _stream!.removeListener(_listener!);
    }
    _stream = null;
    _listener = null;
  }

  BoxFit _fitFor(double? ratio) {
    if (ratio == null) return BoxFit.cover;
    if (ratio > 1.45 || ratio < 0.68) return BoxFit.contain;
    return BoxFit.cover;
  }

  Alignment _alignmentFor(double? ratio) {
    if (ratio != null && ratio < 0.9) {
      return const Alignment(0, -0.2);
    }
    return Alignment.center;
  }

  @override
  Widget build(BuildContext context) {
    final fit = _fitFor(_aspectRatio);
    final alignment = _alignmentFor(_aspectRatio);

    return Image.network(
      widget.imageUrl,
      fit: fit,
      alignment: alignment,
      filterQuality: FilterQuality.medium,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded || frame != null) {
          return child;
        }
        return widget.placeholder;
      },
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return widget.placeholder;
      },
      errorBuilder: (context, error, stackTrace) {
        return widget.error ?? widget.placeholder;
      },
    );
  }
}
