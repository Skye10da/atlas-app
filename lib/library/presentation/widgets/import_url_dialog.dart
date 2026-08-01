import 'package:flutter/material.dart';

class ImportUrlDialog extends StatefulWidget {
  const ImportUrlDialog({
    super.key,
    this.title = 'Import from URL',
    this.labelText = 'Book URL',
    this.hintText = 'https://example.com/book.epub',
    this.buttonLabel = 'Import',
  });

  final String title;
  final String labelText;
  final String hintText;
  final String buttonLabel;

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
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        decoration: InputDecoration(
          hintText: widget.hintText,
          labelText: widget.labelText,
          border: const OutlineInputBorder(),
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
          child: Text(widget.buttonLabel),
        ),
      ],
    );
  }

  void _submit() {
    Navigator.of(context).pop(_controller.text.trim());
  }
}
