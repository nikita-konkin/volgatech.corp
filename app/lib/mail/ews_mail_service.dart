import 'dart:convert';
import 'dart:typed_data';

import 'package:enough_mail/enough_mail.dart';
import 'package:xml/xml.dart';

import 'compose.dart' show htmlToText, isMine;
import 'ews_client.dart';
import 'mail_credentials.dart';
import 'mail_models.dart';
import 'mail_service.dart';

/// [MailService] over Exchange Web Services.
class EwsMailService implements MailService {
  EwsMailService({Uri? endpoint}) : _endpoint = endpoint;

  final Uri? _endpoint;
  EwsSession? _session;
  Map<String, FolderRole> _roles = const {};

  /// Schema versions that may know Outlook's pins, still to try, and the one
  /// that worked. A server that rejects them all gets the plain request.
  final _pinVersions = ['Exchange2016', 'V2015_10_05'];
  String? _pinVersion;

  /// Pinned message ids per folder, learnt with each folder's first page.
  final _pinnedIds = <String, Set<String>>{};

  EwsSession get _s =>
      _session ?? (throw const MailNetworkException('not connected'));

  @override
  Future<void> connect(MailCredentials credentials) async {
    await disconnect();
    final session = EwsSession(credentials, endpoint: _endpoint);
    try {
      // Signs in and learns which folders are Входящие, Отправленные, …
      _roles = parseRoles(await session.call(getSystemFoldersSoap));
    } on Object {
      session.close();
      rethrow;
    }
    _session = session;
  }

  @override
  Future<List<MailFolder>> folders() async =>
      parseFolders(await _s.call(findFoldersSoap), _roles);

  @override
  Future<int> inboxUnread() async {
    final doc = await _s.call(inboxUnreadSoap);
    return int.tryParse(_t(doc, 'UnreadCount').firstOrNull?.innerText ?? '') ??
        0;
  }

  @override
  Future<MailPage> headers(MailFolder folder,
      {int? before, int count = 40, bool pinnedFirst = true}) async {
    final offset = before == null ? 0 : before + 1;
    final doc = await _findItems(folder.path, offset, count, pinnedFirst);
    if (offset == 0) _pinnedIds[folder.path] = await _findPinned(folder.path);
    final toShown =
        folder.role == FolderRole.sent || folder.role == FolderRole.drafts;
    return parseItems(doc,
        offset: offset,
        recipientsAsSender: toShown,
        pinnedIds: _pinnedIds[folder.path] ?? const {});
  }

  /// Exchange sorts by the pin time but leaves it out of the list, so the
  /// pinned ones are asked for separately; none if the server can't say.
  Future<Set<String>> _findPinned(String folderId) async {
    final v = _pinVersion;
    if (v == null) return const {};
    try {
      final doc = await _s.call(findPinnedSoap(folderId), version: v);
      return {
        for (final e in _t(doc, 'ItemId'))
          if (e.getAttribute('Id') case final id?) id,
      };
    } on EwsException {
      return const {};
    }
  }

  /// With which messages are pinned, when the server can say; pinned first
  /// if [pinnedFirst], like Outlook on the web.
  Future<XmlDocument> _findItems(
      String folderId, int offset, int count, bool pinnedFirst) async {
    final pinned = findItemsSoap(folderId, offset, count,
        pins: true, pinnedFirst: pinnedFirst);
    if (_pinVersion case final v?) return _s.call(pinned, version: v);
    while (_pinVersions.isNotEmpty) {
      final v = _pinVersions.first;
      try {
        final doc = await _s.call(pinned, version: v);
        _pinVersion = v;
        return doc;
      } on EwsException {
        _pinVersions.removeAt(0); // an unknown version or field
      }
    }
    return _s.call(findItemsSoap(folderId, offset, count));
  }

  @override
  Future<List<MailHeader>> search(MailFolder folder, String query,
      {int count = 50}) async {
    final toShown =
        folder.role == FolderRole.sent || folder.role == FolderRole.drafts;
    XmlDocument doc;
    try {
      doc = await _s.call(findItemsSoap(folder.path, 0, count, query: query));
    } on EwsException {
      // No search index on the server: at least the subjects.
      doc = await _s
          .call(findItemsSoap(folder.path, 0, count, subjectHas: query));
    }
    return parseItems(doc, offset: 0, recipientsAsSender: toShown).headers;
  }

