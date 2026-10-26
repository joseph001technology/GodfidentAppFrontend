import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:godfident/models/local_video.dart';
import 'package:godfident/services/video/video_selector.dart';

void main() {
  group('VideoSelector', () {
    test('returns nothing when nothing is eligible', () {
      final p = VideoSelector(random: Random(1)).plan(eligible: {}, state: CycleState.empty);
      expect(p.candidates, isEmpty);
    });

    test('only ever returns eligible ids (uuid-style ids, no numeric range)', () {
      final ids = {'9f1c-aa', 'b7e2-01', 'c3d4-77'};
      final sel = VideoSelector(random: Random(3));
      var state = CycleState.empty;
      for (var i = 0; i < 50; i++) {
        final p = sel.plan(eligible: ids, state: state);
        expect(p.candidates, isNotEmpty);
        expect(ids.containsAll(p.candidates), isTrue);
        state = sel.markPlayed(p.state, p.candidates.first);
      }
    });

    test('plays every eligible video once per cycle, then starts a new cycle without an immediate repeat', () {
      final ids = {'a', 'b', 'c', 'd', 'e'};
      for (var seed = 0; seed < 100; seed++) {
        final sel = VideoSelector(random: Random(seed));
        var state = CycleState.empty;
        final picked = <String>[];
        for (var i = 0; i < ids.length; i++) {
          final p = sel.plan(eligible: ids, state: state);
          picked.add(p.candidates.first);
          state = sel.markPlayed(p.state, p.candidates.first);
        }
        expect(picked.toSet(), ids, reason: 'seed $seed');
        expect(picked.length, ids.length);

        final next = sel.plan(eligible: ids, state: state);
        expect(next.candidates.length, ids.length, reason: 'new cycle should offer all videos again');
        expect(next.candidates.first, isNot(picked.last), reason: 'seed $seed repeated the last video');
      }
    });

    test('a single eligible video may repeat', () {
      final sel = VideoSelector(random: Random(5));
      var state = CycleState.empty;
      for (var i = 0; i < 4; i++) {
        final p = sel.plan(eligible: {'only'}, state: state);
        expect(p.candidates, ['only']);
        state = sel.markPlayed(p.state, 'only');
      }
    });

    test('a failed attempt (never marked played) does not consume the video', () {
      final sel = VideoSelector(random: Random(9));
      final first = sel.plan(eligible: {'a', 'b', 'c'}, state: CycleState.empty);
      final again = sel.plan(eligible: {'a', 'b', 'c'}, state: first.state);
      expect(again.candidates, first.candidates);
    });

    test('a video added mid-cycle is included and existing order is kept', () {
      final sel = VideoSelector(random: Random(11));
      final p1 = sel.plan(eligible: {'a', 'b', 'c'}, state: CycleState.empty);
      final state = sel.markPlayed(p1.state, p1.candidates.first);
      final remaining = p1.candidates.skip(1).toList();

      final p2 = sel.plan(eligible: {'a', 'b', 'c', 'd'}, state: state);
      expect(p2.candidates.length, 3);
      expect(p2.candidates, contains('d'));
      expect(p2.candidates.where((id) => id != 'd').toList(), remaining);
      expect(p2.candidates, isNot(contains(p1.candidates.first)));
    });

    test('a removed / missing / excluded video is dropped without errors', () {
      final sel = VideoSelector(random: Random(13));
      final p1 = sel.plan(eligible: {'a', 'b', 'c', 'd'}, state: CycleState.empty);
      var state = sel.markPlayed(p1.state, p1.candidates.first);
      // Everything except one video disappears (including the one just played).
      final survivor = p1.candidates.last;
      final p2 = sel.plan(eligible: {survivor}, state: state);
      expect(p2.candidates, [survivor]);
      state = sel.markPlayed(p2.state, survivor);
      final p3 = sel.plan(eligible: {survivor}, state: state);
      expect(p3.candidates, [survivor]);
    });

    test('never leads with the previous video when others exist, even if the set changed', () {
      final sel = VideoSelector(random: Random(17));
      for (var i = 0; i < 100; i++) {
        final p = sel.plan(
          eligible: {'a', 'b', 'c'},
          state: const CycleState(order: ['a', 'b', 'c'], played: [], previousId: 'a'),
        );
        expect(p.candidates.first, isNot('a'));
      }
    });

    test('first pick is not biased toward any position', () {
      final sel = VideoSelector(random: Random(42));
      final counts = {'a': 0, 'b': 0, 'c': 0, 'd': 0};
      const n = 4000;
      for (var i = 0; i < n; i++) {
        final p = sel.plan(eligible: {'a', 'b', 'c', 'd'}, state: CycleState.empty);
        counts[p.candidates.first] = counts[p.candidates.first]! + 1;
      }
      for (final e in counts.entries) {
        expect(e.value, inInclusiveRange(700, 1300), reason: '${e.key} was picked ${e.value}/$n times');
      }
    });

    test('state survives a JSON round trip', () {
      const s = CycleState(order: ['a', 'b'], played: ['a'], previousId: 'a');
      expect(CycleState.fromJson(s.toJson()), s);
      expect(CycleState.fromJson('garbage'), CycleState.empty);
    });
  });
}
