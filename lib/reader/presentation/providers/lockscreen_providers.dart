import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:atlas_app/reader/domain/use_cases/update_lockscreen_media_use_case.dart';
import 'package:atlas_app/reader/infrastructure/repositories/lockscreen_repository.dart';
import 'package:atlas_app/reader/infrastructure/services/media_notification_service.dart';
import 'package:atlas_app/reader/presentation/providers/speech_providers.dart';
import 'package:atlas_app/reader/presentation/view_models/lockscreen_view_model.dart';

/// Service — stateless wrapper for `audio_service`
final mediaNotificationServiceProvider = Provider<MediaNotificationService>((ref) {
  return const MediaNotificationService();
});

/// Repository — single source of truth, transforms domain → platform
final lockscreenRepositoryProvider = Provider<LockscreenRepository>((ref) {
  final service = ref.watch(mediaNotificationServiceProvider);
  final handler = ref.watch(speechPlaybackControllerProvider);
  return LockscreenRepository(service: service, handler: handler);
});

/// UseCase — cross-repo logic (SpeechEvent → Lockscreen)
final updateLockscreenMediaUseCaseProvider = Provider<UpdateLockscreenMediaUseCase>((ref) {
  final repo = ref.watch(lockscreenRepositoryProvider);
  return UpdateLockscreenMediaUseCase(repo);
});

/// ViewModel — MVVM, injected via constructor, exposes immutable state
final lockscreenViewModelProvider = ChangeNotifierProvider<LockscreenViewModel>((ref) {
  final repo = ref.watch(lockscreenRepositoryProvider);
  final useCase = ref.watch(updateLockscreenMediaUseCaseProvider);
  final engine = ref.watch(speechEngineProvider);
  final vm = LockscreenViewModel(repository: repo, useCase: useCase, engine: engine);
  ref.onDispose(vm.dispose);
  return vm;
});
