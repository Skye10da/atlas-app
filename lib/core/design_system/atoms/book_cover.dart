import 'dart:io';

import 'package:flutter/material.dart';

import 'package:atlas_app/core/design_system/tokens/colors.dart';
import 'package:atlas_app/core/design_system/tokens/spacing.dart';

class BookCover extends StatelessWidget {
  const BookCover({
    super.key,
    this.coverPath,
    this.width = 56,
    this.height = 80,
    this.format = '',
  });

  final String? coverPath;
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
      child: coverPath != null ? _imageOrPlaceholder() : _placeholder(),
    );
  }

  Widget _imageOrPlaceholder() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSpacing.borderRadiusSm),
      child: Image.file(
        File(coverPath!),
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _placeholder(),
      ),
    );
  }

  Widget _placeholder() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          format == 'epub' ? Icons.description : Icons.book,
          size: width * 0.4,
          color: AppColors.onSurfaceVariant,
        ),
      ],
    );
  }
}
