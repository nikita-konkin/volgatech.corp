import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../mail_controller.dart';
import '../mail_models.dart';
import 'message_tile.dart' show folderIcon;

/// What can be done to a message, from the list (a long press) or the open
/// message: shared so both say and do the same.

/// A folder to move a message to, other than the open one; null if none
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

/// Moves [h] to [to]: off the list at once, said in a snackbar; the list
/// comes back from the server if the server refuses.
void moveMessage(BuildContext context, MailHeader h, MailFolder to) {
  final c = context.read<MailController>();
  final messenger = ScaffoldMessenger.of(context);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
        SnackBar(content: Text('Письмо перемещено в «${to.title}»')));
  unawaited(c.move(h, to).catchError((Object e) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
          SnackBar(content: Text('Не удалось переместить письмо: $e')));
    return c.refresh();
  }));
}

/// Files [h] in the archive, first offering to make «Архив» when the
/// mailbox has no archive folder. True once the message is on its way.
Future<bool> archiveMessage(BuildContext context, MailHeader h) async {
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
  moveMessage(context, h, to);
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

/// Pins [h], or unpins it if it is pinned. True when the server took it.
Future<bool> togglePin(BuildContext context, MailHeader h) async {
  final c = context.read<MailController>();
  final messenger = ScaffoldMessenger.of(context);
  final pin = !h.pinned;
  try {
    await c.setPinned(h, pin);
  } on Object catch (e) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
          content: Text(
              'Не удалось ${pin ? 'закрепить' : 'открепить'} письмо: $e')));
    return false;
  }
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(pin ? 'Письмо закреплено' : 'Письмо откреплено'),
      duration: const Duration(seconds: 2),
    ));
  return true;
}

/// Deletes [h] with a few seconds to take it back.
void deleteWithUndo(BuildContext context, MailHeader h) {
  final c = context.read<MailController>();
  final forever = c.folder.role == FolderRole.trash;
  c.deleteSoon(h);
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(forever
          ? 'Письмо удалено навсегда'
          : 'Письмо перемещено в «Удалённые»'),
      duration: const Duration(seconds: 4),
      // Goes after its duration (with an action Flutter would keep it).
      persist: false,
      action: SnackBarAction(label: 'Отменить', onPressed: c.undoDelete),
    ));
}

enum _Action { pin, archive, move, seen, delete }

/// Everything for [h] at once: what a long press on it in the list opens.
Future<void> showMessageActions(BuildContext context, MailHeader h) async {
  final c = context.read<MailController>();
  final action = await showModalBottomSheet<_Action>(
    context: context,
    showDragHandle: true,
    builder: (context) {
      Widget item(_Action a, IconData icon, String title) => ListTile(
            leading: Icon(icon),
            title: Text(title),
            onTap: () => Navigator.pop(context, a),
          );
      return SafeArea(
        child: ListView(shrinkWrap: true, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(h.subject.isEmpty ? '(без темы)' : h.subject,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
          item(_Action.pin, h.pinned ? Icons.push_pin : Icons.push_pin_outlined,
              h.pinned ? 'Открепить' : 'Закрепить'),
          if (c.folder.role != FolderRole.archive)
            item(_Action.archive, Icons.archive_outlined, 'В архив'),
          item(_Action.move, Icons.drive_file_move_outline, 'Переместить'),
          item(
              _Action.seen,
              h.seen
                  ? Icons.mark_email_unread_outlined
                  : Icons.mark_email_read_outlined,
              h.seen ? 'Отметить непрочитанным' : 'Отметить прочитанным'),
          item(_Action.delete, Icons.delete_outline, 'Удалить'),
        ]),
      );
    },
  );
  if (action == null || !context.mounted) return;
  switch (action) {
    case _Action.pin:
      await togglePin(context, h);
    case _Action.archive:
      await archiveMessage(context, h);
    case _Action.move:
      final to = await pickFolder(context, c);
      if (to != null && context.mounted) moveMessage(context, h, to);
    case _Action.seen:
      await c.toggleSeen(h);
    case _Action.delete:
      deleteWithUndo(context, h);
  }
}
