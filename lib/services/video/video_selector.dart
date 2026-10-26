import 'dart:math';

import '../../models/local_video.dart';

/// What [VideoSelector.plan] decided.
class SelectionPlan {
  /// Ids to try, in order. The first is the pick; the rest are fallbacks used
  /// only when the earlier ones fail to open. Empty when nothing is eligible.
  final List<String> candidates;

  /// Cycle state after reconciling with the eligible set (persist if changed).
  final CycleState state;

  const SelectionPlan(this.candidates, this.state);
}

/// Shuffled-bag selection over the IDs of the *currently eligible* videos.
///
/// * Every eligible video is played once per cycle, in a shuffled order.
/// * When the bag is empty a new shuffled cycle starts; its first video is never
///   the one just played (when 2+ videos are eligible).
/// * Videos added mid-cycle are slotted at random into the unplayed rest;
///   videos that disappear or are excluded are dropped from the bag.
/// * With a single eligible video it simply repeats.
///
/// Pure logic: no I/O, so it is fully unit-testable with a seeded [Random].
class VideoSelector {
  VideoSelector({Random? random}) : _rnd = random ?? Random();

  final Random _rnd;

  SelectionPlan plan({required Set<String> eligible, required CycleState state}) {
    if (eligible.isEmpty) {
      return SelectionPlan(const [], CycleState(previousId: state.previousId));
    }

    // Drop ids that are no longer eligible (deleted, moved, excluded, broken).
    final seen = <String>{};
    final order = <String>[
      for (final id in state.order)
        if (eligible.contains(id) && seen.add(id)) id,
    ];
    final played = state.played.where((id) => seen.contains(id)).toSet();

    // Ids that appeared since the cycle was built.
    final newcomers = eligible.where((id) => !seen.contains(id)).toList()..shuffle(_rnd);

    final playedInOrder = order.where(played.contains).toList();
    final unplayed = order.where((id) => !played.contains(id)).toList();
    for (final id in newcomers) {
      unplayed.insert(_rnd.nextInt(unplayed.length + 1), id);
    }

    // Bag empty -> start a new shuffled cycle.
    if (unplayed.isEmpty) {
      final fresh = eligible.toList()..shuffle(_rnd);
      _avoidLeading(fresh, state.previousId);
      return SelectionPlan(List.unmodifiable(fresh), CycleState(order: fresh, played: const [], previousId: state.previousId));
    }

    // Never repeat the previous video straight away (e.g. after eligibility changed).
    _avoidLeading(unplayed, state.previousId);

    return SelectionPlan(
      List.unmodifiable(unplayed),
      CycleState(order: [...playedInOrder, ...unplayed], played: playedInOrder, previousId: state.previousId),
    );
  }

  /// Call only once playback really started.
  CycleState markPlayed(CycleState s, String id) {
    final played = s.played.contains(id) ? s.played : [...s.played, id];
    final order = s.order.contains(id) ? s.order : [...s.order, id];
    return CycleState(order: order, played: played, previousId: id);
  }

  /// If [list] starts with [previous] and has another entry, move it back.
  void _avoidLeading(List<String> list, String? previous) {
    if (previous == null || list.length < 2 || list.first != previous) return;
    final j = 1 + _rnd.nextInt(list.length - 1);
    final t = list[0];
    list[0] = list[j];
    list[j] = t;
  }
}
