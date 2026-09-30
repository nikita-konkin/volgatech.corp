import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../theme.dart';
import '../mail_controller.dart';
import '../mail_models.dart';
import 'message_tile.dart';

/// Search in the open folder by sender, subject or text, as in Outlook.
class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  static const _minLength = 2;

  final _query = TextEditingController();
  Timer? _debounce;
  String _asked = '';
  bool _busy = false;
  Object? _error;
  List<MailHeader>? _found;

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  void _changed(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), () => _run(text));
  }

  Future<void> _run(String text) async {
    _debounce?.cancel();
    final q = text.trim();
    if (q == _asked) return;
    _asked = q;
    if (q.length < _minLength) {
      setState(() => _found = null);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final found = await context.read<MailController>().search(q);
      if (!mounted || q != _asked) return; // typing went on meanwhile
      setState(() => _found = found);
    } on Object catch (e) {
      if (mounted && q == _asked) setState(() => _error = e);
    } finally {
      if (mounted && q == _asked) setState(() => _busy = false);
    }
  }

  /// Opened from the results: read now.
  void _opened(MailHeader h) => setState(() => _found = [
        for (final x in _found ?? const <MailHeader>[])
          x.id == h.id ? x.copyWith(seen: true) : x
      ]);

  @override
  Widget build(BuildContext context) {
    final muted = Brand.muted(context);
    final folder = context.read<MailController>().folder;
    Widget note(String text) => Padding(
          padding: const EdgeInsets.fromLTRB(24, 48, 24, 0),
          child: Text(text,
              textAlign: TextAlign.center, style: TextStyle(color: muted)),
        );
    final found = _found;
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _query,
          autofocus: true,
          textInputAction: TextInputAction.search,
          cursorColor: Colors.white,
          style: const TextStyle(color: Colors.white, fontSize: 18),
          decoration: InputDecoration(
            hintText: 'Поиск: ${folder.title}',
            hintStyle: const TextStyle(color: Colors.white70),
            filled: false,
            border: InputBorder.none,
          ),
          onChanged: _changed,
          onSubmitted: (t) => unawaited(_run(t)),
        ),
        bottom: _busy
            ? const PreferredSize(
                preferredSize: Size.fromHeight(3),
                child: LinearProgressIndicator(minHeight: 3),
              )
            : null,
      ),
      body: ColoredBox(
        color: Brand.card(context),
        child: _error != null
            ? note('Не удалось выполнить поиск — проверьте связь')
            : found == null
                ? note('Отправитель, тема или слова из письма')
                : found.isEmpty && !_busy
                    ? note('Ничего не найдено')
                    : ListView.separated(
                        itemCount: found.length,
                        separatorBuilder: (_, __) => Divider(
                            height: 1,
                            thickness: 0.5,
                            indent: 28,
                            color: muted.withValues(alpha: 0.3)),
                        itemBuilder: (_, i) => MessageTile(found[i],
                            onOpened: () => _opened(found[i])),
                      ),
      ),
    );
  }
}
