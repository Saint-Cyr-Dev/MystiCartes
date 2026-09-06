import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mysticartes/features/battle/widgets/battle_pausable_animation.dart';

void main() {
  testWidgets('animation resumes at its frozen progress after a long pause', (
    tester,
  ) async {
    final paused = ValueNotifier(false);
    addTearDown(paused.dispose);
    var progress = 0.0;
    await tester.pumpWidget(
      ValueListenableBuilder<bool>(
        valueListenable: paused,
        builder: (context, isPaused, _) => BattlePausableAnimation(
          duration: const Duration(seconds: 1),
          paused: isPaused,
          builder: (context, value, child) {
            progress = value;
            return const SizedBox();
          },
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    expect(progress, closeTo(0.4, 0.001));
    paused.value = true;
    await tester.pump();
    await tester.pump(const Duration(seconds: 10));
    expect(progress, closeTo(0.4, 0.001));
    paused.value = false;
    await tester.pump();
    expect(progress, closeTo(0.4, 0.001));
    await tester.pump(const Duration(milliseconds: 300));
    expect(progress, closeTo(0.7, 0.001));
    await tester.pump(const Duration(milliseconds: 300));
    expect(progress, 1);
  });

  testWidgets('animation created during pause does not start until resume', (
    tester,
  ) async {
    final paused = ValueNotifier(true);
    addTearDown(paused.dispose);
    var progress = -1.0;
    await tester.pumpWidget(
      ValueListenableBuilder<bool>(
        valueListenable: paused,
        builder: (context, isPaused, _) => BattlePausableAnimation(
          duration: const Duration(seconds: 1),
          paused: isPaused,
          child: const SizedBox(key: Key('reused-animation-child')),
          builder: (context, value, child) {
            progress = value;
            return child!;
          },
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 5));
    expect(progress, 0);
    expect(find.byKey(const Key('reused-animation-child')), findsOneWidget);
    paused.value = false;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(progress, closeTo(0.5, 0.001));
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });
}
