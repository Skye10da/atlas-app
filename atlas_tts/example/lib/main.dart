// atlas_tts device probe (M3 Android).
//
// Drives the real atlas_tts core on the device to validate the AAudio
// playback consumer chain that cannot be exercised from Windows:
//   init -> enablePlayback -> dev-sine pack -> speak -> word boundaries -->
//   AUDIO_QUEUED -> CHUNK_DRAINED paced by actual play-out, plus mid-speech
//   pause/resume.
//
// The scenario runs automatically on launch; the buttons re-run the speak
// steps manually. The dev-sine pack is an empty pack directory (no neural
// markers): the core falls back to its M1 sine renderer, so no 64 MB pack
// download is needed on device.
//
// ASCII-only source (repo rule for this plugin's Dart files).
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import 'package:atlas_tts/atlas_tts.dart' as atlas;

void main() => runApp(const AtlasTtsProbeApp());

class AtlasTtsProbeApp extends StatelessWidget {
  const AtlasTtsProbeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'atlas_tts probe',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.indigo),
      home: const ProbePage(),
    );
  }
}

class ProbePage extends StatefulWidget {
  const ProbePage({super.key});

  @override
  State<ProbePage> createState() => _ProbePageState();
}

class _ProbePageState extends State<ProbePage> {
  atlas.AtlasTts? _tts;
  String? _docsRoot;
  final List<String> _log = [];
  final Stopwatch _speakWall = Stopwatch();

  // In-flight request bookkeeping for the last speak() issued.
  int _lastAudioFrames = 0;
  int _lastSampleRate = 0;
  Completer<void>? _drained;

  void log(String line) {
    setState(() {
      _log.add('${DateTime.now().toString().substring(11, 23)}  $line');
      if (_log.length > 500) _log.removeRange(0, _log.length - 500);
    });
    // debugPrint is the only channel that reaches logcat for a detached
    // Android app (dart:io stdout is /dev/null there). The AUDIO_QUEUED
    // burst only delays delivery; timestamps are stamped at log() time.
    debugPrint('atlas-probe: $line');
  }

  @override
  void initState() {
    super.initState();
    log('Device probe ready. Package: ${_packageFromCmdline() ?? 'unknown'}');
    WidgetsBinding.instance.addPostFrameCallback((_) => _runScenario());
  }

  // Same derivation the app-side NeuralTtsDriver gate uses (documents the
  // path_provider getApplicationDocuments convention on Android).
  String? _packageFromCmdline() {
    try {
      final line = File('/proc/self/cmdline').readAsStringSync();
      final pkg = line.split(String.fromCharCode(0)).first.trim();
      return pkg.contains('.') ? pkg : null;
    } catch (_) {
      return null;
    }
  }

  Directory? _devPackDir() {
    final pkg = _packageFromCmdline();
    if (pkg == null) return null;
    _docsRoot = '/data/user/0/$pkg/app_flutter';
    return Directory('$_docsRoot/atlas_tts/voices/dev-sine');
  }

  Future<void> _runScenario() async {
    try {
      await _stepInitAndPlayback();
      if (_tts == null) return;
      await _stepCreatePackAndLoad();
      await _stepSpeakShort();
      await Future<void>.delayed(const Duration(seconds: 2));
      await _stepSpeakLongQuiet();
      await Future<void>.delayed(const Duration(seconds: 2));
      await _stepSpeakShort(); // post-drain re-arm sanity check
      await _stepVitsProbe(); // real engine when a .onnx pack is side-loaded
      log('SCENARIO COMPLETE');
    } catch (e) {
      log('SCENARIO THREW: $e');
    }
  }

  // M3/M5 gate data: run the REAL VITS pack when one has been side-loaded
  // into <docs>/atlas_tts/voices (tool/install_pack_device.ps1). Reports an
  // on-device RTF estimate: render wall clock over the utterance's audio
  // length (render finishes at the last AUDIO_QUEUED; play-out continues in
  // real time afterwards).
  Future<void> _stepVitsProbe() async {
    if (_docsRoot == null) return;
    final voicesRoot = Directory('$_docsRoot/atlas_tts/voices');
    if (!voicesRoot.existsSync()) return;
    final packs = voicesRoot
        .listSync()
        .whereType<Directory>()
        .where(
          (d) =>
              d.listSync().any((f) => f.path.toLowerCase().endsWith('.onnx')),
        )
        .toList();
    if (packs.isEmpty) {
      log('VITS probe: no .onnx pack side-loaded; skipping.');
      return;
    }
    final pack = packs.first;
    final err = _tts!.loadVoice(pack.path);
    log('VITS loadVoice ${pack.path.split('/').last} -> $err (awaiting VOICE_READY...)');
    final ready = Completer<void>();
    late final StreamSubscription<atlas.TtsEvent> sub;
    sub = _tts!.events.listen((e) {
      if (e is atlas.TtsVoiceReady && !ready.isCompleted) {
        ready.complete();
        sub.cancel();
      }
    });
    try {
      await ready.future.timeout(const Duration(seconds: 30));
    } on TimeoutException {
      log('VITS VOICE_READY TIMEOUT');
      await sub.cancel();
      return;
    }
    log('VITS voice ready; speaking...');
    await _speak(
      'Atlas neural probe. The engine should read this sentence '
      'with the real VITS model and report the on-device render time.',
      requestId: 9,
    );
  }
  // requestId 9 is fine: any id >= 1 is drained; it only keeps the VITS
  // request distinguishable in the log stream.

