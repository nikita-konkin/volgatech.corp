/// A time of year, as the calendar has them: what the glass's ornament
/// shows (see `GlassOrnament`).
enum Season {
  autumn,
  winter,
  spring,
  summer;

  /// The season [day] falls in.
  static Season of(DateTime day) => switch (day.month) {
        12 || 1 || 2 => winter,
        3 || 4 || 5 => spring,
        6 || 7 || 8 => summer,
        _ => autumn,
      };
}
