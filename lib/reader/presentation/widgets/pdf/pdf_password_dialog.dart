import 'package:flutter/material.dart';

/// Shows a dialog asking for a PDF password. Returns the entered password,
/// or `null` if the user cancels.
Future<String?> promptPdfPassword(BuildContext context) async {
  final controller = TextEditingController();
  final password = await showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      title: const Text('Password required'),
      content: TextField(
        controller: controller,
        autofocus: true,
        obscureText: true,
        decoration: const InputDecoration(
          hintText: 'Enter password',
          border: OutlineInputBorder(),
        ),
        onSubmitted: (value) => Navigator.of(context).pop(value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(controller.text),
          child: const Text('Open'),
        ),
      ],
    ),
  );
  controller.dispose();
  return password?.isEmpty == true ? null : password;
}
