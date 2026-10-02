import 'dart:async';
import 'dart:math';

import 'package:enough_mail/enough_mail.dart';
import 'package:flutter/foundation.dart';

import '../core/cache.dart';
import 'compose.dart';
import 'mail_credentials.dart';
import 'mail_models.dart';
import 'mail_service.dart';

enum MailStatus { starting, signedOut, connecting, ready, offline }

const _inbox = MailFolder(name: 'INBOX', path: 'INBOX', role: FolderRole.inbox);

/// State of the «Почта» screen: sign-in, folders and the message list. The
/// first page of each folder is cached, so the list shows at once and offline.
class MailController extends ChangeNotifier {
  MailController({
    required MailService service,
    required MailCredentialStore store,
    required JsonCache cache,
    this.pinnedFirst = true,
    this.sizeColors = true,
    this.manualQuota,
    this.onInboxUnread,
  })  : _service = service,
        _store = store,
        _cache = cache;

  final MailService _service;
  final MailCredentialStore _store;
  final JsonCache _cache;

  /// Messages pinned in Outlook go above the rest (an option in the menu).
  bool pinnedFirst;

  /// Rows coloured by message size (an option in the menu).
  bool sizeColors;

  /// The mailbox limit as typed in on «Размер ящика», used when the server
  /// doesn't tell it.
  int? manualQuota;

  /// Told the inbox's unread count whenever it is known to change, for the
  /// badge in the app's menu.
  final void Function(int unread)? onInboxUnread;

  MailStatus status = MailStatus.starting;
  MailCredentials? _credentials;
  List<MailFolder> folders = const [_inbox];
  MailFolder folder = _inbox;
  List<MailHeader> headers = const [];
  bool hasMore = false;
  bool loading = false;
  bool loadingMore = false;

  /// Last failure, for the banner / sign-in form; cleared on success.
  Object? error;
  bool _disposed = false;

  String? get login => _credentials?.login;

  MailFolder? folderWith(FolderRole role) =>
      folders.where((f) => f.role == role).firstOrNull;

  /// Where «В архив» files messages; null until the mailbox has one.
  MailFolder? get archiveFolder => folderWith(FolderRole.archive);

  Future<void> start() async {
    _credentials = await _store.read();
    if (_credentials == null) {
      _set(MailStatus.signedOut);
      return;
    }
    await _showCached(folder);
    if ((await _cache.get(_usageKey))?.data case final Map<String, dynamic> u) {
      _serverQuota = u['quota'] as int?;
      usageSummary = MailboxUsage(
          used: u['used'] as int? ?? 0, quota: _serverQuota ?? manualQuota);
    }
    await _connectAndLoad();
  }

  /// Signs in as `MARSTU\login` (see [loginCandidates]) and remembers it.
  Future<bool> signIn(String login, String password) async {
    error = null;
    _set(MailStatus.connecting);
    for (final candidate in loginCandidates(login)) {
      final creds = MailCredentials(candidate, password);
      try {
        await _service.connect(creds);
        await _store.save(creds);
        _credentials = creds;
        await _loadFolders();
        await _load(folder);
        unawaited(_updateUsage());
        return true;
      } on MailAuthException catch (e) {
        error = e;
      } on MailNetworkException catch (e) {
        error = e;
        break;
      }
    }
    _set(MailStatus.signedOut);
    return false;
  }

  Future<void> signOut() async {
    await _service.disconnect();
    await _store.clear();
    await _cache.removePrefix(_cachePrefix);
    onInboxUnread?.call(0);
    _credentials = null;
    headers = const [];
    folders = const [_inbox];
    folder = _inbox;
    usageSummary = null;
    _usageAt = null;
    _serverQuota = null;
    manualQuota = null;
    error = null;
    _set(MailStatus.signedOut);
  }

  Future<void> openFolder(MailFolder f) async {
    if (f == folder) return;
    folder = f;
    headers = const [];
    hasMore = false;
    await _showCached(f);
    await refresh();
  }

  Future<void> setPinnedFirst(bool v) async {
    if (v == pinnedFirst) return;
    pinnedFirst = v;
    notifyListeners();
    await refresh();
  }

  void setSizeColors(bool v) {
    if (v == sizeColors) return;
    sizeColors = v;
    notifyListeners();
  }

  /// When the list was last loaded from the server.
  DateTime? loadedAt;

  /// Back in the app: reload unless the list is fresh anyway.
  Future<void> refreshIfStale(
      {Duration maxAge = const Duration(seconds: 30)}) async {
    final at = loadedAt;
    if (loading || (at != null && DateTime.now().difference(at) < maxAge)) {
      return;
    }
    await refresh();
  }

  Future<void> refresh() async {
    if (_credentials == null) return;
    if (status == MailStatus.offline) {
      await _connectAndLoad();
    } else {
      await _guard(() => _load(folder));
      unawaited(_updateUsage());
    }
  }

