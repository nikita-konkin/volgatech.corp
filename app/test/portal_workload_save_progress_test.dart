import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:volgatech_pro/core/portal_workload_save_progress.dart';

void main() {
  test('A single month advances by a quarter for each completed stage', () {
    final stages = [0, 1, 2, 3, 4]..shuffle(Random());
    final fractions = [0.0, 0.25, 0.5, 0.75, 1.0];
    expect(
      [
        for (final completedStages in stages)
          workloadSaveProgress(
            months: 1,
            completedMonths: 0,
            completedStages: completedStages,
          ),
      ],
      [for (final completedStages in stages) fractions[completedStages]],
      reason: 'the stages did not each advance the save by one quarter',
    );
  });

  test('A batch includes the completed stages of the current month', () {
    final random = Random();
    final months = random.nextInt(7) + 5;
    final completedMonths = random.nextInt(months - 2) + 1;
    final completedStages = random.nextInt(3) + 1;
    expect(
      workloadSaveProgress(
        months: months,
        completedMonths: completedMonths,
        completedStages: completedStages,
      ),
      (completedMonths * 4 + completedStages) / (months * 4),
      reason: 'the batch did not count the stages of the current month',
    );
  });

  test('A batch keeps its progress between months and ends at one', () {
    final random = Random();
    final months = random.nextInt(8) + 4;
    final completedMonths = random.nextInt(months - 1);
    final endOfMonth = workloadSaveProgress(
      months: months,
      completedMonths: completedMonths,
      completedStages: 4,
    );
    final startOfNextMonth = workloadSaveProgress(
      months: months,
      completedMonths: completedMonths + 1,
      completedStages: 0,
    );
    final endOfBatch = workloadSaveProgress(
      months: months,
      completedMonths: months - 1,
      completedStages: 4,
    );
    expect(
      [startOfNextMonth - endOfMonth, endOfBatch],
      [0, 1],
      reason: 'the batch did not preserve progress or reach full completion',
    );
  });
}
