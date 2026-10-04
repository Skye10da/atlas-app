import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:atlas_app/reader/presentation/view_models/pronunciation_view_model.dart';
import 'package:atlas_app/reader/speech/pronunciation/apply_pronunciation_use_case.dart';
import 'package:atlas_app/reader/speech/pronunciation/pronunciation_repository.dart';

final pronunciationRepositoryProvider = Provider<PronunciationRepository>((ref) {
  return PronunciationRepository();
});

final pronunciationUseCaseProvider = Provider<ApplyPronunciationUseCase>((ref) {
  return const ApplyPronunciationUseCase();
});

final pronunciationViewModelProvider = ChangeNotifierProvider<PronunciationViewModel>((ref) {
  final repo = ref.watch(pronunciationRepositoryProvider);
  final vm = PronunciationViewModel(repository: repo);
  // Load defaults lazily
  vm.load();
  ref.onDispose(vm.dispose);
  return vm;
});