  Future<void> loadMore() async {
    if (!hasMore || loadingMore || headers.isEmpty) return;
    loadingMore = true;
    notifyListeners();
    final f = folder;
    await _guard(() async {
      final page = await _service.headers(f,
          before: headers.last.seq, pinnedFirst: pinnedFirst);
      if (f != folder) return;
      // A message pinned or unpinned meanwhile may come round again.
      final have = {for (final h in headers) h.id};
      headers = [
        ...headers,
        for (final h in page.headers)
          if (!have.contains(h.id)) h
      ];
      hasMore = page.hasMore;
    });
    loadingMore = false;
    _notify();
  }

  /// Search in the open folder; throws when the server can't be reached.
  Future<List<MailHeader>> search(String query) {
    final f = folder;
    return _retrying(() => _service.search(f, query.trim()));
  }

  /// The full message; marks it read here and on the server.
  Future<MimeMessage> open(MailHeader h) async {
    final f = folder;
    final msg = await _retrying(() => _service.message(f, h.id));
    if (!h.seen) {
      _countUnread(f, -1);
      _replace(h.copyWith(seen: true));
      unawaited(_guard(() => _service.setSeen(f, h.id, seen: true)));
    }
    return msg;
  }

  Future<void> markUnread(MailHeader h) async {
    if (h.seen) _countUnread(folder, 1);
    _replace(h.copyWith(seen: false));
    await _guard(() => _service.setSeen(folder, h.id, seen: false));
  }

  Future<void> markRead(MailHeader h) async {
    if (!h.seen) _countUnread(folder, -1);
    _replace(h.copyWith(seen: true));
    await _guard(() => _service.setSeen(folder, h.id, seen: true));
  }

  /// Read ↔ unread, without opening it (a swipe to the right).
  Future<void> toggleSeen(MailHeader h) => h.seen ? markUnread(h) : markRead(h);

  Future<void> delete(MailHeader h) async {
    final f = folder;
    headers = [
      for (final x in headers)
        if (x.id != h.id) x
    ];
    _notify();
    await _guard(() => _service.delete(f, h.id));
    unawaited(_saveCache(f));
  }

  /// Files [h] into [to]: off this list at once, then on the server.
  Future<void> move(MailHeader h, MailFolder to) async {
    final f = folder;
    headers = [
      for (final x in headers)
        if (x.id != h.id) x
    ];
    if (!h.seen) {
      _countUnread(f, -1);
      _countUnread(to, 1);
    }
    _notify();
    await _guard(() => _service.move(f, h.id, to));
    unawaited(_saveCache(f));
  }

  /// Files [h] into [archiveFolder] (see [createArchive] for when there is
  /// none yet).
  Future<void> archive(MailHeader h) async {
    final to = archiveFolder;
    if (to == null) throw StateError('no archive folder');
    await move(h, to);
  }

  /// Makes «Архив» at the top of the mailbox, for [archive].
  Future<MailFolder> createArchive() async {
    final made = await _retrying(() => _service.createFolder('Архив'));
    final f = made.role == FolderRole.archive
        ? made
        : MailFolder(
            name: made.name, path: made.path, role: FolderRole.archive);
    folders = _sorted([...folders, f]);
    _notify();
    return f;
  }

  /// Pins [h] above the rest, or puts it back among them by date; on the
  /// list at once, then on the server. Throws, and puts it back as it was,
  /// when the server refuses.
  Future<void> setPinned(MailHeader h, bool pinned) async {
    final f = folder;
    final before = headers;
    headers = _placed(h.copyWith(pinned: pinned));
    _notify();
    try {
      await _guard(
          () => _service.setPinned(f, h.id, pinned: pinned, received: h.date));
    } on Object {
      if (f == folder) headers = before;
      _notify();
      rethrow;
    }
    unawaited(_saveCache(f));
  }

  /// The list with [h] where it now belongs: with the pinned ones first, a
  /// newly pinned one tops them and an unpinned one goes back by date;
  /// otherwise it stays put. A message not on the list stays off it.
  List<MailHeader> _placed(MailHeader h) {
    final i = headers.indexWhere((x) => x.id == h.id);
    if (i < 0) return headers;
    final rest = [...headers]..removeAt(i);
    if (!pinnedFirst) return rest..insert(i, h);
    if (h.pinned) return rest..insert(0, h);
    final epoch = DateTime.fromMillisecondsSinceEpoch(0);
    final at = rest.indexWhere(
        (x) => !x.pinned && (x.date ?? epoch).isBefore(h.date ?? epoch));
    // Older than all loaded: at the end, unless more are still to come.
    if (at < 0 && hasMore) return rest;
    return rest..insert(at < 0 ? rest.length : at, h);
  }

