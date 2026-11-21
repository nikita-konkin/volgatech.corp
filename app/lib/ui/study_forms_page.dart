import 'dart:async';

import 'package:flutter/material.dart';

import '../data/portal_timetable_store.dart';
import '../data/portal_workload_client.dart';
import 'portal_sign_in.dart';

enum _LoadState { busy, signIn, failed }

/// Loads study forms for one app profile using the portal session.
final class StudyFormsPage extends StatefulWidget {
  const StudyFormsPage({
    super.key,
    required this.personId,
    required this.store,
    required this.readTimetable,
    required this.signInView,
  });

  factory StudyFormsPage.portal({
    required int personId,
    required PortalTimetableStore store,
  }) {
    final portal = PortalWorkloadClient(
      onSignedIn: () {},
      onAuthRequest: (request) => request.onCancel(),
      onLoginFailure: (_) {},
    );
    return StudyFormsPage(
      personId: personId,
      store: store,
      readTimetable: portal.readTimetable,
      signInView: (onSignedIn, onUnexpected) => PortalSignIn(
        signIn: portal.signIn,
        onSignedIn: onSignedIn,
        onUnexpected: onUnexpected,
      ),
    );
  }

  final int personId;
  final PortalTimetableStore store;
  final Future<List<Object?>> Function() readTimetable;
  final Widget Function(VoidCallback onSignedIn, VoidCallback onUnexpected)
      signInView;

  @override
  State<StudyFormsPage> createState() => _StudyFormsPageState();
}

/// Tracks the read, authentication prompt, and explicit retry.
final class _StudyFormsPageState extends State<StudyFormsPage> {
  var _state = _LoadState.busy;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() => _state = _LoadState.busy);
    var signInRequired = false;
    final saved = await widget.store.refresh(widget.personId, () async {
      try {
        final rows = await widget.readTimetable();
        if (!mounted || ModalRoute.of(context)?.isCurrent != true) {
          throw StateError('Study forms page closed');
        }
        return rows;
      } on PortalWorkloadFailure catch (error) {
        signInRequired = error.signIn;
        rethrow;
      }
    });
    if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;
    if (saved && widget.store.read(widget.personId).hasForms) {
      Navigator.pop(context, true);
      return;
    }
    setState(
        () => _state = signInRequired ? _LoadState.signIn : _LoadState.failed);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Форма обучения групп')),
        body: switch (_state) {
          _LoadState.busy => const Center(child: CircularProgressIndicator()),
          _LoadState.signIn => widget.signInView(
              _load, () => setState(() => _state = _LoadState.failed)),
          _LoadState.failed => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Не удалось загрузить форму обучения групп.',
                        textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    FilledButton(
                        onPressed: _load, child: const Text('Повторить')),
                  ],
                ),
              ),
            ),
        },
      );
}
