import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:atlas_app/browser/domain/engines/browser_web_engine.dart';
import 'package:atlas_app/browser/domain/entities/web_selection.dart';
import 'package:atlas_app/browser/domain/entities/web_tab_state.dart';
import 'package:atlas_app/browser/domain/repository_interfaces/browser_repository_interface.dart';
import 'package:atlas_app/core/error_handling/result.dart';

/// Sentinel URL meaning "no page loaded yet" — the browser shows its native
/// start page for these tabs.
const String kBrowserStartPageUrl = 'about:blank';

/// A single open browser tab. The engine owns the native web view; the tab
/// only remembers identity + order and mirrors engine state for the strip.
class BrowserTab {
  BrowserTab({required this.id, required this.engine});

  final String id;
  final BrowserWebEngine engine;

  String get title => engine.currentTitle.value?.isNotEmpty == true
      ? engine.currentTitle.value!
      : 'New tab';

  String? get url => engine.currentUrl.value;

  /// True while the tab shows the native start page instead of a loaded URL.
  bool get isOnStartPage => url == null || url == kBrowserStartPageUrl;
}

/// Holds up to [maxTabs] live [BrowserTab]s and persists them through
/// [BrowserRepositoryInterface] so the strip survives app restarts.
///
/// The controller only speaks the abstract [BrowserWebEngine] contract, so it
/// is fully testable with a fake engine.
class BrowserTabsController extends ChangeNotifier {
  BrowserTabsController({
    required BrowserRepositoryInterface repository,
    required BrowserEngineFactory engineFactory,
    this.maxTabs = 5,
    this.persist = true,
  })  : _repository = repository,
        _engineFactory = engineFactory;

  final BrowserRepositoryInterface _repository;
  final BrowserEngineFactory _engineFactory;
  final int maxTabs;
  final bool persist;

  static const Duration _saveDebounce = Duration(milliseconds: 500);

  final List<BrowserTab> _tabs = [];
  final Map<String, Timer> _saveTimers = {};
  int _activeIndex = -1;
  int _sequence = 0;

  List<BrowserTab> get tabs => List.unmodifiable(_tabs);
  int get activeIndex => _activeIndex;
  BrowserTab? get activeTab => _activeIndex >= 0 && _activeIndex < _tabs.length
      ? _tabs[_activeIndex]
      : null;
  bool get hasTabs => _tabs.isNotEmpty;
  bool get canAddTab => _tabs.length < maxTabs;

  bool _darkModeEnabled = false;
  bool get darkModeEnabled => _darkModeEnabled;

  /// Applies (or clears) forced dark mode across every open tab and makes new
  /// tabs inherit the setting.
  Future<void> setDarkMode(bool enabled) async {
    if (_darkModeEnabled == enabled) return;
    _darkModeEnabled = enabled;
    for (final tab in _tabs) {
      await tab.engine.setDarkMode(enabled);
    }
  }

  /// Routes page-selection events from the active engine to [onSelection].
  /// Called by the browser screen when the active tab changes.
  Future<void> bindSelectionListener(
      void Function(WebSelection selection)? onSelection) async {
    await activeTab?.engine.setSelectionListener(onSelection);
  }

  /// Routes intercepted download requests (epub taps) from the active engine
  /// to [onDownload]. Called by the browser screen alongside the selection
  /// binding.
  Future<void> bindDownloadListener(
      void Function(String url, String? mimeType)? onDownload) async {
    await activeTab?.engine.setDownloadListener(onDownload);
  }

  /// Rebuilds tabs from persisted state (in order), capping at [maxTabs].
  Future<void> restore() async {
    final result = await _repository.getTabs();
    final states = switch (result) {
      Success(value: final tabs) => tabs..sort((a, b) => a.order.compareTo(b.order)),
      Failure() => <WebTabState>[],
    };
    for (final state in states.take(maxTabs)) {
      final engine = _createEngine(initialUrl: state.url);
      _tabs.add(BrowserTab(id: state.id, engine: engine));
      _attachSaveWiring(_tabs.last);
    }
    if (_tabs.isEmpty) {
      await addTab();
    } else {
      _activeIndex = _tabs.length - 1;
    }
    notifyListeners();
  }

