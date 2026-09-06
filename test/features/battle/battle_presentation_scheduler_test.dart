import 'package:flutter_test/flutter_test.dart';
import 'package:mysticartes/features/battle/battle_presentation_scheduler.dart';

void main() {
  testWidgets('pause preserves the remaining AI presentation delay', (
    tester,
  ) async {
    final epoch = tester.binding.clock.now();
    final scheduler = BattlePresentationScheduler(
      elapsed: () => tester.binding.clock.now().difference(epoch),
    );
    bool? completed;
    scheduler
        .wait(const Duration(seconds: 1))
        .then((value) => completed = value);

    await tester.pump(const Duration(milliseconds: 400));
    scheduler.pause();
    await tester.pump(const Duration(seconds: 10));
    expect(completed, isNull);
    scheduler.resume();
    await tester.pump(const Duration(milliseconds: 599));
    expect(completed, isNull);
    await tester.pump(const Duration(milliseconds: 1));
    expect(completed, isTrue);
    scheduler.dispose();
  });

  testWidgets('tasks created during pause wait for resume', (tester) async {
    final scheduler = BattlePresentationScheduler()..pause();
    var callbackCount = 0;
    scheduler.schedule(
      const Duration(milliseconds: 500),
      () => callbackCount++,
    );
    await tester.pump(const Duration(seconds: 5));
    expect(callbackCount, 0);
    scheduler.resume();
    await tester.pump(const Duration(milliseconds: 500));
    expect(callbackCount, 1);
    scheduler.dispose();
  });

  testWidgets('restart cancels pending callbacks and unblocks old waits', (
    tester,
  ) async {
    final scheduler = BattlePresentationScheduler();
    var callbackCount = 0;
    final waiting = scheduler.wait(const Duration(seconds: 1));
    final task = scheduler.schedule(
      const Duration(seconds: 1),
      () => callbackCount++,
    );
    scheduler.cancelAll();
    expect(await waiting, isFalse);
    expect(task.isActive, isFalse);
    await tester.pump(const Duration(seconds: 2));
    expect(callbackCount, 0);
    scheduler.schedule(Duration.zero, () => callbackCount++);
    await tester.pump(const Duration(milliseconds: 1));
    expect(callbackCount, 1);
    scheduler.dispose();
  });

  testWidgets('dispose cancels paused waits and rejects late scheduling', (
    tester,
  ) async {
    final scheduler = BattlePresentationScheduler()..pause();
    final waiting = scheduler.wait(const Duration(seconds: 1));
    scheduler.dispose();
    expect(await waiting, isFalse);
    expect(await scheduler.wait(Duration.zero), isFalse);
    var called = false;
    final task = scheduler.schedule(Duration.zero, () => called = true);
    scheduler.resume();
    await tester.pump(const Duration(seconds: 2));
    expect(task.isActive, isFalse);
    expect(called, isFalse);
  });
}
