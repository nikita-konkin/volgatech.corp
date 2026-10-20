import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/prefs.dart';
import '../../theme.dart';
import '../../ui/hourly_setup_pages.dart' show TextPrompt;

/// Phrases to put into a message with a tap; the list kept in [Prefs].
/// Pops with the phrase chosen.
class TemplatesSheet extends StatefulWidget {
  const TemplatesSheet({super.key});

  @override
  State<TemplatesSheet> createState() => _TemplatesSheetState();
}

class _TemplatesSheetState extends State<TemplatesSheet> {
  late final Prefs _prefs = context.read<Prefs>();
  late List<String> _list = [..._prefs.mailTemplates];
  bool _editing = false;

  Future<void> _save(List<String> list) async {
    setState(() => _list = list);
    await _prefs.setMailTemplates(list);
  }

  Future<void> _edit([int? at]) async {
    final r = await showDialog<(String, String)>(
      context: context,
      builder: (_) => TextPrompt(
        title: at == null ? 'Новый шаблон' : 'Шаблон',
        initial: at == null ? '' : _list[at],
        minLines: 2,
        maxLines: 6,
      ),
    );
    final text = r?.$2.trim() ?? '';
    if (r == null || text.isEmpty) return;
    await _save([
      for (var i = 0; i < _list.length; i++) i == at ? text : _list[i],
      if (at == null) text,
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final muted = Brand.muted(context);
    return SafeArea(
      child: ConstrainedBox(
        constraints:
            BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.7),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 8, 0),
            child: Row(children: [
              const Expanded(
                child: Text('Шаблоны',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
              TextButton(
                onPressed: () => setState(() => _editing = !_editing),
                child: Text(_editing ? 'Готово' : 'Изменить'),
              ),
            ]),
          ),
          Flexible(
            child: ListView(shrinkWrap: true, children: [
              if (_list.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                      'Шаблонов нет — добавьте фразы, которые часто '
                      'пишете.',
                      style: TextStyle(color: muted)),
                ),
              for (var i = 0; i < _list.length; i++)
                ListTile(
                  title: Text(_list[i],
                      maxLines: 3, overflow: TextOverflow.ellipsis),
                  trailing: _editing
                      ? IconButton(
                          tooltip: 'Удалить шаблон',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () =>
                              unawaited(_save([..._list]..removeAt(i))),
                        )
                      : null,
                  onTap: _editing
                      ? () => unawaited(_edit(i))
                      : () => Navigator.pop(context, _list[i]),
                ),
              if (_editing)
                ListTile(
                  leading: const Icon(Icons.add),
                  title: const Text('Добавить шаблон'),
                  onTap: () => unawaited(_edit()),
                ),
            ]),
          ),
        ]),
      ),
    );
  }
}
