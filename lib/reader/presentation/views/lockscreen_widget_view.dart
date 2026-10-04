import 'dart:io';

import 'package:flutter/material.dart';

import 'package:atlas_app/reader/presentation/view_models/lockscreen_view_model.dart';

/// View: dumb widget that reflects `LockscreenViewModel` state.
/// System lockscreen itself is rendered by `audio_service` (MediaStyle/SMTC),
/// this view is for in-app preview / debugging.
class LockscreenWidgetView extends StatelessWidget {
  const LockscreenWidgetView({super.key, required this.viewModel});

  final LockscreenViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) {
        final state = viewModel.state;
        if (state == null) return const SizedBox.shrink();
        return Card(
          child: ListTile(
            leading: state.coverPath != null ? Image.file(
              // ignore: avoid_dynamic_calls
              File(state.coverPath!),
              width: 40,
              height: 40,
              errorBuilder: (_, _, _) => const Icon(Icons.music_note),
            ) : const Icon(Icons.music_note),
            title: Text(state.chapterTitle),
            subtitle: Text('${state.bookTitle} • ${state.author}'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(state.isPlaying ? Icons.pause : Icons.play_arrow),
                  onPressed: state.isPlaying ? viewModel.pause : viewModel.resume,
                ),
                IconButton(icon: const Icon(Icons.stop), onPressed: viewModel.stop),
              ],
            ),
          ),
        );
      },
    );
  }
}


