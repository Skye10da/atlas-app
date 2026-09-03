import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:path/path.dart' as p;

/// Renders an inline chapter image with rounded corners, subtle border,
/// optional caption, and tap-to-zoom full screen modal.
class ReaderImageWidget extends StatelessWidget {
  const ReaderImageWidget({
    super.key,
    required this.src,
    this.alt,
    this.bookDir,
  });

  final String src;
  final String? alt;
  final String? bookDir;

  File? get _resolvedFile {
    if (src.startsWith('http://') || src.startsWith('https://')) return null;
    if (p.isAbsolute(src)) return File(src);
    if (bookDir != null) {
      return File(p.join(bookDir!, src));
    }
    return File(src);
  }

  void _openImageViewer(BuildContext context, ImageProvider imageProvider) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.85),
      builder: (ctx) => _ImageViewerDialog(
        imageProvider: imageProvider,
        caption: alt,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final file = _resolvedFile;
    final isNetwork = src.startsWith('http://') || src.startsWith('https://');

    ImageProvider? provider;
    if (isNetwork) {
      provider = NetworkImage(src);
    } else if (file != null && file.existsSync()) {
      provider = FileImage(file);
    }

    if (provider == null) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: () => _openImageViewer(context, provider!),
              child: Hero(
                tag: 'reader_img_${src.hashCode}',
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8.0),
                  child: Container(
                    constraints: const BoxConstraints(
                      maxHeight: 450,
                      maxWidth: 600,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8.0),
                      border: Border.all(
                        color: Theme.of(context).dividerColor.withValues(alpha: 0.15),
                        width: 1.0,
                      ),
                    ),
                    child: Image(
                      image: provider,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                    ),
                  ),
                ),
              ),
            ),
            if (alt != null && alt!.trim().isNotEmpty) ...[
              const SizedBox(height: 6.0),
              Text(
                alt!.trim(),
                style: TextStyle(
                  fontSize: 12.0,
                  fontStyle: FontStyle.italic,
                  color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.7),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ImageViewerDialog extends HookWidget {
  const _ImageViewerDialog({
    required this.imageProvider,
    this.caption,
  });

  final ImageProvider imageProvider;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final controller = useTransformationController();

    void resetZoom() {
      controller.value = Matrix4.identity();
    }

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.zero,
      child: Stack(
        alignment: Alignment.center,
        children: [
          GestureDetector(
            onDoubleTap: resetZoom,
            child: InteractiveViewer(
              transformationController: controller,
              minScale: 0.8,
              maxScale: 5.0,
              child: Image(
                image: imageProvider,
                fit: BoxFit.contain,
              ),
            ),
          ),
          // Top close button
          Positioned(
            top: 40,
            right: 20,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 28),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          // Caption at bottom
          if (caption != null && caption!.trim().isNotEmpty)
            Positioned(
              bottom: 40,
              left: 24,
              right: 24,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  caption!.trim(),
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
