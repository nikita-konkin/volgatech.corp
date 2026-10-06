import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../web/files.dart';

/// Hands the calendar file [ics] to wherever this device keeps calendars:
/// the share sheet on Android (a calendar app, mail, a messenger); on an
/// iPhone, Safari's «Добавить все»; on a computer, a download that Outlook
/// or Calendar opens. In a browser it must run straight from the tap, with
/// nothing awaited before, or the new tab is taken for a pop-up.
Future<void> exportCalendar(String ics,
    {required String fileName, required String title}) async {
  if (kIsWeb) {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      openInBrowser(
          'data:text/calendar;charset=utf-8,${Uri.encodeComponent(ics)}');
    } else {
      saveInBrowser(utf8.encode(ics), fileName, 'text/calendar');
    }
    return;
  }
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/$fileName');
  await file.writeAsString(ics, flush: true);
  await SharePlus.instance.share(ShareParams(
    files: [XFile(file.path, mimeType: 'text/calendar')],
    fileNameOverrides: [fileName],
    subject: title,
  ));
}

/// «В календарь» in a top bar; disabled ([onPressed] null) with nothing to add.
class CalendarButton extends StatelessWidget {
  const CalendarButton({super.key, required this.onPressed});
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: 'В календарь',
        icon: const Icon(Icons.event_available_outlined),
        onPressed: onPressed,
      );
}
