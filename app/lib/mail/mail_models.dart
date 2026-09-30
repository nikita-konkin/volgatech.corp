enum FolderRole { inbox, sent, drafts, trash, junk, other }

class MailFolder {
  const MailFolder({
    required this.name,
    required this.path,
    this.role = FolderRole.other,
    this.unseen = 0,
  });

  final String name;
  final String path;
  final FolderRole role;
  final int unseen;

  /// Russian names for the system folders; others keep the server's name.
  String get title => switch (role) {
        FolderRole.inbox => 'Входящие',
        FolderRole.sent => 'Отправленные',
        FolderRole.drafts => 'Черновики',
        FolderRole.trash => 'Удалённые',
        FolderRole.junk => 'Нежелательная почта',
        FolderRole.other => name,
      };

  MailFolder withUnseen(int n) =>
      MailFolder(name: name, path: path, role: role, unseen: n);

  @override
  bool operator ==(Object other) => other is MailFolder && other.path == path;

  @override
  int get hashCode => path.hashCode;
}

/// Role of a folder from its IMAP special-use flag or, as Exchange doesn't
/// always send those, from its (Russian or English) name.
FolderRole folderRole({
  required String path,
  required String name,
  bool inbox = false,
  bool sent = false,
  bool drafts = false,
  bool trash = false,
  bool junk = false,
}) {
  if (inbox || path.toUpperCase() == 'INBOX') return FolderRole.inbox;
  if (sent) return FolderRole.sent;
  if (drafts) return FolderRole.drafts;
  if (trash) return FolderRole.trash;
  if (junk) return FolderRole.junk;
  final n = name.toLowerCase().replaceAll('ё', 'е');
  if (n == 'отправленные' || n == 'sent items' || n == 'sent') {
    return FolderRole.sent;
  }
  if (n == 'черновики' || n == 'drafts') return FolderRole.drafts;
  if (n == 'удаленные' || n == 'deleted items' || n == 'trash') {
    return FolderRole.trash;
  }
  if (n == 'нежелательная почта' || n == 'junk email' || n == 'junk') {
    return FolderRole.junk;
  }
  return FolderRole.other;
}

/// One line of the message list.
class MailHeader {
  const MailHeader({
    required this.id,
    required this.seq,
    required this.fromName,
    required this.fromEmail,
    required this.subject,
    required this.date,
    this.seen = false,
    this.flagged = false,
    this.answered = false,
    this.hasAttachments = false,
    this.pinned = false,
    this.size,
  });

  /// Exchange's item id.
  final String id;

  /// Position in the folder, newest first; the next page starts after it.
  final int seq;
  final String fromName;
  final String fromEmail;
  final String subject;
  final DateTime? date;
  final bool seen;
  final bool flagged;
  final bool answered;
  final bool hasAttachments;

  /// Pinned in Outlook on the web: kept above everything else.
  final bool pinned;

  /// The whole message with attachments, in bytes, as Exchange counts it.
  final int? size;

  String get from => fromName.isNotEmpty ? fromName : fromEmail;

  MailHeader copyWith({bool? seen, bool? answered}) => MailHeader(
        id: id,
        seq: seq,
        fromName: fromName,
        fromEmail: fromEmail,
        subject: subject,
        date: date,
        seen: seen ?? this.seen,
        flagged: flagged,
        answered: answered ?? this.answered,
        hasAttachments: hasAttachments,
        pinned: pinned,
        size: size,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'seq': seq,
        'fromName': fromName,
        'fromEmail': fromEmail,
        'subject': subject,
        'date': date?.toIso8601String(),
        'seen': seen,
        'flagged': flagged,
        'answered': answered,
        'att': hasAttachments,
        'pin': pinned,
        'size': size,
      };

  factory MailHeader.fromJson(Map<String, dynamic> j) => MailHeader(
        id: j['id'] as String? ?? '',
        seq: j['seq'] as int? ?? 0,
        fromName: j['fromName'] as String? ?? '',
        fromEmail: j['fromEmail'] as String? ?? '',
        subject: j['subject'] as String? ?? '',
        date: DateTime.tryParse(j['date'] as String? ?? ''),
        seen: j['seen'] as bool? ?? false,
        flagged: j['flagged'] as bool? ?? false,
        answered: j['answered'] as bool? ?? false,
        hasAttachments: j['att'] as bool? ?? false,
        pinned: j['pin'] as bool? ?? false,
        size: j['size'] as int?,
      );
}

/// A page of the list, newest first.
class MailPage {
  const MailPage(this.headers, {required this.hasMore});
  final List<MailHeader> headers;
  final bool hasMore;
}

class MailAuthException implements Exception {
  const MailAuthException([this.serverReply]);

  /// What Exchange answered, when it said anything.
  final String? serverReply;

  @override
  String toString() => 'Неверный логин или пароль почты';
}

class MailNetworkException implements Exception {
  const MailNetworkException(this.cause);
  final Object cause;
  @override
  String toString() => 'Нет связи с почтовым сервером';
}

/// Out-of-office replies («Автоответ»), as Outlook sets them.
enum AutoReplyState { off, on, scheduled }

class AutoReply {
  const AutoReply({
    this.state = AutoReplyState.off,
    this.start,
    this.end,
    this.message = '',
    this.external = true,
  });

  final AutoReplyState state;

  /// The period, for [AutoReplyState.scheduled].
  final DateTime? start;
  final DateTime? end;

  /// Plain text, sent to colleagues and, with [external], to the rest.
  final String message;
  final bool external;
}

/// How much of the mailbox is taken, and by which folders.
class MailboxUsage {
  const MailboxUsage(
      {required this.used,
      this.quota,
      this.folders = const [],
      this.recoverable = 0});

  /// Bytes, all folders together.
  final int used;

  /// Bytes deleted for good that the server still keeps for recovery; not
  /// in [used], and not counted against [quota].
  final int recoverable;

  /// The size at which Exchange stops sending, when the server tells.
  final int? quota;

  /// Biggest first.
  final List<FolderUsage> folders;
}

class FolderUsage {
  const FolderUsage(this.folder, {required this.size, required this.count});
  final MailFolder folder;
  final int size;
  final int count;
}