  @override
  Future<MimeMessage> message(MailFolder folder, String id) async {
    final doc = await _s.call(getMimeSoap(id));
    final mime = doc
        .findAllElements('MimeContent', namespace: ewsTypes)
        .firstOrNull
        ?.innerText;
    if (mime == null) throw const EwsException('письмо без содержимого');
    return MimeMessage.parseFromData(base64Decode(mime.trim()));
  }

  @override
  Future<void> setSeen(MailFolder folder, String id, {required bool seen}) =>
      _s.call(setReadSoap(id, seen: seen));

  @override
  Future<void> move(MailFolder folder, String id, MailFolder to) =>
      _s.call(moveSoap(id, to.path));

  @override
  Future<void> delete(MailFolder folder, String id) =>
      _s.call(deleteSoap(id, permanently: folder.role == FolderRole.trash));

  @override
  Future<void> send(Uint8List mime) => _s.call(createItemSoap(mime));

  /// The signed-in user's address, which the out-of-office calls need:
  /// found once in the address book by the login.
  String? _address;

  Future<String> _myAddress() async {
    if (_address case final a?) return a;
    final login = _s.credentials.login;
    final name = login.split(r'\').last.split('@').first;
    final found = parseResolutions(await _s.call(resolveNamesSoap(name)));
    final me = found.where((a) => isMine(a.email, login)).firstOrNull ??
        (found.length == 1 ? found.single : null);
    if (me == null) throw const EwsException('не найден адрес почты');
    return _address = me.email;
  }

  @override
  Future<MailboxUsage> usage() async {
    final root = await _s.call(sendQuotaSoap);
    final sizes = parseFolderSizes(await _s.call(folderSizesSoap), _roles,
        recoverableRoot: parseRecoverableRoot(root));
    return MailboxUsage(
      used: sizes.folders.fold(0, (n, f) => n + f.size),
      quota: parseSendQuota(root),
      folders: sizes.folders,
      recoverable: sizes.recoverable,
    );
  }

  @override
  Future<AutoReply> autoReply() async =>
      parseAutoReply(await _s.call(getAutoReplySoap(await _myAddress())));

  @override
  Future<void> setAutoReply(AutoReply reply) async =>
      _s.call(setAutoReplySoap(await _myAddress(), reply));

  @override
  Future<String?> webSignature() async =>
      parseWebSignature(await _s.call(getWebOptionsSoap));

  @override
  Future<List<MailAddress>> searchDirectory(String query) async {
    try {
      return parseResolutions(await _s.call(resolveNamesSoap(query)));
    } on EwsException {
      return const []; // «No results were found» comes back as an error
    }
  }

  @override
  Future<void> disconnect() async {
    _session?.close();
    _session = null;
  }
}

// --- requests ---

const _systemFolders = {
  'inbox': FolderRole.inbox,
  'sentitems': FolderRole.sent,
  'drafts': FolderRole.drafts,
  'deleteditems': FolderRole.trash,
  'junkemail': FolderRole.junk,
};

final getSystemFoldersSoap = '<m:GetFolder>'
    '<m:FolderShape><t:BaseShape>IdOnly</t:BaseShape></m:FolderShape>'
    '<m:FolderIds>'
    '${[
  for (final id in _systemFolders.keys) '<t:DistinguishedFolderId Id="$id"/>'
].join()}'
    '</m:FolderIds></m:GetFolder>';

const inboxUnreadSoap = '<m:GetFolder>'
    '<m:FolderShape><t:BaseShape>IdOnly</t:BaseShape><t:AdditionalProperties>'
    '<t:FieldURI FieldURI="folder:UnreadCount"/></t:AdditionalProperties>'
    '</m:FolderShape><m:FolderIds><t:DistinguishedFolderId Id="inbox"/>'
    '</m:FolderIds></m:GetFolder>';

