import 'dart:async';

import 'package:flutter/material.dart';

import '../core/prefs.dart';

/// Offers to load study forms and remembers when the offer is dismissed.
final class StudyFormsHint extends StatefulWidget {
  const StudyFormsHint({
    super.key,
    required this.prefs,
    required this.hasForms,
    required this.hasLessons,
    required this.onOpen,
  });

  final Prefs prefs;
  final bool hasForms;
  final bool hasLessons;
  final VoidCallback onOpen;

  @override
  State<StudyFormsHint> createState() => _StudyFormsHintState();
}

/// Hides the offer immediately when it is dismissed.
final class _StudyFormsHintState extends State<StudyFormsHint> {
  @override
  Widget build(BuildContext context) {
    if (!widget.hasLessons ||
        widget.hasForms ||
        widget.prefs.studyFormsHintDismissed) {
      return const SizedBox.shrink();
    }
    return Row(
      children: [
        Expanded(
          child: TextButton(
            onPressed: widget.onOpen,
            child: const Text(
              'Показать форму обучения групп (оз, з, о)? Войти на портал ›',
              textAlign: TextAlign.start,
            ),
          ),
        ),
        IconButton(
          tooltip: 'Не показывать',
          onPressed: () {
            setState(() => unawaited(widget.prefs.dismissStudyFormsHint()));
          },
          icon: const Icon(Icons.close, size: 18),
        ),
      ],
    );
  }
}