  /// Opens a fresh tab; a null/empty [url] lands on the start page.
  Future<void> addTab({String? url}) async {
    if (_tabs.length >= maxTabs) return;
    final engine = _createEngine(initialUrl: url);
    final id = 'tab-${DateTime.now().microsecondsSinceEpoch}-${_sequence++}';
    final tab = BrowserTab(id: id, engine: engine);
    if (_darkModeEnabled) {
      unawaited(engine.setDarkMode(true));
    }
    _tabs.add(tab);
    _attachSaveWiring(tab);
    _activeIndex = _tabs.length - 1;
    if (persist) {
      await _saveTab(tab, lastActiveAt: DateTime.now());
    }
    notifyListeners();
  }

  /// Brings the tab at [index] forward (making it active).
  Future<void> activate(int index) async {
    if (index < 0 || index >= _tabs.length || index == _activeIndex) return;
    _activeIndex = index;
    if (persist) {
      await _saveTab(_tabs[index], lastActiveAt: DateTime.now());
    }
    notifyListeners();
  }

  Future<void> close(int index) async {
    if (index < 0 || index >= _tabs.length) return;
    final tab = _tabs.removeAt(index);
    _detachSaveWiring(tab);
    _saveTimers.remove(tab.id)?.cancel();
    tab.engine.dispose();
    if (persist) {
      await _repository.removeTab(tab.id);
    }
    if (_tabs.isEmpty) {
      _activeIndex = -1;
      notifyListeners();
      return;
    }
    if (_activeIndex > index) _activeIndex--;
    if (_activeIndex >= _tabs.length) _activeIndex = _tabs.length - 1;
    await _renumber();
    notifyListeners();
  }

  @override
  void dispose() {
    for (final tab in _tabs) {
      _detachSaveWiring(tab);
      tab.engine.dispose();
    }
    for (final timer in _saveTimers.values) {
      timer.cancel();
    }
    super.dispose();
  }

  BrowserWebEngine _createEngine({String? initialUrl}) {
    final url = initialUrl;
    if (url == null || url.isEmpty || url == kBrowserStartPageUrl) {
      return _engineFactory(initialUrl: null);
    }
    return _engineFactory(initialUrl: url);
  }

  void _attachSaveWiring(BrowserTab tab) {
    tab.engine.currentUrl.addListener(() => _scheduleSave(tab));
    tab.engine.currentTitle.addListener(() => _scheduleSave(tab));
  }

  void _detachSaveWiring(BrowserTab tab) {
    tab.engine.currentUrl.removeListener(() => _scheduleSave(tab));
    tab.engine.currentTitle.removeListener(() => _scheduleSave(tab));
  }

  void _scheduleSave(BrowserTab tab) {
    if (!persist || !_tabs.any((t) => t.id == tab.id)) return;
    _saveTimers.remove(tab.id)?.cancel();
    _saveTimers[tab.id] = Timer(_saveDebounce, () {
      _saveTimers.remove(tab.id);
      _saveTab(tab);
    });
  }

  Future<void> _saveTab(BrowserTab tab, {DateTime? lastActiveAt}) async {
    if (!persist) return;
    final order = _tabs.indexWhere((t) => t.id == tab.id);
    await _repository.upsertTab(WebTabState(
      id: tab.id,
      url: tab.isOnStartPage ? null : tab.url,
      title: tab.title,
      order: order,
      lastActiveAt: lastActiveAt ?? DateTime.now(),
    ));
  }

  Future<void> _renumber() async {
    for (var i = 0; i < _tabs.length; i++) {
      await _repository.upsertTab(WebTabState(
        id: _tabs[i].id,
        url: _tabs[i].isOnStartPage ? null : _tabs[i].url,
        title: _tabs[i].title,
        order: i,
        lastActiveAt: DateTime.now(),
      ));
    }
  }
}