  /// Swipe to delete: off the list at once, off the server after [delay]
  /// unless [undoDelete] brings it back first.
  void deleteSoon(MailHeader h, {Duration delay = const Duration(seconds: 4)}) {
    unawaited(_commitDelete()); // the previous one can't be undone any more
    final i = headers.indexWhere((x) => x.id == h.id);
    if (i < 0) return;
    headers = [...headers]..removeAt(i);
    if (!h.seen) _countUnread(folder, -1);
    _pending = _PendingDelete(h, i, folder, Timer(delay, _commitSoon));
    _notify();
  }

  void undoDelete() {
    final p = _pending;
    if (p == null) return;
    p.timer.cancel();
    _pending = null;
    if (!p.header.seen) _countUnread(p.folder, 1);
    if (p.folder != folder) return;
    headers = [...headers]..insert(min(p.index, headers.length), p.header);
    _notify();
  }

  _PendingDelete? _pending;

  void _commitSoon() => unawaited(_commitDelete());

  Future<void> _commitDelete() async {
    final p = _pending;
    if (p == null) return;
    _pending = null;
    p.timer.cancel();
    await _guard(() => _service.delete(p.folder, p.header.id));
    unawaited(_saveCache(p.folder));
  }

  /// Sends [draft]; throws [EwsException], [MailAuthException] or
  /// [MailNetworkException] for the compose screen to show.
  Future<void> send(ComposeDraft draft) async {
    final creds = _credentials;
    if (creds == null) throw const MailAuthException();
    await _retrying(() => _service.send(buildMime(draft)));
    if (folder.role == FolderRole.sent && !_disposed) unawaited(refresh());
  }

  /// Sends [draft] after [delay] unless [cancelSend] takes it back first.
  /// Completes with null once sent, [sendCancelled], or the error.
  Future<Object?> sendSoon(ComposeDraft draft,
      {Duration delay = const Duration(seconds: 5)}) {
    unawaited(_flushSend()); // one waiting at a time
    final done = Completer<Object?>();
    _outbox = _PendingSend(draft, done, Timer(delay, _flushSoon));
    return done.future;
  }

  /// The message waiting to go, back for editing; null if it has gone.
  ComposeDraft? cancelSend() {
    final p = _outbox;
    if (p == null) return null;
    _outbox = null;
    p.timer.cancel();
    p.done.complete(sendCancelled);
    return p.draft;
  }

  _PendingSend? _outbox;

  void _flushSoon() => unawaited(_flushSend());

  Future<void> _flushSend() async {
    final p = _outbox;
    if (p == null) return;
    _outbox = null;
    p.timer.cancel();
    try {
      await send(p.draft);
      p.done.complete(null);
    } on Object catch (e) {
      p.done.complete(e);
    }
  }

  /// The address book, for recipient suggestions: empty when offline or
  /// nothing matches, never an error.
  Future<List<MailAddress>> searchDirectory(String query) async {
    if (_credentials == null) return const [];
    try {
      return await _retrying(() => _service.searchDirectory(query));
    } on Object {
      return const [];
    }
  }

  /// Space the mailbox takes; throws when the server can't be reached.
  Future<MailboxUsage> usage() async {
    final u = await _retrying(_service.usage);
    _setUsage(u);
    return u;
  }

  /// Space used and the limit (the server's, or else [manualQuota]) — for
  /// the bar above the list. Remembered for the next start; checked every few minutes.
  MailboxUsage? usageSummary;
  DateTime? _usageAt;
  int? _serverQuota;

  /// The limit typed in (null: none); the server's, if it tells, still wins.
  void setManualQuota(int? bytes) {
    manualQuota = bytes;
    if (usageSummary case final u?) {
      usageSummary =
          MailboxUsage(used: u.used, quota: _serverQuota ?? manualQuota);
    }
    _notify();
  }

  static const _usageKey = '${_cachePrefix}usage';

  Future<void> _updateUsage() async {
    final at = _usageAt;
    if (at != null &&
        DateTime.now().difference(at) < const Duration(minutes: 5)) {
      return;
    }
    try {
      await usage();
    } on Object {
      // Offline or busy: the last known size stays.
    }
  }

  void _setUsage(MailboxUsage u) {
    _usageAt = DateTime.now();
    _serverQuota = u.quota;
    usageSummary = MailboxUsage(used: u.used, quota: u.quota ?? manualQuota);
    unawaited(_cache.put(_usageKey, {'used': u.used, 'quota': u.quota}));
    _notify();
  }

  /// Out-of-office replies; both throw when the server can't be reached.
  Future<AutoReply> autoReply() => _retrying(_service.autoReply);
  Future<void> setAutoReply(AutoReply r) =>
      _retrying(() => _service.setAutoReply(r));

