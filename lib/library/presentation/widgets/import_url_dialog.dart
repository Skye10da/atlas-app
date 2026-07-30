import 'package:flutter/material.dart';

class ImportUrlDialog extends StatefulWidget {
  const ImportUrlDialog({super.key});

  @override
  State<ImportUrlDialog> createState() => _ImportUrlDialogState();
}

class _ImportUrlDialogState extends State<ImportUrlDialog> {
  final _controller = TextEditingController();
  bool _valid = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _validate(String value) {
    final uri = Uri.tryParse(value);
    setState(() => _valid = uri != null && uri.hasScheme && uri.hasAuthority);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Import from URL'),
      content: TextField(
        controller: _controller,
        decoration: const InputDecoration(
          hintText: 'https://example.com/book.txt',
          labelText: 'Book URL',
          border: OutlineInputBorder(),
        ),
        autofocus: true,
        keyboardType: TextInputType.url,
        textInputAction: TextInputAction.go,
        onChanged: _validate,
        onSubmitted: _valid ? (_) => _submit() : null,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _valid ? _submit : null,
          child: const Text('Import'),
        ),
      ],
    );
  }

  void _submit() {
    Navigator.of(context).pop(_controller.text.trim());
  }
}