  Future<void> _stepInitAndPlayback() async {
    try {
      final err = atlas.AtlasTts.initialize(sampleRateHint: 22050);
      if (err != null) {
        log('INIT FAILED: err=$err');
        return;
      }
      _tts = atlas.AtlasTts.instance;
      log('Init OK (session @22050)');

      _tts!.events.listen(
        _onEvent,
        onError: (Object e) => log('evt error: $e'),
        onDone: () => log('event stream closed'),
      );

      final playback = _tts!.enablePlayback(true);
      log('enablePlayback -> $playback (ok=0)');
    } catch (e, st) {
      log('Init threw: $e\n$st');
    }
  }

  Future<void> _stepCreatePackAndLoad() async {
    final pack = _devPackDir();
    if (pack == null) {
      log('No package name -> no docs path (cmdline probe failed).');
      return;
    }
    try {
      pack.createSync(recursive: true);
      log('Dev sine pack at ${pack.path}');
      final err = _tts!.loadVoice(pack.path);
      log('loadVoice -> $err');
      // TtsVoiceReady follows as an event.
    } catch (e) {
      log('Pack load threw: $e');
    }
  }

  // Request ids MUST start at 1: the core treats 0 in its render_done_id
  // marker as "no pending drain", so a request id 0 never receives its
  // CHUNK_DRAINED in playback mode (recorded in atlas_tts.h).
  int _requestId = 1;

  Future<void> _speak(String text, {int requestId = -1}) async {
    if (_tts == null) return;
    if (requestId < 0) requestId = _requestId++;
    _lastAudioFrames = 0;
    _lastSampleRate = 0;
    _lastQueuedAtMs = -1;
    final drained = Completer<void>();
    _drained = drained;
    final err = _tts!.speak(text, requestId: requestId);
    _speakWall
      ..reset()
      ..start();
    log('speak -> $err (reqId=$requestId)');
    try {
      await drained.future.timeout(const Duration(seconds: 60));
    } on TimeoutException {
      log('DRAINED TIMEOUT (reqId=$requestId) after 60s');
      return;
    }
    final audioSeconds = _lastAudioFrames / _rateFormula(_lastSampleRate);
    final renderSeconds = _lastQueuedAtMs / 1000.0;
    log(
      'PACING audio=${audioSeconds.toStringAsFixed(2)}s '
      'render=${renderSeconds.toStringAsFixed(2)}s '
      'RTF~${audioSeconds > 0 ? (renderSeconds / audioSeconds).toStringAsFixed(3) : '?'}',
    );
  }

  int _lastQueuedAtMs = -1; // wall time of the final AUDIO_QUEUED chunk

  void _onEvent(atlas.TtsEvent e) {
    switch (e) {
      case atlas.TtsVoiceReady():
        log('VOICE_READY');
      case atlas.TtsWordBoundary():
        log('WORD off=${e.offset} len=${e.length} t=${_now()}');
      case atlas.TtsAudioQueued():
        _lastAudioFrames += e.frames;
        _lastSampleRate = e.sampleRate;
        _lastQueuedAtMs = _speakWall.elapsedMilliseconds;
        log(
          'AUDIO_QUEUED +${e.frames}f total=$_lastAudioFrames '
          '(${(_lastAudioFrames / _rateFormula(e.sampleRate)).toStringAsFixed(2)}s) '
          't=${_now()}',
        );
      case atlas.TtsChunkDrained():
        log(
          'CHUNK_DRAINED reqId=${e.requestId} t=${_now()} audio='
          '${(_lastAudioFrames / _rateFormula(_lastSampleRate)).toStringAsFixed(2)}s',
        );
        _drained?.complete();
      case atlas.TtsError():
        log('ERROR code=${e.code} reqId=${e.requestId} t=${_now()}');
    }
  }

  double _rateFormula(int rate) => (rate == 0 ? 22050 : rate).toDouble();

  String _now() => _speakWall.isRunning
      ? '${(_speakWall.elapsedMilliseconds / 1000).toStringAsFixed(2)}s'
      : '-';

  Future<void> _stepSpeakShort() async {
    await _speak('The quick brown fox jumps over the lazy dog.');
  }

  // Long utterance with a scripted mid-flight pause + resume.
  Future<void> _stepSpeakLongQuiet() async {
    final allDone = _speak(
      'Atlas probe long phrase test. The playback '
      'consumer must hold audio while paused and resume without dropping '
      'the tail.',
    );
    final pauseTimer = Timer(const Duration(milliseconds: 600), () async {
      log('-- pausing device --');
      log('pause(true) -> ${_tts!.pause(true)}');
      await Future<void>.delayed(const Duration(seconds: 2));
      log('-- resuming device --');
      log('pause(false) -> ${_tts!.pause(false)}');
    });
    await allDone;
    pauseTimer.cancel();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('atlas_tts M3 device probe')),
      body: Column(
        children: [
          _docsRoot == null
              ? const SizedBox.shrink()
              : Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: Text(
                    'docs=$_docsRoot',
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              FilledButton(
                onPressed: _tts == null
                    ? () async {
                        await _stepInitAndPlayback();
                        await _stepCreatePackAndLoad();
                      }
                    : null,
                child: const Text('Init'),
              ),
              FilledButton(
                onPressed: _tts == null ? null : _stepSpeakShort,
                child: const Text('Short'),
              ),
              FilledButton(
                onPressed: _tts == null ? null : _stepSpeakLongQuiet,
                child: const Text('Long+pause'),
              ),
            ],
          ),
          const Divider(height: 4),
          Expanded(
            child: ListView.builder(
              reverse: true,
              itemCount: _log.length,
              itemBuilder: (context, i) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
                child: Text(
                  _log[_log.length - 1 - i],
                  style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
