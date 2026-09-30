import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/prefs.dart';
import '../../core/ru_plural.dart';
import '../../theme.dart';
import '../mail_controller.dart';
import '../mail_models.dart';
import 'message_page.dart' show fileSize;
import 'message_tile.dart' show folderIcon, sizeTintAt;

/// «Размер ящика»: how much the mailbox takes and which folders take it.
class MailboxSizePage extends StatefulWidget {
  const MailboxSizePage({super.key});

  @override
  State<MailboxSizePage> createState() => _MailboxSizePageState();
}

class _MailboxSizePageState extends State<MailboxSizePage> {
  late Future<MailboxUsage> _usage = context.read<MailController>().usage();

  Future<void> _reload() async {
    final next = context.read<MailController>().usage();
    setState(() => _usage = next);
    await next;
  }

  Future<void> _setLimit() async {
    final c = context.read<MailController>();
    final prefs = context.read<Prefs>();
    final bytes = await showDialog<int>(
        context: context, builder: (_) => _LimitDialog(current: c.manualQuota));
    if (bytes == null) return; // cancelled
    final limit = bytes > 0 ? bytes : null;
    await prefs.setMailQuota(limit);
    c.setManualQuota(limit);
  }

  @override
  Widget build(BuildContext context) {
    final muted = Brand.muted(context);
    final manual = context.select<MailController, int?>((c) => c.manualQuota);
    return Scaffold(
      appBar: AppBar(title: const Text('Размер ящика')),
      body: FutureBuilder<MailboxUsage>(
        future: _usage,
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text('Не удалось узнать размер ящика',
                    style: TextStyle(color: muted)),
                const SizedBox(height: 12),
                OutlinedButton(
                    onPressed: _reload, child: const Text('Повторить')),
              ]),
            );
          }
          final u = snap.data;
          if (u == null) {
            return const Center(child: CircularProgressIndicator());
          }
          final folders = [
            for (final f in u.folders)
              if (f.size > 0) f
          ];
          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                _Total(
                  usage: u,
                  quota: u.quota ?? manual,
                  manual: u.quota == null,
                  onLimit: _setLimit,
                ),
                for (final f in folders)
                  ListTile(
                    leading: Icon(folderIcon(f.folder.role)),
                    title: Text(f.folder.title,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(
                        '${f.count} ${pluralRu(f.count, 'письмо', 'письма', 'писем')}'),
                    trailing: Text(fileSize(f.size),
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// «1,8 из 2 ГБ», «450 из 500 МБ»; «1,8 ГБ занято» when the limit is unknown.
String usageLabel(int used, int? quota) {
  if (quota == null) return '${fileSize(used)} занято';
  const mb = 1024 * 1024, gb = 1024 * mb;
  if (quota < gb) return '${(used / mb).round()} из ${(quota / mb).round()} МБ';
  String n(int v) {
    final x = v / gb;
    return x == x.roundToDouble()
        ? '${x.round()}'
        : x.toStringAsFixed(1).replaceAll('.', ',');
  }

  return '${n(used)} из ${n(quota)} ГБ';
}

/// The mailbox's fill in the top bar of the list; opens «Размер ящика».
class UsageBar extends StatelessWidget {
  const UsageBar({super.key, required this.usage, required this.onTap});
  final MailboxUsage usage;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = IconTheme.of(context).color ?? Colors.white;
    final quota = usage.quota;
    final share = quota == null ? null : (usage.used / quota).clamp(0.0, 1.0);
    return Tooltip(
      message: 'Размер ящика',
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(usageLabel(usage.used, quota),
                  style: TextStyle(
                      color: fg, fontSize: 11.5, fontWeight: FontWeight.w600)),
              if (share != null) ...[
                const SizedBox(height: 4),
                SizedBox(
                  width: 64,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: share,
                      minHeight: 4,
                      backgroundColor: fg.withValues(alpha: 0.3),
                      color: share > 0.9 ? Brand.coral : fg,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Total extends StatelessWidget {
  const _Total(
      {required this.usage,
      required this.quota,
      required this.manual,
      required this.onLimit});
  final MailboxUsage usage;

  /// The server's limit, or else the one typed in.
  final int? quota;

  /// The server doesn't tell the limit: it can be typed in ([onLimit]).
  final bool manual;
  final VoidCallback onLimit;

  @override
  Widget build(BuildContext context) {
    final muted = Brand.muted(context);
    final quota = this.quota;
    final share = quota == null ? null : (usage.used / quota).clamp(0.0, 1.0);
    final note = TextStyle(color: muted, fontSize: 12.5);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(TextSpan(children: [
            TextSpan(
                text: fileSize(usage.used),
                style:
                    const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
            TextSpan(
                text: quota == null ? '  занято' : '  из ${fileSize(quota)}',
                style: TextStyle(fontSize: 16, color: muted)),
          ])),
          if (share != null) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: share,
                minHeight: 8,
                color: share > 0.9 ? Brand.coral : null,
                // Free space in grey: the theme's track is coral-ish, which
                // read as a warning.
                backgroundColor: muted.withValues(alpha: 0.2),
              ),
            ),
            const SizedBox(height: 6),
            Text(
                quota! > usage.used
                    ? 'Свободно ${fileSize(quota - usage.used)}'
                    : 'Ящик заполнен — отправка писем остановлена',
                style: TextStyle(color: muted)),
            if (manual)
              Row(children: [
                Expanded(child: Text('Лимит указан вручную', style: note)),
                TextButton(onPressed: onLimit, child: const Text('Изменить')),
              ]),
          ] else ...[
            const SizedBox(height: 6),
            Text(
              'Сколько всего можно занять, почтовый сервер приложению не '
              'сообщает. Лимит виден в веб-почте: Параметры → Общие → '
              'Моя учётная запись.',
              style: note,
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: onLimit,
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Указать лимит'),
              ),
            ),
          ],
          if (usage.recoverable >= 1024 * 1024) ...[
            const SizedBox(height: 6),
            Text(
              'Не входят в лимит: ${fileSize(usage.recoverable)} удалённых '
              'насовсем писем — сервер ещё хранит их для восстановления.',
              style: note,
            ),
          ],
          if (context.select<MailController, bool>((c) => c.sizeColors)) ...[
            const SizedBox(height: 16),
            const _SizeLegend(),
          ],
          const SizedBox(height: 12),
          Text('Папки', style: TextStyle(color: muted)),
        ],
      ),
    );
  }
}

/// What the colours of the rows in the mail list mean.
class _SizeLegend extends StatelessWidget {
  const _SizeLegend();

  @override
  Widget build(BuildContext context) {
    final muted = Brand.muted(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final small = TextStyle(color: muted, fontSize: 12);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Цвет письма в списке — по его размеру',
            style: TextStyle(color: muted, fontSize: 12.5)),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          // Over the list's own background, as the rows show it.
          child: ColoredBox(
            color: Brand.card(context),
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  for (var i = 0; i <= 10; i++) sizeTintAt(i / 10, dark: dark),
                ]),
              ),
              child: const SizedBox(height: 12, width: double.infinity),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Row(children: [
          Expanded(child: Text('100 КБ', style: small)),
          Expanded(
              child: Text('1 МБ', style: small, textAlign: TextAlign.center)),
          Expanded(
              child: Text('10 МБ и больше',
                  style: small, textAlign: TextAlign.end)),
        ]),
      ],
    );
  }
}

