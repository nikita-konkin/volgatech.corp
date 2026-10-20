import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Other apps' forms the mail reader opens (MainActivity's TextIntents):
/// a new contact, a new calendar event, a translation. Each answers whether
/// an app took it; off Android there is none.
class TextIntents {
  const TextIntents();

  static const _channel = MethodChannel('volgatech/text');

  bool get available =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<bool> addContact({String? name, String? email, String? phone}) =>
      _call('addContact', {'name': name, 'email': email, 'phone': phone});

  /// An event at [start]: an hour long, or all day when not [timed].
  Future<bool> addEvent({
    required String title,
    required DateTime start,
    required bool timed,
    String? description,
  }) {
    final end = timed
        ? start.add(const Duration(hours: 1))
        : start.add(const Duration(days: 1));
    // An all-day event is a UTC day in Android's calendar.
    DateTime utcDay(DateTime d) => DateTime.utc(d.year, d.month, d.day);
    return _call('addEvent', {
      'title': title,
      'description': description,
      'begin': (timed ? start : utcDay(start)).millisecondsSinceEpoch,
      'end': (timed ? end : utcDay(end)).millisecondsSinceEpoch,
      'allDay': !timed,
    });
  }

  /// False when no app on the phone translates.
  Future<bool> translate(String text) => _call('translate', {'text': text});

  Future<bool> _call(String method, Map<String, Object?> args) async {
    if (!available) return false;
    try {
      return await _channel.invokeMethod<bool>(method, args) ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}