const findFoldersSoap = '<m:FindFolder Traversal="Deep">'
    '<m:FolderShape><t:BaseShape>IdOnly</t:BaseShape><t:AdditionalProperties>'
    '<t:FieldURI FieldURI="folder:DisplayName"/>'
    '<t:FieldURI FieldURI="folder:FolderClass"/>'
    '<t:FieldURI FieldURI="folder:UnreadCount"/>'
    '</t:AdditionalProperties></m:FolderShape>'
    '<m:ParentFolderIds><t:DistinguishedFolderId Id="msgfolderroot"/>'
    '</m:ParentFolderIds></m:FindFolder>';

/// PR_LAST_VERB_EXECUTED: 102 replied, 103 replied to all, 104 forwarded.
const _lastVerb =
    '<t:ExtendedFieldURI PropertyTag="0x1081" PropertyType="Integer"/>';

/// Outlook on the web pins a message by moving its «received or renewed»
/// time to 4500-09-01, so sorting by it puts pinned ones first.
const _renewTime = '<t:FieldURI FieldURI="item:ReceivedOrRenewTime"/>';
final _pinnedAfter = DateTime.utc(3000);

/// Ids of the messages pinned in [folderId]: renewed past [_pinnedAfter].
String findPinnedSoap(String folderId) => '<m:FindItem Traversal="Shallow">'
    '<m:ItemShape><t:BaseShape>IdOnly</t:BaseShape></m:ItemShape>'
    '<m:IndexedPageItemView MaxEntriesReturned="200" Offset="0" '
    'BasePoint="Beginning"/>'
    '<m:Restriction><t:IsGreaterThan>$_renewTime'
    '<t:FieldURIOrConstant><t:Constant Value="${_pinnedAfter.toIso8601String()}"/>'
    '</t:FieldURIOrConstant></t:IsGreaterThan></m:Restriction>'
    '<m:ParentFolderIds><t:FolderId Id="${xmlText(folderId)}"/></m:ParentFolderIds>'
    '</m:FindItem>';

/// A page of [folderId], newest first. With [pins] (a schema newer than
/// [ewsVersion]) it says which are pinned and, if [pinnedFirst], puts them
/// first as Outlook does.
///
/// A [query] searches the way Outlook does (Exchange's index: sender,
/// subject, text); [subjectHas] is the plain fallback without the index.
String findItemsSoap(String folderId, int offset, int count,
        {bool pins = false,
        bool pinnedFirst = true,
        String? query,
        String? subjectHas}) =>
    '<m:FindItem Traversal="Shallow">'
    '<m:ItemShape><t:BaseShape>IdOnly</t:BaseShape><t:AdditionalProperties>'
    '<t:FieldURI FieldURI="item:Subject"/>'
    '<t:FieldURI FieldURI="item:DateTimeReceived"/>'
    '<t:FieldURI FieldURI="item:HasAttachments"/>'
    '<t:FieldURI FieldURI="item:Size"/>'
    '<t:FieldURI FieldURI="item:DisplayTo"/>'
    '<t:FieldURI FieldURI="message:From"/>'
    '<t:FieldURI FieldURI="message:IsRead"/>'
    '$_lastVerb${pins ? _renewTime : ''}'
    '</t:AdditionalProperties></m:ItemShape>'
    '<m:IndexedPageItemView MaxEntriesReturned="$count" Offset="$offset" '
    'BasePoint="Beginning"/>'
    '${subjectHas == null ? '' : '<m:Restriction><t:Contains ContainmentMode="Substring" ContainmentComparison="IgnoreCase">'
        '<t:FieldURI FieldURI="item:Subject"/><t:Constant Value="${xmlText(subjectHas)}"/>'
        '</t:Contains></m:Restriction>'}'
    '<m:SortOrder><t:FieldOrder Order="Descending">'
    '${pins && pinnedFirst ? _renewTime : '<t:FieldURI FieldURI="item:DateTimeReceived"/>'}'
    '</t:FieldOrder></m:SortOrder>'
    '<m:ParentFolderIds><t:FolderId Id="${xmlText(folderId)}"/></m:ParentFolderIds>'
    '${query == null ? '' : '<m:QueryString>${xmlText(query)}</m:QueryString>'}'
    '</m:FindItem>';

