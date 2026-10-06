import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/cache.dart';
import '../../core/prefs.dart';
import '../../theme.dart';
import '../../ui/web_view_page.dart';
import '../attachments.dart';
import '../compose.dart';
import '../ews_mail_service.dart';
import '../mail_alerts.dart';
import '../mail_badge.dart';
import '../mail_config.dart';
import '../mail_controller.dart';
import '../mail_credentials.dart';
import '../mail_models.dart';
import 'auto_reply_page.dart';
import 'compose_page.dart';
import 'mailbox_size_page.dart';
import 'message_tile.dart';
import 'search_page.dart';
import 'signature_page.dart';

export 'message_tile.dart' show mailDate;

/// «Почта»: the built-in client (builds with `--dart-define=MAIL=true`).
class MailPage extends StatelessWidget {
  const MailPage({super.key, this.create});

  /// For tests; defaults to EWS on mail.volgatech.net.
  final MailController Function(BuildContext)? create;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<MailController>(
      create: (ctx) {
        final c = create?.call(ctx) ??
            MailController(
              service: EwsMailService(),
              store: MailCredentialStore(),
              cache: ctx.read<JsonCache>(),
              pinnedFirst: ctx.read<Prefs>().mailPinnedFirst,
              sizeColors: ctx.read<Prefs>().mailSizeColors,
              manualQuota: ctx.read<Prefs>().mailQuota,
              onInboxUnread: ctx.read<MailBadge>().set,
              onInboxShown: MailAlerts.supported
                  ? (h) => unawaited(ctx.read<MailAlerts>().seen(h))
                  : null,
            );
        unawaited(c.start());
        return c;
      },
      child: const _MailView(),
    );
  }
}

class _MailView extends StatefulWidget {
  const _MailView();

  @override
  State<_MailView> createState() => _MailViewState();
}

class _MailViewState extends State<_MailView> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    // Back from another app: new mail may have come.
    _lifecycle = AppLifecycleListener(
        onResume: () =>
            unawaited(context.read<MailController>().refreshIfStale()));
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<MailController>();
    final signedOut = c.status == MailStatus.signedOut;
    return Scaffold(
      appBar: AppBar(
        title: signedOut || c.status == MailStatus.starting
            ? const Text('Почта')
            : _FolderTitle(c),
        actions: [
          if (c.usageSummary case final u?
              when c.status == MailStatus.ready ||
                  c.status == MailStatus.offline)
            UsageBar(
              usage: u,
              onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => ChangeNotifierProvider.value(
                    value: c, child: const MailboxSizePage()),
              )),
            ),
          if (c.status == MailStatus.ready || c.status == MailStatus.offline)
            IconButton(
              tooltip: 'Поиск',
              icon: const Icon(Icons.search),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ChangeNotifierProvider.value(
                      value: c, child: const SearchPage()),
                ),
              ),
            ),
          _Menu(signedIn: !signedOut),
        ],
        bottom: c.status == MailStatus.connecting || c.loading
            ? const PreferredSize(
                preferredSize: Size.fromHeight(3),
                child: LinearProgressIndicator(minHeight: 3),
              )
            : null,
      ),
      floatingActionButton:
          c.status == MailStatus.ready || c.status == MailStatus.offline
              ? FloatingActionButton(
                  tooltip: 'Написать',
                  backgroundColor: Brand.coral,
                  foregroundColor: Colors.white,
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => ChangeNotifierProvider.value(
                        value: c,
                        child: ComposePage(
                            draft: switch (context.read<Prefs>().mailDraft) {
                          final Map<String, dynamic> kept =>
                            ComposeDraft.fromJson(kept),
                          _ => ComposeDraft(),
                        }),
                      ),
                    ),
                  ),
                  child: const Icon(Icons.edit),
                )
              : null,
      body: switch (c.status) {
        MailStatus.starting => const Center(child: CircularProgressIndicator()),
        MailStatus.signedOut => const _SignInForm(),
        _ => const _MessageList(),
      },
    );
  }
}

class _FolderTitle extends StatelessWidget {
  const _FolderTitle(this.c);
  final MailController c;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => unawaited(_pick(context)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
              child: Text(c.folder.title, overflow: TextOverflow.ellipsis)),
          const Icon(Icons.arrow_drop_down),
        ],
      ),
    );
  }

  Future<void> _pick(BuildContext context) async {
    final picked = await showModalBottomSheet<MailFolder>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final f in c.folders)
              ListTile(
                leading: Icon(folderIcon(f.role)),
                title: Text(f.title),
                trailing: f.unseen > 0 ? Text('${f.unseen}') : null,
                selected: f == c.folder,
                onTap: () => Navigator.pop(context, f),
              ),
          ],
        ),
      ),
    );
    if (picked != null) await c.openFolder(picked);
  }
}

