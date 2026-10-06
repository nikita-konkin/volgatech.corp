import 'dart:typed_data';

import 'package:enough_mail/enough_mail.dart';

import 'mail_credentials.dart';
import 'mail_models.dart';

/// The mailbox as the «Почта» screen needs it. An interface so the controller
/// can be tested without a server; the real one is `EwsMailService`.
abstract class MailService {
  /// Signs in; throws [MailAuthException] or [MailNetworkException].
  Future<void> connect(MailCredentials credentials);

  /// Mail folders; the one Outlook on the web archives to (or else one named
  /// «Архив») has [FolderRole.archive].
  Future<List<MailFolder>> folders();

  /// Unread messages in «Входящие», for the badge in the menu.
  Future<int> inboxUnread();

  /// The newest [count] messages of «Входящие» by arrival (pins aside), in
  /// one request: the background check for new mail.
  Future<List<MailHeader>> latestInbox({int count = 20});

  /// Newest [count] messages of [folder] after sequence number [before];
  /// with [pinnedFirst], the ones pinned in Outlook come before the rest.
  Future<MailPage> headers(MailFolder folder,
      {int? before, int count = 40, bool pinnedFirst = true});
  Future<MimeMessage> message(MailFolder folder, String id);

  /// Messages in [folder] matching [query] (sender, subject or text),
  /// newest first.
  Future<List<MailHeader>> search(MailFolder folder, String query,
      {int count = 50});
  Future<void> setSeen(MailFolder folder, String id, {required bool seen});

  /// Moves message [id] from [folder] to [to].
  Future<void> move(MailFolder folder, String id, MailFolder to);

  /// Moves to the trash, or deletes for good when already there.
  Future<void> delete(MailFolder folder, String id);

  /// Pins message [id] above the rest of [folder], the way Outlook on the
  /// web does, or unpins it back to its place by [received].
  Future<void> setPinned(MailFolder folder, String id,
      {required bool pinned, DateTime? received});

  /// Makes a mail folder [name] at the top of the mailbox.
  Future<MailFolder> createFolder(String name);

  /// Sends an RFC 822 message and keeps a copy in «Отправленные».
  Future<void> send(Uint8List mime);

  /// People and lists in the organisation's address book whose name or
  /// address starts with [query]; empty when nothing matches.
  Future<List<MailAddress>> searchDirectory(String query);

  /// The signature set in Outlook on the web, as text; null if none.
  Future<String?> webSignature();

  /// Space the mailbox takes, per folder.
  Future<MailboxUsage> usage();

  /// Out-of-office replies: how they are set, and setting them.
  Future<AutoReply> autoReply();
  Future<void> setAutoReply(AutoReply reply);
  Future<void> disconnect();
}