  /// The signature set in the web mail, to start the app's from; null when
  /// there is none or the server can't say.
  Future<String?> webSignature() async {
    if (_credentials == null) return null;
    try {
      return await _retrying(_service.webSignature);
    } on Object {
      return null;
    }
  }

  // --- internals ---

  Future<void> _connectAndLoad() async {
    final creds = _credentials;
    if (creds == null) return;
    _set(MailStatus.connecting);
    try {
      await _service.connect(creds);
      await _loadFolders();
      await _load(folder);
      unawaited(_updateUsage());
    } on MailAuthException catch (e) {
      // The password changed: ask again, keeping the login.
      await _store.clear();
      _credentials = null;
      error = e;
      _set(MailStatus.signedOut);
    } on MailNetworkException catch (e) {
      error = e;
      _set(MailStatus.offline);
    }
  }

  Future<void> _loadFolders() async {
    final list = _sorted(await _service.folders());
    folders = list.isEmpty ? const [_inbox] : list;
    folder = folders.firstWhere((f) => f == folder, orElse: () => folders[0]);
    _reportUnread();
  }

  /// Keeps the folders' unread counts (and the menu badge) in step with what
  /// was read, marked or deleted here.
  void _countUnread(MailFolder f, int delta) {
    folders = [
      for (final x in folders)
        x == f ? x.withUnseen(max(0, x.unseen + delta)) : x
    ];
    if (f == folder) folder = folders.firstWhere((x) => x == f);
    _reportUnread();
  }

  void _reportUnread() {
    final inbox = folderWith(FolderRole.inbox);
    if (inbox != null) onInboxUnread?.call(inbox.unseen);
  }

  Future<void> _load(MailFolder f) async {
    loading = true;
    _notify();
    try {
      final page = await _service.headers(f, pinnedFirst: pinnedFirst);
      if (f != folder) return;
      // A swiped message the server still has stays hidden.
      headers = [
        for (final h in page.headers)
          if (h.id != _pending?.header.id) h
      ];
      hasMore = page.hasMore;
      loadedAt = DateTime.now();
      error = null;
      status = MailStatus.ready;
      unawaited(_saveCache(f));
    } finally {
      loading = false;
      _notify();
    }
  }

  /// Runs [job]; on a dropped connection reconnects once and retries.
  Future<T> _retrying<T>(Future<T> Function() job) async {
    try {
      return await job();
    } on MailNetworkException {
      final creds = _credentials;
      if (creds == null) rethrow;
      await _service.connect(creds);
      return job();
    }
  }

  Future<void> _guard(Future<void> Function() job) async {
    try {
      await _retrying(job);
      if (status != MailStatus.ready) _set(MailStatus.ready);
    } on MailAuthException catch (e) {
      error = e;
      await _store.clear();
      _credentials = null;
      _set(MailStatus.signedOut);
    } on MailNetworkException catch (e) {
      error = e;
      _set(MailStatus.offline);
    }
  }

  /// System folders first, then by name.
  static List<MailFolder> _sorted(List<MailFolder> list) => list
    ..sort((a, b) {
      final r = a.role.index.compareTo(b.role.index);
      return r != 0 ? r : a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

  void _replace(MailHeader h) {
    headers = [for (final x in headers) x.id == h.id ? h : x];
    _notify();
  }

  static const _cachePrefix = 'mail_';

  /// System folders by role: the inbox's server id is unknown offline.
  String _cacheKey(MailFolder f) =>
      _cachePrefix + (f.role == FolderRole.other ? f.path : f.role.name);

  Future<void> _showCached(MailFolder f) async {
    final entry = await _cache.get(_cacheKey(f));
    final data = entry?.data;
    if (data is! List || f != folder) return;
    headers = [
      for (final j in data)
        if (j is Map) MailHeader.fromJson(Map<String, dynamic>.from(j)),
    ];
    _notify();
  }

  Future<void> _saveCache(MailFolder f) async {
    if (f != folder) return;
    await _cache
        .put(_cacheKey(f), [for (final h in headers.take(40)) h.toJson()]);
  }

  void _set(MailStatus s) {
    status = s;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    // A swiped message or one waiting to be sent goes before hanging up.
    unawaited(Future.wait([_commitDelete(), _flushSend()])
        .whenComplete(_service.disconnect));
    super.dispose();
  }
}

/// What [MailController.sendSoon] completes with when it was taken back.
const Object sendCancelled = _SendCancelled();

class _SendCancelled {
  const _SendCancelled();
}

class _PendingSend {
  _PendingSend(this.draft, this.done, this.timer);
  final ComposeDraft draft;
  final Completer<Object?> done;
  final Timer timer;
}

class _PendingDelete {
  _PendingDelete(this.header, this.index, this.folder, this.timer);
  final MailHeader header;
  final int index;
  final MailFolder folder;
  final Timer timer;
}
