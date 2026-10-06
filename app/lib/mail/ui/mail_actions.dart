import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/ru_plural.dart';
import '../mail_controller.dart';
import '../mail_models.dart';
import 'message_tile.dart' show folderIcon;

/// What can be done to messages, from the list (one swiped, or several
/// picked) or the open message: shared so all say and do the same.

/// «Письмо» or «3 письма»: the start of what was done to [n] messages.
String lettersDone(int n, String one, String several) => n == 1
    ? 'Письмо $one'
    : '$n ${pluralRu(n, 'письмо', 'письма', 'писем')} '
        '${pluralRu(n, one, several, several)}';

/// A folder to move messages to, other than the open one; null if none
/// was picked.
Future<MailFolder?> pickFolder(BuildContext context, MailController c) =>
    showModalBottomSheet<MailFolder>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(shrinkWrap: true, children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text('Переместить в папку',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
          for (final f in c.folders)
            if (f != c.folder)
              ListTile(
                leading: Icon(folderIcon(f.role)),
                title: Text(f.title),
                onTap: () => Navigator.pop(context, f),
              ),
        ]),
      ),
    );

/// Moves [hs] to [to]: off the list at once, said in a snackbar; the list
/// comes back from the server if the server refuses.
void moveMessages(BuildContext context, List<MailHeader> hs, MailFolder to) {
  final c = context.read<MailController>();
  final messenger = ScaffoldMessenger.of(context);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
        content: Text('${lettersDone(hs.length, 'перемещено', 'перемещены')} '
            'в «${to.title}»')));
  unawaited(c.moveAll(hs, to).catchError((Object e) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('Не удалось переместить: $e')));
    return c.refresh();
  }));
}

/// Files [hs] in the archive, first offering to make «Архив» when the
/// mailbox has no archive folder. True once they are on their way.
Future<bool> archiveMessages(BuildContext context, List<MailHeader> hs) async {
  final c = context.read<MailController>();
  final messenger = ScaffoldMessenger.of(context);
  var to = c.archiveFolder;
  if (to == null) {
    if (!await _confirmNewArchive(context)) return false;
    try {
      to = await c.createArchive();
    } on Object catch (e) {
      messenger.showSnackBar(
          SnackBar(content: Text('Не удалось создать папку «Архив»: $e')));
      return false;
    }
  }
  if (!context.mounted) return false;
  moveMessages(context, hs, to);
  return true;
}

Future<bool> _confirmNewArchive(BuildContext context) async =>
    await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Создать папку «Архив»?'),
        content: const Text('В ящике нет папки для архива. Она появится '
            'рядом с «Входящими», в веб-версии почты тоже.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Отмена')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Создать')),
        ],
      ),
    ) ??
    false;

/// Pins [hs] (or unpins them, with [pin] false). True when the server took
/// them all.
Future<bool> pinMessages(
    BuildContext context, List<MailHeader> hs, bool pin) async {
  final c = context.read<MailController>();
  final messenger = ScaffoldMessenger.of(context);
  try {
    await c.pinAll(hs, pin);
  } on Object catch (e) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
          content: Text('Не удалось ${pin ? 'закрепить' : 'открепить'}: $e')));
    return false;
  }
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(pin
          ? lettersDone(hs.length, 'закреплено', 'закреплены')
          : lettersDone(hs.length, 'откреплено', 'откреплены')),
      duration: const Duration(seconds: 2),
    ));
  return true;
}

/// Pins [h], or unpins it if it is pinned. True when the server took it.
Future<bool> togglePin(BuildContext context, MailHeader h) =>
    pinMessages(context, [h], !h.pinned);

/// Deletes [hs] with a few seconds to take them back.
void deleteWithUndo(BuildContext context, List<MailHeader> hs) {
  final c = context.read<MailController>();
  final forever = c.folder.role == FolderRole.trash;
  c.deleteSoonAll(hs);
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(forever
          ? '${lettersDone(hs.length, 'удалено', 'удалены')} навсегда'
          : '${lettersDone(hs.length, 'перемещено', 'перемещены')} '
              'в «Удалённые»'),
      duration: const Duration(seconds: 4),
      // Goes after its duration (with an action Flutter would keep it).
      persist: false,
      action: SnackBarAction(label: 'Отменить', onPressed: c.undoDelete),
    ));
}
