import 'package:dailyhabits/models/habit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('CompletionState.fromString defaults to pending', () {
    expect(CompletionState.fromString(null), CompletionState.pending);
    expect(CompletionState.fromString('unknown'), CompletionState.pending);
  });

  test('CompletionState.fromString maps known values', () {
    expect(CompletionState.fromString('completed'), CompletionState.completed);
    expect(CompletionState.fromString('skipped'), CompletionState.skipped);
    expect(CompletionState.fromString('missed'), CompletionState.missed);
  });

  test('HabitCategory.fromName falls back to Custom', () {
    final category = HabitCategory.fromName('does-not-exist');
    expect(category.name, 'Custom');
  });
}