String getMimeSoap(String id) => '<m:GetItem><m:ItemShape>'
    '<t:BaseShape>IdOnly</t:BaseShape>'
    '<t:IncludeMimeContent>true</t:IncludeMimeContent></m:ItemShape>'
    '<m:ItemIds><t:ItemId Id="${xmlText(id)}"/></m:ItemIds></m:GetItem>';

String setReadSoap(String id, {required bool seen}) =>
    '<m:UpdateItem MessageDisposition="SaveOnly" '
    'ConflictResolution="AlwaysOverwrite" SuppressReadReceipts="true">'
    '<m:ItemChanges><t:ItemChange><t:ItemId Id="${xmlText(id)}"/><t:Updates>'
    '<t:SetItemField><t:FieldURI FieldURI="message:IsRead"/>'
    '<t:Message><t:IsRead>$seen</t:IsRead></t:Message></t:SetItemField>'
    '</t:Updates></t:ItemChange></m:ItemChanges></m:UpdateItem>';

String moveSoap(String id, String folderId) => '<m:MoveItem>'
    '<m:ToFolderId><t:FolderId Id="${xmlText(folderId)}"/></m:ToFolderId>'
    '<m:ItemIds><t:ItemId Id="${xmlText(id)}"/></m:ItemIds></m:MoveItem>';

String deleteSoap(String id, {required bool permanently}) =>
    '<m:DeleteItem DeleteType="${permanently ? 'SoftDelete' : 'MoveToDeletedItems'}">'
    '<m:ItemIds><t:ItemId Id="${xmlText(id)}"/></m:ItemIds></m:DeleteItem>';

/// Exchange sends the MIME message as is and files a copy under Sent Items.
String createItemSoap(Uint8List mime) =>
    '<m:CreateItem MessageDisposition="SendAndSaveCopy">'
    '<m:SavedItemFolderId><t:DistinguishedFolderId Id="sentitems"/>'
    '</m:SavedItemFolderId><m:Items><t:Message>'
    '<t:MimeContent CharacterSet="UTF-8">${base64Encode(mime)}</t:MimeContent>'
    '</t:Message></m:Items></m:CreateItem>';

/// Outlook's address-book lookup: names, surnames and addresses starting
/// with [query], at most 100.
String resolveNamesSoap(String query) =>
    '<m:ResolveNames ReturnFullContactData="false" '
    'SearchScope="ActiveDirectory">'
    '<m:UnresolvedEntry>${xmlText(query)}</m:UnresolvedEntry></m:ResolveNames>';

/// PR_MESSAGE_SIZE_EXTENDED: a folder's messages, in bytes.
const _folderSize =
    '<t:ExtendedFieldURI PropertyTag="0x0E08" PropertyType="Long"/>';

/// Every folder of the mailbox with its size, hidden ones included.
const folderSizesSoap = '<m:FindFolder Traversal="Deep">'
    '<m:FolderShape><t:BaseShape>IdOnly</t:BaseShape><t:AdditionalProperties>'
    '<t:FieldURI FieldURI="folder:DisplayName"/>'
    '<t:FieldURI FieldURI="folder:TotalCount"/>'
    '<t:FieldURI FieldURI="folder:ParentFolderId"/>'
    '$_folderSize</t:AdditionalProperties></m:FolderShape>'
    '<m:ParentFolderIds><t:DistinguishedFolderId Id="root"/></m:ParentFolderIds>'
    '</m:FindFolder>';

/// PR_PROHIBIT_SEND_QUOTA (KB) is the mailbox's, not a folder's; some
/// servers show it on the root folder anyway, most leave it out. Asked
/// along with «Recoverable Items», which holds what was deleted for good
/// until the server purges it: it has its own limit, not this one.
const sendQuotaSoap = '<m:GetFolder>'
    '<m:FolderShape><t:BaseShape>IdOnly</t:BaseShape><t:AdditionalProperties>'
    '<t:ExtendedFieldURI PropertyTag="0x666E" PropertyType="Integer"/>'
    '</t:AdditionalProperties></m:FolderShape>'
    '<m:FolderIds><t:DistinguishedFolderId Id="root"/>'
    '<t:DistinguishedFolderId Id="recoverableitemsroot"/></m:FolderIds>'
    '</m:GetFolder>';

