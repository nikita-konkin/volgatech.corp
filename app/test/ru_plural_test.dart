import 'package:flutter_test/flutter_test.dart';
import 'package:volgatech_pro/core/ru_plural.dart';

void main() {
  group('pluralRu picks the right form', () {
    String y(int n) => pluralRu(n, 'год', 'года', 'лет');
    test('one: 1, 21, 101 (not 11)', () {
      expect(y(1), 'год');
      expect(y(21), 'год');
      expect(y(101), 'год');
    });
    test('few: 2,3,4,22,33 (not 12–14)', () {
      expect(y(2), 'года');
      expect(y(4), 'года');
      expect(y(23), 'года');
    });
    test('many: 0,5,11,12,13,14,25', () {
      expect(y(0), 'лет');
      expect(y(5), 'лет');
      expect(y(11), 'лет');
      expect(y(12), 'лет');
      expect(y(14), 'лет');
      expect(y(25), 'лет');
    });
  });

  group('humanYearsMonths matches the portal wording', () {
    test('real values from GetInfo', () {
      expect(humanYearsMonths(11, 1), '11 лет 1 месяц'); // Общий стаж
      expect(humanYearsMonths(9, 3), '9 лет 3 месяца'); // научно-педагогический
      expect(humanYearsMonths(8, 8), '8 лет 8 месяцев');
    });
    test('drops zero parts', () {
      expect(humanYearsMonths(8, 0), '8 лет');
      expect(humanYearsMonths(0, 5), '5 месяцев');
      expect(humanYearsMonths(1, 2), '1 год 2 месяца');
      expect(humanYearsMonths(null, null), '');
      expect(humanYearsMonths(0, 0), '');
    });
  });
}
