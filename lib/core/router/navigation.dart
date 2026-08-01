import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

void popOrGoToLibrary(BuildContext context) {
  try {
    context.pop();
  } on GoError catch (error) {
    if (error.message == 'There is nothing to pop') {
      context.go('/library');
    } else {
      rethrow;
    }
  }
}