String getAutoReplySoap(String address) => '<m:GetUserOofSettingsRequest>'
    '<t:Mailbox><t:Address>${xmlText(address)}</t:Address></t:Mailbox>'
    '</m:GetUserOofSettingsRequest>';

/// Exchange keeps the reply as HTML: the text goes in with its line breaks.
String setAutoReplySoap(String address, AutoReply r) {
  final html = '<html><body>'
      '${xmlText(r.message.trim()).replaceAll('\n', '<br>')}</body></html>';
  final message = '<t:Message>${xmlText(html)}</t:Message>';
  final state = switch (r.state) {
    AutoReplyState.off => 'Disabled',
    AutoReplyState.on => 'Enabled',
    AutoReplyState.scheduled => 'Scheduled',
  };
  final start = r.start, end = r.end;
  return '<m:SetUserOofSettingsRequest>'
      '<t:Mailbox><t:Address>${xmlText(address)}</t:Address></t:Mailbox>'
      '<t:UserOofSettings><t:OofState>$state</t:OofState>'
      '<t:ExternalAudience>${r.external ? 'All' : 'None'}</t:ExternalAudience>'
      '${r.state == AutoReplyState.scheduled && start != null && end != null ? '<t:Duration>'
          '<t:StartTime>${start.toUtc().toIso8601String()}</t:StartTime>'
          '<t:EndTime>${end.toUtc().toIso8601String()}</t:EndTime></t:Duration>' : ''}'
      '<t:InternalReply>$message</t:InternalReply>'
      '<t:ExternalReply>$message</t:ExternalReply>'
      '</t:UserOofSettings></m:SetUserOofSettingsRequest>';
}

/// Outlook on the web's settings, the signature among them.
const getWebOptionsSoap = '<m:GetUserConfiguration>'
    '<m:UserConfigurationName Name="OWA.UserOptions">'
    '<t:DistinguishedFolderId Id="root"/></m:UserConfigurationName>'
    '<m:UserConfigurationProperties>Dictionary</m:UserConfigurationProperties>'
    '</m:GetUserConfiguration>';

// --- responses ---

Iterable<XmlElement> _t(XmlNode n, String name) =>
    n.findAllElements(name, namespace: ewsTypes);

String? _text(XmlElement e, String name) =>
    e.findElements(name, namespace: ewsTypes).firstOrNull?.innerText;

/// Folder sizes from [folderSizesSoap], biggest first. Search folders only
/// show messages kept elsewhere, so they don't count. Nor does
/// «Recoverable Items» ([recoverableRoot], or found by its name, which
/// Exchange doesn't translate) with its subfolders: that is [recoverable].
({List<FolderUsage> folders, int recoverable}) parseFolderSizes(
    XmlDocument doc, Map<String, FolderRole> roles,
    {String? recoverableRoot}) {
  final found = <({String id, String? parent, XmlElement f})>[];
  final root = doc.findAllElements('Folders', namespace: ewsTypes).firstOrNull;
  for (final f in root?.childElements ?? const <XmlElement>[]) {
    if (f.name.local == 'SearchFolder') continue;
    final id = _t(f, 'FolderId').firstOrNull?.getAttribute('Id');
    if (id == null) continue;
    found.add((
      id: id,
      parent: _t(f, 'ParentFolderId').firstOrNull?.getAttribute('Id'),
      f: f,
    ));
  }
  final parents = {for (final e in found) e.id: e.parent};
  final dumpster = recoverableRoot ??
      found
          .where((e) =>
              !parents.containsKey(e.parent) && // right under the root
              _text(e.f, 'DisplayName') == 'Recoverable Items')
          .firstOrNull
          ?.id;
  bool recovered(String id) {
    String? at = id;
    // Bounded, in case of a loop in what the server sent.
    for (var i = 0; at != null && i < 64; i++, at = parents[at]) {
      if (at == dumpster) return true;
    }
    return false;
  }

  final list = <FolderUsage>[];
  var recoverable = 0;
  for (final (:id, parent: _, :f) in found) {
    final size = int.tryParse(_t(f, 'ExtendedProperty')
                .map((p) => _text(p, 'Value'))
                .firstOrNull ??
            '') ??
        0;
    if (dumpster != null && recovered(id)) {
      recoverable += size;
      continue;
    }
    final name = _text(f, 'DisplayName') ?? '';
    list.add(FolderUsage(
      MailFolder(
          name: name,
          path: id,
          role: roles[id] ?? folderRole(path: id, name: name)),
      size: size,
      count: int.tryParse(_text(f, 'TotalCount') ?? '') ?? 0,
    ));
  }
  list.sort((a, b) => b.size.compareTo(a.size));
  return (folders: list, recoverable: recoverable);
}