class _Menu extends StatelessWidget {
  const _Menu({required this.signedIn});
  final bool signedIn;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: (v) async {
        final c = context.read<MailController>();
        final prefs = context.read<Prefs>();
        if (v == 'web') {
          await Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) =>
                const WebViewScreen(title: 'Почта', url: kWebMailUrl),
          ));
        } else if (v == 'signature') {
          await Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => ChangeNotifierProvider.value(
                value: c, child: const SignaturePage()),
          ));
        } else if (v == 'autoreply') {
          await Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => ChangeNotifierProvider.value(
                value: c, child: const AutoReplyPage()),
          ));
        } else if (v == 'size') {
          await Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => ChangeNotifierProvider.value(
                value: c, child: const MailboxSizePage()),
          ));
        } else if (v == 'pins') {
          final on = !c.pinnedFirst;
          unawaited(prefs.setMailPinnedFirst(on));
          await c.setPinnedFirst(on);
        } else if (v == 'sizes') {
          final on = !c.sizeColors;
          unawaited(prefs.setMailSizeColors(on));
          c.setSizeColors(on);
        } else if (v == 'signout' && await _confirmSignOut(context)) {
          await c.signOut();
          await prefs.setMailQuota(null);
          await clearAttachmentFiles();
        }
      },
      itemBuilder: (_) => [
        const PopupMenuItem(value: 'web', child: Text('Веб-версия')),
        if (signedIn)
          const PopupMenuItem(value: 'signature', child: Text('Подпись')),
        if (signedIn)
          const PopupMenuItem(value: 'autoreply', child: Text('Автоответ')),
        if (signedIn)
          const PopupMenuItem(value: 'size', child: Text('Размер ящика')),
        if (signedIn)
          CheckedPopupMenuItem(
            value: 'pins',
            checked: context.read<MailController>().pinnedFirst,
            child: const Text('Закреплённые сверху'),
          ),
        if (signedIn)
          CheckedPopupMenuItem(
            value: 'sizes',
            checked: context.read<MailController>().sizeColors,
            child: const Text('Цвет по размеру'),
          ),
        if (signedIn)
          const PopupMenuItem(value: 'signout', child: Text('Выйти из почты')),
      ],
    );
  }

  Future<bool> _confirmSignOut(BuildContext context) async =>
      await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Выйти из почты?'),
          content: const Text(
              'Пароль почты будет удалён с телефона, сохранённые письма — тоже.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Отмена')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Выйти')),
          ],
        ),
      ) ??
      false;
}

class _SignInForm extends StatefulWidget {
  const _SignInForm();

  @override
  State<_SignInForm> createState() => _SignInFormState();
}

