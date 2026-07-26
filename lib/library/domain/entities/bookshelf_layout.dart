import 'package:flutter/material.dart';

enum BookshelfLayout { grid, list, scattered }

extension BookshelfLayoutX on BookshelfLayout {
  String get label => switch (this) {
    BookshelfLayout.grid => 'Grid',
    BookshelfLayout.list => 'List',
    BookshelfLayout.scattered => 'Scattered',
  };

  IconData get icon => switch (this) {
    BookshelfLayout.grid => Icons.grid_view,
    BookshelfLayout.list => Icons.view_list,
    BookshelfLayout.scattered => Icons.auto_awesome_mosaic,
  };
}
