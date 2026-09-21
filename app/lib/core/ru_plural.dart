/// Russian plural selection — pick the `one` / `few` / `many` form for [n].
/// 1 → one (год), 2–4 → few (года), 0 & 5–20 → many (лет); handles the 11–14
/// exception. Pure and unit-tested (see test/ru_plural_test.dart).
String pluralRu(int n, String one, String few, String many) {
  final n100 = n % 100, n10 = n % 10;
  if (n10 == 1 && n100 != 11) return one;
  if (n10 >= 2 && n10 <= 4 && !(n100 >= 12 && n100 <= 14)) return few;
  return many;
}

String yearsWord(int n) => pluralRu(n, 'год', 'года', 'лет');
String monthsWord(int n) => pluralRu(n, 'месяц', 'месяца', 'месяцев');

/// "11 лет 1 месяц" · "9 лет 3 месяца" · "8 лет" · "5 месяцев" · '' when both 0/null.
String humanYearsMonths(int? year, int? month) {
  final parts = <String>[];
  if (year != null && year > 0) parts.add('$year ${yearsWord(year)}');
  if (month != null && month > 0) parts.add('$month ${monthsWord(month)}');
  return parts.join(' ');
}
