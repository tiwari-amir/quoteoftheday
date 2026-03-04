import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants.dart';
import 'storage_provider.dart';

class ViewerProgressState {
  const ViewerProgressState({
    required this.scrolledCount,
    required this.lastMilestone,
  });

  final int scrolledCount;
  final int lastMilestone;

  ViewerProgressState copyWith({int? scrolledCount, int? lastMilestone}) {
    return ViewerProgressState(
      scrolledCount: scrolledCount ?? this.scrolledCount,
      lastMilestone: lastMilestone ?? this.lastMilestone,
    );
  }
}

class ViewerProgressNotifier extends StateNotifier<ViewerProgressState> {
  ViewerProgressNotifier(this._ref)
    : super(
        ViewerProgressState(
          scrolledCount:
              _ref
                  .read(sharedPreferencesProvider)
                  .getInt(prefViewerScrolledCount) ??
              0,
          lastMilestone:
              _ref
                  .read(sharedPreferencesProvider)
                  .getInt(prefViewerLastMilestone) ??
              0,
        ),
      );

  final Ref _ref;

  Future<int> incrementScrolledCount() async {
    final next = state.scrolledCount + 1;
    state = state.copyWith(scrolledCount: next);
    await _ref
        .read(sharedPreferencesProvider)
        .setInt(prefViewerScrolledCount, next);
    return next;
  }

  Future<void> setLastMilestone(int milestone) async {
    if (state.lastMilestone == milestone) return;
    state = state.copyWith(lastMilestone: milestone);
    await _ref
        .read(sharedPreferencesProvider)
        .setInt(prefViewerLastMilestone, milestone);
  }
}

final viewerProgressProvider =
    StateNotifierProvider<ViewerProgressNotifier, ViewerProgressState>(
      ViewerProgressNotifier.new,
    );