Iterable<XmlElement> _getFolderAnswers(XmlDocument doc) =>
    doc.findAllElements('GetFolderResponseMessage', namespace: ewsMessages);

/// The send quota from [sendQuotaSoap] in bytes; null when not shown.
int? parseSendQuota(XmlDocument doc) {
  final root = _getFolderAnswers(doc).firstOrNull;
  if (root == null) return null;
  final kb = int.tryParse(
      _t(root, 'ExtendedProperty').map((p) => _text(p, 'Value')).firstOrNull ??
          '');
  return kb == null || kb <= 0 ? null : kb * 1024;
}

/// The id of «Recoverable Items» from [sendQuotaSoap], when the server
/// gave it.
String? parseRecoverableRoot(XmlDocument doc) {
  final answer = _getFolderAnswers(doc).elementAtOrNull(1);
  if (answer?.getAttribute('ResponseClass') != 'Success') return null;
  return _t(answer!, 'FolderId').firstOrNull?.getAttribute('Id');
}

/// The out-of-office settings from [getAutoReplySoap], the reply as text.
AutoReply parseAutoReply(XmlDocument doc) {
  final s = _t(doc, 'OofSettings').firstOrNull;
  if (s == null) return const AutoReply();
  String? reply(String name) {
    final r = _t(s, name).firstOrNull;
    return r == null ? null : _text(r, 'Message');
  }

  final duration = _t(s, 'Duration').firstOrNull;
  DateTime? time(String name) => duration == null
      ? null
      : DateTime.tryParse(_text(duration, name) ?? '')?.toLocal();
  return AutoReply(
    state: switch (_text(s, 'OofState')) {
      'Enabled' => AutoReplyState.on,
      'Scheduled' => AutoReplyState.scheduled,
      _ => AutoReplyState.off,
    },
    start: time('StartTime'),
    end: time('EndTime'),
    message: htmlToText(reply('InternalReply') ?? ''),
    external: _text(s, 'ExternalAudience') != 'None',
  );
}

/// The web mail's signature from [getWebOptionsSoap]: its text version, or
/// the HTML one made readable (pictures can't come along).
String? parseWebSignature(XmlDocument doc) {
  String? value(String key) {
    for (final e in _t(doc, 'DictionaryEntry')) {
      final k = _t(e, 'DictionaryKey').firstOrNull;
      if (k != null && _text(k, 'Value') == key) {
        final v = _t(e, 'DictionaryValue').firstOrNull;
        return v == null ? null : _text(v, 'Value');
      }
    }
    return null;
  }

  final text = value('signaturetext')?.trim() ?? '';
  if (text.isNotEmpty) return text;
  final html = htmlToText(value('signaturehtml') ?? '');
  return html.isEmpty ? null : html;
}

/// The people a [resolveNamesSoap] found, each address once.
List<MailAddress> parseResolutions(XmlDocument doc) {
  final seen = <String>{};
  return [
    for (final m in _t(doc, 'Mailbox'))
      if (_text(m, 'EmailAddress') case final email?
          when _text(m, 'RoutingType') != 'EX' &&
              email.contains('@') &&
              seen.add(email.toLowerCase()))
        MailAddress(_text(m, 'Name')?.trim(), email.trim()),
  ];
}

