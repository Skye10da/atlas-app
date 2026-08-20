import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

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

final chargingProvider = FutureProvider<bool>((ref) async {
  final svc = ref.watch(platformServiceProvider);
  return svc.isCharging();
});

final liveChargingProvider = StreamProvider<bool>((ref) async* {
  final svc = ref.watch(platformServiceProvider);
  yield await svc.isCharging();
  yield* svc.onChargingChanged;
});

void _emitBatteryLevel(
  PlatformService svc,
  StreamController<double> controller,
) {
  svc.getBatteryLevel().then(controller.add).catchError((_) {});
}

final httpClientProvider = Provider<http.Client>((ref) {
  final httpClient = HttpClient();
  httpClient.badCertificateCallback = (_, _, _) => true;
  final client = IOClient(httpClient);
  ref.onDispose(client.close);
  return client;
});

final dictionaryServiceProvider =
    Provider.family<DictionaryService, DictionarySource>((ref, source) {
      final client = ref.watch(httpClientProvider);
      return switch (source) {
        DictionarySource.wiktionary => WiktionaryService(client: client),
        DictionarySource.urbanDictionary => UrbanDictionaryService(
          client: client,
        ),
      };
    });
