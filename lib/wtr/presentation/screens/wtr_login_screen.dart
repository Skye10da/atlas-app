import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

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
class WtrLoginScreen extends HookConsumerWidget {
  const WtrLoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(wtrAuthManagerProvider);
    final engine = useMemoized<BrowserWebEngine>(() {
      final factory = ref.read(wtrLoginEngineFactoryProvider);
      return factory(initialUrl: WtrAuthenticationManager.loginUrl);
    }, []);

    final completing = useState(false);
    final completed = useRef(false);

    useEffect(() {
      auth.beginLogin();
      return () {
        if (!completed.value) {
          auth.markAuthenticationFailed();
        }
        engine.dispose();
      };
    }, [auth, engine]);

    Future<void> completeLogin() async {
      if (completing.value) return;
      completing.value = true;
      final ok = await auth.completeLogin();
      if (!context.mounted) return;
      completed.value = true;
      if (ok) {
        Navigator.of(context).pop(true);
      } else {
        completing.value = false;
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
          Expanded(child: engine.buildView()),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: FilledButton.icon(
            onPressed: completing.value ? null : completeLogin,
            icon: completing.value
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check_rounded),
            label: Text(completing.value ? 'Finishing sign-in…' : 'I have signed in'),
          ),
        ),
      ),
    );
  }
}
