import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_client/data/models.dart';

void main() {
  test('maps server statuses', () {
    expect(RunState.from('queued'), RunState.queued);
    expect(RunState.from('started'), RunState.started);
    expect(RunState.from('running'), RunState.running);
    expect(RunState.from('in_progress'), RunState.running);
    expect(RunState.from('completed'), RunState.completed);
    expect(RunState.from('complete'), RunState.completed);
    expect(RunState.from('succeeded'), RunState.completed);
    expect(RunState.from('failed'), RunState.failed);
    expect(RunState.from('error'), RunState.failed);
    expect(RunState.from('cancelled'), RunState.cancelled);
    expect(RunState.from('canceled'), RunState.cancelled);
    expect(RunState.from('interrupted'), RunState.interrupted);
    expect(RunState.from('whatever'), RunState.unknown);
    expect(RunState.from(null), RunState.unknown);
  });

  test('terminal and active partition the space', () {
    for (final state in RunState.values) {
      expect(state.isTerminal, !state.isActive,
          reason: '$state should be either terminal or active');
    }
    expect(RunState.completed.isTerminal, isTrue);
    expect(RunState.failed.isTerminal, isTrue);
    expect(RunState.cancelled.isTerminal, isTrue);
    expect(RunState.interrupted.isTerminal, isTrue);
    expect(RunState.running.isActive, isTrue);
    expect(RunState.unknown.isActive, isTrue);
  });
}
