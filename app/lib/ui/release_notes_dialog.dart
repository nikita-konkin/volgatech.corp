import 'package:flutter/material.dart';

/// Presents the installed release's short notes in the current dialog theme.
final class ReleaseNotesDialog extends StatelessWidget {
  const ReleaseNotesDialog({
    super.key,
    required this.version,
    required this.lines,
  });

  final String version;
  final List<String> lines;

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text('Что нового в $version'),
        scrollable: true,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 8,
          children: [
            for (final line in lines)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 8,
                children: [const Text('•'), Expanded(child: Text(line))],
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Понятно'),
          ),
        ],
      );
}
