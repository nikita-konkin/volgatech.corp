import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../theme.dart';
import '../mail_controller.dart';
import '../mail_models.dart';
import 'mail_actions.dart';
import 'message_page.dart';

/// A message in the folder list: swipe left to delete it (with a moment to
/// take that back), right to mark it read or unread; a long press for the
/// rest (pin, archive, move).
class SwipeableMessage extends StatelessWidget {
  const SwipeableMessage(this.h, {super.key});
  final MailHeader h;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Dismissible(
      key: ValueKey(h.id),
      background: _SwipeHint(
          start: true,
          color: primary,
          icon: h.seen
              ? Icons.mark_email_unread_outlined
              : Icons.mark_email_read_outlined,
          label: h.seen ? 'Непрочитанное' : 'Прочитано'),
      secondaryBackground: const _SwipeHint(
          start: false,
          color: Brand.coral,
          icon: Icons.delete_outline,
          label: 'Удалить'),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.endToStart) return true;
        // Read / unread: the message stays where it is.
        unawaited(context.read<MailController>().toggleSeen(h));
        return false;
      },
      onDismissed: (_) => deleteWithUndo(context, h),
      child: MessageTile(h,
          onLongPress: () => unawaited(showMessageActions(context, h))),
    );
  }
}

class _SwipeHint extends StatelessWidget {
  const _SwipeHint(
      {required this.start,
      required this.color,
      required this.icon,
      required this.label});
  final bool start;
  final Color color;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    const white = TextStyle(color: Colors.white, fontWeight: FontWeight.w600);
    final parts = [
      Icon(icon, color: Colors.white),
      const SizedBox(width: 8),
      Text(label, style: white),
    ];
    return ColoredBox(
      color: color,
      child: Align(
        alignment: start ? Alignment.centerLeft : Alignment.centerRight,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
              mainAxisSize: MainAxisSize.min,
              children: start ? parts : parts.reversed.toList()),
        ),
      ),
    );
  }
}

IconData folderIcon(FolderRole role) => switch (role) {
      FolderRole.inbox => Icons.inbox,
      FolderRole.sent => Icons.send,
      FolderRole.drafts => Icons.drafts,
      FolderRole.trash => Icons.delete_outline,
      FolderRole.junk => Icons.report_outlined,
      FolderRole.archive => Icons.archive_outlined,
      FolderRole.other => Icons.folder_outlined,
    };

/// The wash behind pinned messages, as in Outlook on the web.
Color pinnedTint(BuildContext context) =>
    Theme.of(context).colorScheme.primary.withValues(alpha: 0.09);

/// Where the size colours start, and how many tenfold steps they span:
/// yellow from 100 KB, orange at 1 MB, red from 10 MB.
const sizeTintFrom = 100 * 1024;
const _sizeTintDecades = 2;

/// ColorBrewer's YlOrRd: a sequential scale that reads «more» as «hotter».
const _ylOrRd = [Color(0xFFFED976), Color(0xFFFD8D3C), Color(0xFFE31A1C)];

/// The wash behind a message of [size] bytes, on a log scale from
/// [sizeTintFrom]; null for smaller ones. Translucent, so the text keeps its
/// contrast on either theme and a pinned row's own wash shows through.
Color? sizeTint(int? size, {required bool dark}) {
  if (size == null || size <= sizeTintFrom) return null;
  final t = (math.log(size / sizeTintFrom) / math.ln10 / _sizeTintDecades)
      .clamp(0.0, 1.0);
  return sizeTintAt(t, dark: dark);
}

/// The size colour [t] of the way from 100 KB (0) to 10 MB (1).
Color sizeTintAt(double t, {required bool dark}) {
  final hue = t < 0.5
      ? Color.lerp(_ylOrRd[0], _ylOrRd[1], t * 2)!
      : Color.lerp(_ylOrRd[1], _ylOrRd[2], t * 2 - 1)!;
  // Fades in from almost nothing, so 100 KB is not a hard edge.
  return hue.withValues(alpha: dark ? 0.08 + 0.3 * t : 0.08 + 0.22 * t);
}

