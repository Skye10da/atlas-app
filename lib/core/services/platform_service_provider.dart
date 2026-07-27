import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'package:atlas_app/core/services/dictionary_service.dart';
import 'package:atlas_app/core/services/platform_service.dart';
import 'package:atlas_app/core/services/platform_service_stub.dart';
import 'package:atlas_app/core/services/screen_brightness_service.dart';

final platformServiceProvider = Provider<PlatformService>((ref) {
  return ScreenBrightnessService();
});

final stubPlatformServiceProvider = Provider<PlatformService>((ref) {
  return StubPlatformService();
});

final batteryLevelProvider = FutureProvider<double>((ref) async {
  final svc = ref.watch(platformServiceProvider);
  return svc.getBatteryLevel();
});

final liveBatteryLevelProvider = StreamProvider<double>((ref) {
  final svc = ref.watch(platformServiceProvider);
  final controller = StreamController<double>();
  _emitBatteryLevel(svc, controller);
  final timer = Timer.periodic(const Duration(seconds: 30), (_) {
    _emitBatteryLevel(svc, controller);
  });
  ref.onDispose(() {
    timer.cancel();
    controller.close();
  });
  return controller.stream;
});

void _emitBatteryLevel(PlatformService svc, StreamController<double> controller) {
  svc.getBatteryLevel().then(controller.add).catchError((_) {});
}

final httpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

final dictionaryServiceProvider = Provider<DictionaryService>((ref) {
  final client = ref.watch(httpClientProvider);
  return WiktionaryService(client: client);
});
