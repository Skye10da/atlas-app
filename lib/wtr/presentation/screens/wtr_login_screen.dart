import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:atlas_app/browser/domain/engines/browser_web_engine.dart';
import 'package:atlas_app/wtr/domain/services/wtr_authentication_manager.dart';
import 'package:atlas_app/wtr/presentation/providers/wtr_providers.dart';

/// Full-screen WTR-Lab sign-in. Renders WTR-Lab's own login page (GitHub /
/// Discord OAuth) in a WebView so credentials are entered and handled entirely
/// on wtr-lab.com; Atlas never collects or displays the form.
///
/// The bottom action is the only handshake with the app: tapping it captures
/// the session cookies created during sign-in and flips the auth state. Closing
/// the screen first (AppBar close / system back) abandons the attempt and
/// reports `authenticationFailed` so the translation selector can recover.
class WtrLoginScreen extends ConsumerStatefulWidget {
  const WtrLoginScreen({super.key});

  @override
  ConsumerState<WtrLoginScreen> createState() => _WtrLoginScreenState();
}

class _WtrLoginScreenState extends ConsumerState<WtrLoginScreen> {
  late final BrowserWebEngine _engine;
  late final WtrAuthenticationManager _auth;
  bool _completing = false;
  bool _completed = false;

  @override
  void initState() {
    super.initState();
    final factory = ref.read(wtrLoginEngineFactoryProvider);
    _engine = factory(initialUrl: WtrAuthenticationManager.loginUrl);
    _auth = ref.read(wtrAuthManagerProvider);
    _auth.beginLogin();
  }

  Future<void> _completeLogin() async {
    if (_completing) return;
    setState(() => _completing = true);
    final ok = await _auth.completeLogin();
    if (!mounted) return;
    _completed = true;
    if (ok) {
      Navigator.of(context).pop(true);
    } else {
      setState(() => _completing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'WTR-Lab sign-in did not complete. Check that you reached the '
            'wtr-lab.com site, then try again.',
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    if (!_completed) {
      // User closed the browser before finishing login — reflect that in the
      // auth state so the selector offers a retry instead of staying stuck on
      // "signing in".
      _auth.markAuthenticationFailed();
    }
    _engine.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sign in to WTR-Lab'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Close sign-in',
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: theme.colorScheme.surfaceContainerHighest,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Text(
              'Sign in on wtr-lab.com to unlock the AI translation service. '
              'Your login stays on WTR-Lab; Atlas only saves that you signed in.',
              style: theme.textTheme.bodySmall,
            ),
          ),
          Expanded(child: _engine.buildView()),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: FilledButton.icon(
            onPressed: _completing ? null : _completeLogin,
            icon: _completing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check),
            label: const Text('Done — Return to Atlas'),
          ),
        ),
      ),
    );
  }
}