/// One line of a message list: sender, date, subject and marks.
class MessageTile extends StatelessWidget {
  const MessageTile(this.h, {super.key, this.onOpened, this.onLongPress});
  final MailHeader h;

  /// After the message was opened (it is read now).
  final VoidCallback? onOpened;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final muted = Brand.muted(context);
    final bold = h.seen ? FontWeight.normal : FontWeight.bold;
    var tint = h.pinned ? pinnedTint(context) : null;
    if (context.select<MailController, bool>((c) => c.sizeColors)) {
      final dark = Theme.of(context).brightness == Brightness.dark;
      if (sizeTint(h.size, dark: dark) case final bySize?) {
        tint = tint == null ? bySize : Color.alphaBlend(bySize, tint);
      }
    }
    return Material(
      color: tint ?? Colors.transparent,
      child: InkWell(
        onTap: () async {
          await Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => ChangeNotifierProvider.value(
              value: context.read<MailController>(),
              child: MessagePage(header: h),
            ),
          ));
          onOpened?.call();
        },
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 16, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 16,
                child: h.seen
                    ? null
                    : const Padding(
                        padding: EdgeInsets.only(top: 6),
                        child: CircleAvatar(
                            radius: 4, backgroundColor: Brand.coral),
                      ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                        child: Text(h.from,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 15, fontWeight: bold)),
                      ),
                      const SizedBox(width: 8),
                      Text(mailDate(h.date, DateTime.now()),
                          style: TextStyle(fontSize: 12.5, color: muted)),
                    ]),
                    const SizedBox(height: 2),
                    Row(children: [
                      Expanded(
                        child: Text(
                            h.subject.isEmpty ? '(без темы)' : h.subject,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: bold,
                                color: h.seen ? muted : null)),
                      ),
                      if (h.pinned)
                        Icon(Icons.push_pin,
                            size: 15,
                            color: Theme.of(context).colorScheme.primary),
                      if (h.hasAttachments)
                        Icon(Icons.attach_file, size: 16, color: muted),
                      if (h.answered) Icon(Icons.reply, size: 16, color: muted),
                      if (h.size case final size?) ...[
                        const SizedBox(width: 6),
                        Text(fileSize(size),
                            style: TextStyle(fontSize: 12, color: muted)),
                      ],
                    ]),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// «14:05» today, «3 сент.» this year, «03.09.25» before.
String mailDate(DateTime? d, DateTime now) {
  if (d == null) return '';
  final l = d.toLocal();
  if (l.year == now.year && l.month == now.month && l.day == now.day) {
    return DateFormat('HH:mm').format(l);
  }
  if (l.year == now.year) return DateFormat('d MMM', 'ru_RU').format(l);
  return DateFormat('dd.MM.yy').format(l);
}

/// The list heading a message falls under, as in Outlook on the web:
/// «Сегодня», «Вчера», «На этой неделе», «На прошлой неделе», then the month
/// («Август», or «Декабрь 2025» for another year).
String dateGroup(DateTime? d, DateTime now) {
  if (d == null) return 'Без даты';
  final l = d.toLocal();
  final day = DateTime(l.year, l.month, l.day);
  bool since(DateTime from) => !day.isBefore(from);
  if (since(DateTime(now.year, now.month, now.day))) return 'Сегодня';
  if (since(DateTime(now.year, now.month, now.day - 1))) return 'Вчера';
  final monday = DateTime(now.year, now.month, now.day - (now.weekday - 1));
  if (since(monday)) return 'На этой неделе';
  if (since(DateTime(monday.year, monday.month, monday.day - 7))) {
    return 'На прошлой неделе';
  }
  final month = DateFormat('LLLL', 'ru_RU').format(day);
  final title = month[0].toUpperCase() + month.substring(1);
  return day.year == now.year ? title : '$title ${day.year}';
}
