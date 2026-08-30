import 'dart:io';

import 'package:flutter/material.dart';

import 'package:atlas_app/core/design_system/tokens/colors.dart';
import 'package:atlas_app/core/design_system/tokens/spacing.dart';

class BookCover extends StatelessWidget {
  const BookCover({
    super.key,
    this.coverPath,
    this.coverUrl,
    this.width = 56,
    this.height = 80,
    this.format = '',
  });

  final String? coverPath;
  final String? coverUrl;
  final double width;
  final double height;
  final String format;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppSpacing.borderRadiusSm),
      ),
      child: _hasImage ? _imageOrPlaceholder() : _placeholder(),
    );
  }

  bool get _hasImage =>
      (coverPath != null && coverPath!.isNotEmpty) ||
      (coverUrl != null && coverUrl!.isNotEmpty);

  Widget _imageOrPlaceholder() {
    final pathOrUrl = (coverPath != null && coverPath!.isNotEmpty)
        ? coverPath!
        : (coverUrl ?? '');

    final isNetwork = pathOrUrl.startsWith('http://') || pathOrUrl.startsWith('https://');
    final cacheW = width.isFinite ? (width * 2.5).round().clamp(100, 1200) : 400;
    final cacheH = height.isFinite ? (height * 2.5).round().clamp(100, 1600) : 600;

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSpacing.borderRadiusSm),
      child: isNetwork
          ? Image.network(
              pathOrUrl,
              width: width,
              height: height,
              fit: BoxFit.cover,
              cacheWidth: cacheW,
              cacheHeight: cacheH,
              errorBuilder: (_, _, _) => _placeholder(),
            )
          : Image.file(
              File(pathOrUrl),
              width: width,
              height: height,
              fit: BoxFit.cover,
              cacheWidth: cacheW,
              cacheHeight: cacheH,
              errorBuilder: (_, _, _) => _placeholder(),
            ),
    );
  }

  Widget _placeholder() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          switch (format) {
            'epub' => Icons.description,
            'pdf' => Icons.picture_as_pdf,
            'txt' || 'text' => Icons.article_outlined,
            'md' || 'markdown' => Icons.code,
            _ => Icons.book,
          },
          size: width.isFinite ? width * 0.4 : 32,
          color: AppColors.onSurfaceVariant,
        ),
      ],
    );
  }
}