/// Folder id → role, from the GetFolder of the system folders (a folder the
/// mailbox lacks just has no entry).
Map<String, FolderRole> parseRoles(XmlDocument doc) {
  final roles = <String, FolderRole>{};
  final messages = doc
      .findAllElements('GetFolderResponseMessage', namespace: ewsMessages)
      .toList();
  final kinds = _systemFolders.values.toList();
  for (var i = 0; i < messages.length && i < kinds.length; i++) {
    final id = _t(messages[i], 'FolderId').firstOrNull?.getAttribute('Id');
    if (id != null) roles[id] = kinds[i];
  }
  return roles;
}

/// Mail folders (not calendar, contacts, …), system ones first.
List<MailFolder> parseFolders(XmlDocument doc, Map<String, FolderRole> roles) {
  final list = <MailFolder>[];
  for (final f in _t(doc, 'Folder')) {
    final id = _t(f, 'FolderId').firstOrNull?.getAttribute('Id');
    final cls = _text(f, 'FolderClass');
    if (id == null || (cls != null && !cls.startsWith('IPF.Note'))) continue;
    final name = _text(f, 'DisplayName') ?? '';
    list.add(MailFolder(
      name: name,
      path: id,
      role: roles[id] ?? folderRole(path: id, name: name),
      unseen: int.tryParse(_text(f, 'UnreadCount') ?? '') ?? 0,
    ));
  }
  list.sort((a, b) {
    final r = a.role.index.compareTo(b.role.index);
    return r != 0 ? r : a.name.toLowerCase().compareTo(b.name.toLowerCase());
  });
  return list;
}

/// A page of FindItem. [recipientsAsSender] shows «Кому» in the sender
/// column, for Отправленные and Черновики; [pinnedIds] come from
/// [findPinnedSoap].
MailPage parseItems(XmlDocument doc,
    {required int offset,
    bool recipientsAsSender = false,
    Set<String> pinnedIds = const {}}) {
  final root =
      doc.findAllElements('RootFolder', namespace: ewsMessages).firstOrNull;
  final items = root
          ?.findElements('Items', namespace: ewsTypes)
          .firstOrNull
          ?.childElements
          .toList() ??
      const <XmlElement>[];
  final headers = <MailHeader>[];
  for (var i = 0; i < items.length; i++) {
    final it = items[i];
    final id = _t(it, 'ItemId').firstOrNull?.getAttribute('Id');
    if (id == null) continue;
    final mailbox = it
        .findElements('From', namespace: ewsTypes)
        .firstOrNull
        ?.findElements('Mailbox', namespace: ewsTypes)
        .firstOrNull;
    final smtp = mailbox != null && _text(mailbox, 'RoutingType') != 'EX';
    final verb =
        _t(it, 'ExtendedProperty').map((p) => _text(p, 'Value')).firstOrNull;
    headers.add(MailHeader(
      id: id,
      seq: offset + i,
      fromName: recipientsAsSender
          ? _text(it, 'DisplayTo') ?? ''
          : (mailbox == null ? '' : _text(mailbox, 'Name') ?? ''),
      fromEmail: recipientsAsSender || !smtp
          ? ''
          : _text(mailbox, 'EmailAddress') ?? '',
      subject: (_text(it, 'Subject') ?? '').trim(),
      date: DateTime.tryParse(_text(it, 'DateTimeReceived') ?? ''),
      // Items other than messages (meeting requests too) count as read.
      seen: _text(it, 'IsRead') != 'false',
      answered: verb == '102' || verb == '103',
      hasAttachments: _text(it, 'HasAttachments') == 'true',
      size: int.tryParse(_text(it, 'Size') ?? ''),
      pinned: pinnedIds.contains(id) ||
          (DateTime.tryParse(_text(it, 'ReceivedOrRenewTime') ?? '')
                  ?.isAfter(_pinnedAfter) ??
              false),
    ));
  }
  final last = root?.getAttribute('IncludesLastItemInRange');
  return MailPage(headers, hasMore: last == 'false');
}