/// The limit typed as megabytes, as the web mail shows it («512», «512,00»),
/// in bytes; null when it isn't a size.
int? limitFromMb(String text) {
  final t = text
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'\s|мб|mb'), '')
      .replaceAll(',', '.');
  final mb = double.tryParse(t);
  if (mb == null || !mb.isFinite || mb < 1 || mb > 1024 * 1024) return null;
  return (mb * 1024 * 1024).round();
}

/// Asks for the mailbox limit: pops its bytes, 0 to go without one, or
/// nothing when cancelled.
class _LimitDialog extends StatefulWidget {
  const _LimitDialog({required this.current});
  final int? current;

  @override
  State<_LimitDialog> createState() => _LimitDialogState();
}

class _LimitDialogState extends State<_LimitDialog> {
  late final _text = TextEditingController(
      text: switch (widget.current) {
    null => '',
    final b => (b / (1024 * 1024))
        .toStringAsFixed(2)
        .replaceAll(RegExp(r'[.,]?0+$'), '')
        .replaceAll('.', ','),
  });
  bool _bad = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _save() {
    final bytes = limitFromMb(_text.text);
    if (bytes == null) {
      setState(() => _bad = true);
      return;
    }
    Navigator.pop(context, bytes);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Лимит ящика'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Из веб-почты: Параметры → Общие → Моя учётная запись, '
            '«…когда используемый объём достигнет 512.00 МБ».',
            style: TextStyle(color: Brand.muted(context), fontSize: 13),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _text,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
            ],
            decoration: InputDecoration(
              labelText: 'Лимит',
              hintText: '512',
              suffixText: 'МБ',
              errorText: _bad ? 'Число мегабайт, например 512' : null,
            ),
            onChanged: (_) {
              if (_bad) setState(() => _bad = false);
            },
            onSubmitted: (_) => _save(),
          ),
        ],
      ),
      actions: [
        if (widget.current != null)
          TextButton(
              onPressed: () => Navigator.pop(context, 0),
              child: const Text('Убрать')),
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена')),
        FilledButton(onPressed: _save, child: const Text('Сохранить')),
      ],
    );
  }
}
