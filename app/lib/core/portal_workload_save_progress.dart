/// The fraction of save stages completed across the months being submitted.
double workloadSaveProgress({
  required int months,
  required int completedMonths,
  required int completedStages,
}) =>
    (completedMonths + completedStages / 4) / months;
