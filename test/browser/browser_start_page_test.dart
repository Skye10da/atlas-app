import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;

import 'package:atlas_app/browser/presentation/widgets/browser_start_page.dart';
import 'package:atlas_app/core/content_acquisition/adapters/source_registry.dart';
import 'package:atlas_app/core/content_acquisition/providers.dart';
import 'package:atlas_app/core/content_acquisition/sources/gutenberg_source.dart';
import 'package:atlas_app/core/content_engine/registry/plugin_source.dart';
import 'package:atlas_app/core/content_engine/templates/html_template.dart';

import '../content_engine/test_fixtures.dart';

void main() {
  testWidgets('lists every registered source including plugin tiles',
      (tester) async {
    final registry = SourceRegistry()
      ..register(GutenbergSource(client: http.Client()))
      ..register(PluginSource(
        manifest: buildManifest(
          baseUrl: 'https://novel.example',
          sourceName: 'Novel Hub',
        ),
        template: const HtmlTemplate(),
        transport: FakeTransport(),
      ));

    final opened = <String>[];
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => BrowserStartPage(onOpenSite: opened.add),
        ),
        GoRoute(
          path: '/sources/:name',
          builder: (context, state) => const Scaffold(),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sourceRegistryProvider.overrideWithValue(registry),
          pluginSourcesProvider.overrideWith((ref) async => <PluginSource>[]),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Project Gutenberg'), findsOneWidget);
    expect(find.text('Novel Hub'), findsOneWidget);

    await tester.tap(find.text('Novel Hub'));
    await tester.pumpAndSettle();
    expect(opened, ['https://novel.example']);

    await tester.tap(find.text('Project Gutenberg'));
    await tester.pumpAndSettle();
    expect(opened, ['https://novel.example', 'https://www.gutenberg.org']);
  });
}
