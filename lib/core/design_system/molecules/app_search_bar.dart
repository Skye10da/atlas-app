import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import 'package:atlas_app/core/design_system/tokens/spacing.dart';

class AppSearchBar extends HookWidget {
  const AppSearchBar({
    super.key,
    this.onChanged,
    this.onSubmitted,
    this.hint = 'Search',
    this.controller,
    this.autofocus = false,
  });

  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final String hint;
  final TextEditingController? controller;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final fallbackController = useTextEditingController();
    final effectiveController = controller ?? fallbackController;
    final debounce = useRef<Timer?>(null);
    final hasText = useState(effectiveController.text.isNotEmpty);

    useEffect(() {
      void onTextChanged() {
        final notEmpty = effectiveController.text.isNotEmpty;
        if (notEmpty != hasText.value) {
          hasText.value = notEmpty;
        }
      }

      effectiveController.addListener(onTextChanged);
      return () {
        debounce.value?.cancel();
        effectiveController.removeListener(onTextChanged);
      };
    }, [effectiveController]);

    void onSearchChanged(String value) {
      debounce.value?.cancel();
      debounce.value = Timer(const Duration(milliseconds: 300), () {
        onChanged?.call(value);
      });
    }

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Semantics(
        label: 'Search',
        child: TextField(
          controller: effectiveController,
          autofocus: autofocus,
          onChanged: onSearchChanged,
          onSubmitted: onSubmitted,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: const Icon(Icons.search, size: 20),
            suffixIcon: hasText.value
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 20),
                    onPressed: () {
                      effectiveController.clear();
                      onChanged?.call('');
                    },
                  )
                : null,
            filled: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSpacing.borderRadiusFull),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ),
    );
  }
}