class _SignInFormState extends State<_SignInForm> {
  late final _login = TextEditingController(
      text: context.read<MailController>().login?.split('@').first ??
          context.read<Prefs>().rememberedLogin ??
          '');
  final _password = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _login.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_login.text.trim().isEmpty || _password.text.isEmpty) return;
    FocusScope.of(context).unfocus();
    final ok = await context
        .read<MailController>()
        .signIn(_login.text, _password.text);
    if (ok) _password.clear();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<MailController>();
    final busy = c.status == MailStatus.connecting;
    final muted = Brand.muted(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
      children: [
        const Icon(Icons.mail_outline, size: 56, color: Brand.coral),
        const SizedBox(height: 12),
        const Text('Вход в почту',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Text(kMailHost,
            textAlign: TextAlign.center, style: TextStyle(color: muted)),
        const SizedBox(height: 24),
        TextField(
          controller: _login,
          enabled: !busy,
          autocorrect: false,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'Логин'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _password,
          enabled: !busy,
          obscureText: _obscure,
          onSubmitted: (_) => unawaited(_submit()),
          decoration: InputDecoration(
            labelText: 'Пароль',
            suffixIcon: IconButton(
              icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
          ),
        ),
        if (c.error != null) ...[
          const SizedBox(height: 12),
          Text('${c.error}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Brand.coral)),
          if (c.error case MailAuthException(:final serverReply?))
            Text('Сервер: $serverReply',
                textAlign: TextAlign.center,
                style: TextStyle(color: muted, fontSize: 12.5)),
        ],
        const SizedBox(height: 20),
        FilledButton(
          onPressed: busy ? null : () => unawaited(_submit()),
          child: busy
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Войти'),
        ),
        const SizedBox(height: 20),
        Text(
          'Пароль хранится только на этом телефоне, в защищённом хранилище, '
          'и нужен для связи с почтовым сервером. Включите блокировку '
          'приложения в настройках, чтобы защитить почту.',
          textAlign: TextAlign.center,
          style: TextStyle(color: muted, fontSize: 12.5),
        ),
      ],
    );
  }
}

/// The folder's messages, pinned ones first under a header that folds.
class _MessageList extends StatefulWidget {
  const _MessageList();

  @override
  State<_MessageList> createState() => _MessageListState();
}

class _MessageListState extends State<_MessageList> {
  late bool _folded = context.read<Prefs>().mailPinsFolded;

  void _toggle() {
    setState(() => _folded = !_folded);
    unawaited(context.read<Prefs>().setMailPinsFolded(_folded));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<MailController>();
    // With the option off, pinned ones stay in date order, just tinted.
    final grouped = c.pinnedFirst;
    final pinned = [
      for (final h in c.headers)
        if (grouped && h.pinned) h
    ];
    final rest = [
      for (final h in c.headers)
        if (!grouped || !h.pinned) h
    ];
    // The rest under OWA's headings: «Сегодня», «Вчера», … then months.
    final now = DateTime.now();
    String? heading;
    final rows = <Object>[
      if (pinned.isNotEmpty) _Section.pinned,
      if (!_folded) ...pinned,
      for (final h in rest) ...[
        if (dateGroup(h.date, now) case final g when g != heading) heading = g,
        h,
      ],
    ];
    return Column(
      children: [
        if (c.status == MailStatus.offline) const _OfflineStrip(),
        Expanded(
          child: ColoredBox(
            color: Brand.card(context),
            child: RefreshIndicator(
              onRefresh: c.refresh,
              child: c.headers.isEmpty && !c.loading
                  ? ListView(children: [
                      const SizedBox(height: 120),
                      Center(
                        child: Text('Писем нет',
                            style: TextStyle(color: Brand.muted(context))),
                      ),
                    ])
                  : ListView.separated(
                      itemCount: rows.length + (c.hasMore ? 1 : 0),
                      separatorBuilder: (_, i) => rows[i] is! MailHeader ||
                              (i + 1 < rows.length &&
                                  rows[i + 1] is! MailHeader)
                          ? const SizedBox.shrink()
                          : Divider(
                              height: 1,
                              thickness: 0.5,
                              indent: 28,
                              color:
                                  Brand.muted(context).withValues(alpha: 0.3)),
                      itemBuilder: (context, i) {
                        if (i == rows.length) {
                          unawaited(c.loadMore());
                          return const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                        return switch (rows[i]) {
                          _Section.pinned => _PinnedHeader(
                              count: pinned.length,
                              folded: _folded,
                              onTap: _toggle),
                          final String g => _Heading(g),
                          final h => SwipeableMessage(h as MailHeader),
                        };
                      },
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

enum _Section { pinned }

class _Heading extends StatelessWidget {
  const _Heading(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(28, 14, 16, 6),
        child: Text(text,
            style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontSize: 13.5,
                fontWeight: FontWeight.w600)),
      );
}

class _PinnedHeader extends StatelessWidget {
  const _PinnedHeader(
      {required this.count, required this.folded, required this.onTap});
  final int count;
  final bool folded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Material(
      color: pinnedTint(context),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 16, 8),
          child: Row(children: [
            SizedBox(
                width: 16,
                child: Icon(Icons.push_pin, size: 14, color: accent)),
            const SizedBox(width: 4),
            Expanded(
              child: Text('Закреплённые · $count',
                  style: TextStyle(
                      color: accent,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600)),
            ),
            Icon(folded ? Icons.expand_more : Icons.expand_less,
                size: 20, color: accent),
          ]),
        ),
      ),
    );
  }
}

class _OfflineStrip extends StatelessWidget {
  const _OfflineStrip();

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        color: const Color(0xFFFFF3CD),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: const Row(children: [
          Icon(Icons.cloud_off, size: 18, color: Color(0xFF8A6D3B)),
          SizedBox(width: 8),
          Expanded(
            child: Text('Нет связи с почтой — показаны сохранённые письма',
                style: TextStyle(color: Color(0xFF8A6D3B), fontSize: 13)),
          ),
        ]),
      );
}
