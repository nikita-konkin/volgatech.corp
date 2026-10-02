import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:enough_mail/enough_mail.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:volgatech_pro/mail/compose.dart';
import 'package:volgatech_pro/mail/ews_client.dart';
import 'package:volgatech_pro/mail/ews_mail_service.dart';
import 'package:volgatech_pro/mail/mail_credentials.dart';
import 'package:volgatech_pro/mail/mail_models.dart';
import 'package:volgatech_pro/mail/ntlm.dart';
import 'package:volgatech_pro/mail/ui/message_page.dart' show fileSize;
import 'package:xml/xml.dart';

MimeMessage _parse(String raw) =>
    MimeMessage.parseFromText(raw.replaceAll('\n', '\r\n'));

final _original = _parse('''
From: =?utf-8?B?0JjQstCw0L3QvtCyINCYLtCYLg==?= <ivanov@volgatech.net>
To: KonkinNA@volgatech.net, petrova@volgatech.net
Cc: sidorov@volgatech.net
Subject: =?utf-8?B?0KDQsNGB0L/QuNGB0LDQvdC40LU=?=
Date: Mon, 28 Sep 2026 10:15:00 +0300
Message-ID: <abc@volgatech.net>
MIME-Version: 1.0
Content-Type: multipart/mixed; boundary="b"

--b
Content-Type: text/plain; charset=utf-8

Коллеги, расписание во вложении.
--b
Content-Type: application/pdf; name="plan.pdf"
Content-Disposition: attachment; filename="plan.pdf"
Content-Transfer-Encoding: base64

JVBERi0xLjQK
--b--
''');

const _successXml = '''
<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/"><s:Body>
<m:CreateItemResponse xmlns:m="http://schemas.microsoft.com/exchange/services/2006/messages">
<m:ResponseMessages><m:CreateItemResponseMessage ResponseClass="Success">
<m:ResponseCode>NoError</m:ResponseCode></m:CreateItemResponseMessage>
</m:ResponseMessages></m:CreateItemResponse></s:Body></s:Envelope>''';

/// CHALLENGE for domain MARSTU with an empty target info.
String _challenge() {
  final b = BytesBuilder()
    ..add(ascii.encode('NTLMSSP\x00'))
    ..add([2, 0, 0, 0])
    ..add([12, 0, 12, 0, 48, 0, 0, 0]) // target name: 6 UTF-16 chars at 48
    ..add([0x05, 0x82, 0x89, 0xa2]) // unicode, request target, ntlm, …
    ..add([1, 2, 3, 4, 5, 6, 7, 8]) // server challenge
    ..add(List.filled(8, 0))
    ..add([0, 0, 0, 0, 60, 0, 0, 0]) // empty target info
    ..add([
      for (final c in 'MARSTU'.codeUnits) ...[c, 0]
    ]);
  return base64Encode(b.toBytes());
}

void main() {
  setUpAll(() => initializeDateFormatting('ru_RU'));

  group('drafts', () {
    test('signature: at the end of new mail, above a quote', () {
      expect(signed('', ' Конкин Н.А. \n'), '\n\nКонкин Н.А.');
      final reply = ComposeDraft.reply(_original, all: false, myLogin: 'k');
      expect(reply.quotes, isTrue);
      expect(ComposeDraft().quotes, isFalse);
      final text = signed(reply.text, 'Конкин Н.А.');
      expect(text, startsWith('\n\nКонкин Н.А.\n\n'));
      expect(text.indexOf('Конкин'), lessThan(text.indexOf('> ')));
      expect(signed('abc', '  '), 'abc');
    });

    test('a draft left unsent keeps its text, not its attachments', () {
      final d = ComposeDraft.forward(_original)
        ..to = 'a@volgatech.net'
        ..text = 'Смотрите';
      final back = ComposeDraft.fromJson(
          jsonDecode(jsonEncode(d.toJson())) as Map<String, dynamic>);
      expect([back.to, back.subject, back.text, back.quotes],
          ['a@volgatech.net', d.subject, 'Смотрите', true]);
      expect(back.attachments, isEmpty);
      expect(back.lostAttachments, 1);
      expect([back.signedAlready, back.fromPhone], [true, true]);
      expect([d.signedAlready, d.fromPhone], [false, false]);
    });

    test('a picked recipient replaces the half-typed one', () {
      expect(lastRecipient('a@b.ru, орл'), 'орл');
      expect(lastRecipient('орл'), 'орл');
      expect(lastRecipient('a@b.ru; '), '');
      const p = MailAddress('Орлов, М.С.', 'OrlovMS@volgatech.net');
      expect(withRecipient('a@b.ru, орл', p),
          'a@b.ru, Орлов М.С. <OrlovMS@volgatech.net>, ');
      expect(withRecipient('орл', const MailAddress(null, 'x@volgatech.net')),
          'x@volgatech.net, ');
      // What the form sends is still valid.
      expect(parseRecipients(withRecipient('a@b.ru, орл', p)), hasLength(2));
    });

    test('reply goes to the sender, quoted, with RE:', () {
      final d = ComposeDraft.reply(_original, all: false, myLogin: 'konkinna');
      expect(d.to, 'Иванов И.И. <ivanov@volgatech.net>');
      expect(d.cc, '');
      expect(d.subject, 'RE: Расписание');
      expect(d.text, startsWith('\n\n28 сентября 2026 г., '));
      expect(d.text, contains('> Коллеги, расписание во вложении.'));
      expect(d.inReplyTo, '<abc@volgatech.net>');
    });

    test('reply all copies everyone except me', () {
      final d = ComposeDraft.reply(_original, all: true, myLogin: 'konkinna');
      expect(d.cc, 'petrova@volgatech.net, sidorov@volgatech.net');
    });

    test('forward keeps the attachments and the original header', () {
      final d = ComposeDraft.forward(_original);
      expect(d.subject, 'FW: Расписание');
      expect(d.to, '');
      expect(d.text, contains('От: Иванов И.И. <ivanov@volgatech.net>'));
      expect([for (final a in d.attachments) a.name], ['plan.pdf']);
      expect(ascii.decode(d.attachments.single.bytes), '%PDF-1.4\n');
    });

    test('recipients: names, separators, and rejects', () {
      final list = parseRecipients(
          'Иванов <ivanov@volgatech.net>; petrova@volgatech.net,')!;
      expect([for (final a in list) a.email],
          ['ivanov@volgatech.net', 'petrova@volgatech.net']);
      expect(list.first.personalName, 'Иванов');
      expect(parseRecipients('ivanov'), isNull);
      expect(parseRecipients(''), isEmpty);
    });

    test('the MIME message threads the reply and carries attachments', () {
      final d = ComposeDraft.reply(_original, all: false, myLogin: 'konkinna')
        ..text = 'Спасибо!';
      d.attachments.add(DraftAttachment(
          'отчёт.txt', 'text/plain', Uint8List.fromList(utf8.encode('ok'))));
      final m = MimeMessage.parseFromData(buildMime(d));
      expect(m.decodeSubject(), 'RE: Расписание');
      expect(m.getHeaderValue('in-reply-to'), '<abc@volgatech.net>');
      expect(m.to!.single.email, 'ivanov@volgatech.net');
      expect(m.decodeTextPlainPart()?.trim(), 'Спасибо!');
      expect(m.findContentInfo().single.fileName, 'отчёт.txt');
      expect(m.getHeaderValue('from'), isNull); // Exchange fills it in
    });
  });

  group('EWS', () {
    test('error text is picked out of a response', () {
      expect(ewsError(_successXml), isNull);
      expect(
          ewsError('<m:CreateItemResponseMessage ResponseClass="Error">'
              '<m:MessageText>Mailbox quota exceeded</m:MessageText>'),
          'Mailbox quota exceeded');
      expect(ewsError('<faultstring xml:lang="en">Bad request</faultstring>'),
          'Bad request');
      // One missing system folder doesn't fail the batch.
      expect(ewsError('<a ResponseClass="Success"/><b ResponseClass="Error"/>'),
          isNull);
    });

    test('address book: people and lists, each address once', () {
      expect(resolveNamesSoap('<Кар>'),
          contains('<m:UnresolvedEntry>&lt;Кар&gt;</m:UnresolvedEntry>'));
      final found = parseResolutions(XmlDocument.parse(_env(_resolvedXml)));
      expect([
        for (final a in found) '${a.personalName} ${a.email}'
      ], [
        'Орлов Антон Дмитриевич OrlovAD@volgatech.net',
        'Кафедра информатики kafedra@volgatech.net',
      ]);
    });

    test('web archive folder: the one Outlook on the web set, if any', () {
      String? archive(String entries) => parseWebArchiveFolder(XmlDocument
          .parse(_env('<m:GetUserConfigurationResponse><m:ResponseMessages>'
              '<m:GetUserConfigurationResponseMessage ResponseClass="Success">'
              '<m:UserConfiguration><t:Dictionary>$entries</t:Dictionary>'
              '</m:UserConfiguration></m:GetUserConfigurationResponseMessage>'
              '</m:ResponseMessages></m:GetUserConfigurationResponse>')));
      String entry(String k, String v) => '<t:DictionaryEntry>'
          '<t:DictionaryKey><t:Type>String</t:Type><t:Value>$k</t:Value></t:DictionaryKey>'
          '<t:DictionaryValue><t:Type>String</t:Type><t:Value>$v</t:Value></t:DictionaryValue>'
          '</t:DictionaryEntry>';
      expect(archive(entry('ArchiveFolderId', 'AAMkADRi=')), 'AAMkADRi=');
      expect(archive(entry('archivefolderid', ' AAMkX ')), 'AAMkX');
      expect(archive(entry('signaturetext', 'x')), isNull);
      expect(archive(entry('ArchiveFolderId', '')), isNull);
    });

    test('web signature: the text one, else the HTML one made readable', () {
      String? sig(String entries) => parseWebSignature(XmlDocument.parse(
          _env('<m:GetUserConfigurationResponse><m:ResponseMessages>'
              '<m:GetUserConfigurationResponseMessage ResponseClass="Success">'
              '<m:UserConfiguration><t:Dictionary>$entries</t:Dictionary>'
              '</m:UserConfiguration></m:GetUserConfigurationResponseMessage>'
              '</m:ResponseMessages></m:GetUserConfigurationResponse>')));
      String entry(String k, String v) => '<t:DictionaryEntry>'
          '<t:DictionaryKey><t:Type>String</t:Type><t:Value>$k</t:Value></t:DictionaryKey>'
          '<t:DictionaryValue><t:Type>String</t:Type><t:Value>$v</t:Value></t:DictionaryValue>'
          '</t:DictionaryEntry>';
      expect(
          sig(entry('autoaddsignature', 'True') +
              entry('signaturetext', ' С уважением, Конкин Н.А. ')),
          'С уважением, Конкин Н.А.');
      expect(
          sig(entry('signaturehtml',
              '&lt;div&gt;С уважением,&lt;br&gt;Конкин Н.А.&lt;/div&gt;&lt;img src="cid:x"&gt;')),
          'С уважением,\nКонкин Н.А.');
      expect(sig(entry('signaturetext', '')), isNull);
      expect(sig(''), isNull);
    });

    test('mailbox size: folders summed, search folders left out', () {
      final (:folders, :recoverable) = parseFolderSizes(
          XmlDocument.parse(_env('<m:FindFolderResponse><m:ResponseMessages>'
              '<m:FindFolderResponseMessage ResponseClass="Success"><m:RootFolder><t:Folders>'
              '<t:Folder><t:FolderId Id="F-in"/><t:DisplayName>Inbox</t:DisplayName><t:TotalCount>120</t:TotalCount>'
              '<t:ExtendedProperty><t:ExtendedFieldURI PropertyTag="0xe08" PropertyType="Long"/><t:Value>52428800</t:Value></t:ExtendedProperty></t:Folder>'
              '<t:SearchFolder><t:FolderId Id="S-1"/><t:DisplayName>Поиск</t:DisplayName>'
              '<t:ExtendedProperty><t:ExtendedFieldURI PropertyTag="0xe08" PropertyType="Long"/><t:Value>999999999</t:Value></t:ExtendedProperty></t:SearchFolder>'
              '<t:CalendarFolder><t:FolderId Id="F-cal"/><t:DisplayName>Календарь</t:DisplayName><t:TotalCount>3</t:TotalCount>'
              '<t:ExtendedProperty><t:ExtendedFieldURI PropertyTag="0xe08" PropertyType="Long"/><t:Value>1048576</t:Value></t:ExtendedProperty></t:CalendarFolder>'
              '<t:Folder><t:FolderId Id="F-del"/><t:DisplayName>Deleted Items</t:DisplayName><t:TotalCount>7</t:TotalCount>'
              '<t:ExtendedProperty><t:ExtendedFieldURI PropertyTag="0xe08" PropertyType="Long"/><t:Value>104857600</t:Value></t:ExtendedProperty></t:Folder>'
              '</t:Folders></m:RootFolder></m:FindFolderResponseMessage></m:ResponseMessages></m:FindFolderResponse>')),
          {'F-in': FolderRole.inbox, 'F-del': FolderRole.trash});
      expect([for (final f in folders) f.folder.title],
          ['Удалённые', 'Входящие', 'Календарь']);
      expect(folders.fold(0, (n, f) => n + f.size), 158334976);
      expect(folders[1].count, 120);
      expect(recoverable, 0);
      expect(fileSize(158334976), '151,0 МБ');
      expect(fileSize(2147483648), '2,0 ГБ');

      // The root, then «Recoverable Items» (or an error for it).
      const noDumpster = '<m:GetFolderResponseMessage ResponseClass="Error">'
          '<m:MessageText>not found</m:MessageText></m:GetFolderResponseMessage>';
      const dumpster = '<m:GetFolderResponseMessage ResponseClass="Success">'
          '<m:Folders><t:Folder><t:FolderId Id="R-root"/></t:Folder></m:Folders>'
          '</m:GetFolderResponseMessage>';
      XmlDocument quota(String props, String second) => XmlDocument.parse(_env(
          '<m:GetFolderResponse><m:ResponseMessages>'
          '<m:GetFolderResponseMessage ResponseClass="Success"><m:Folders><t:Folder>'
          '<t:FolderId Id="root"/>$props</t:Folder></m:Folders>'
          '</m:GetFolderResponseMessage>$second</m:ResponseMessages></m:GetFolderResponse>'));
      expect(parseSendQuota(quota('', noDumpster)), isNull);
      expect(parseRecoverableRoot(quota('', noDumpster)), isNull);
      expect(parseRecoverableRoot(quota('', dumpster)), 'R-root');
      expect(
          parseSendQuota(quota(
              '<t:ExtendedProperty>'
              '<t:ExtendedFieldURI PropertyTag="0x666e" PropertyType="Integer"/>'
              '<t:Value>2097152</t:Value></t:ExtendedProperty>',
              dumpster)),
          2147483648);
    });

    test('mailbox size: what is kept for recovery is not counted', () {
      String folder(String id, String parent, String name, int size) =>
          '<t:Folder><t:FolderId Id="$id"/><t:ParentFolderId Id="$parent"/>'
          '<t:DisplayName>$name</t:DisplayName><t:TotalCount>1</t:TotalCount>'
          '<t:ExtendedProperty><t:ExtendedFieldURI PropertyTag="0xe08" PropertyType="Long"/>'
          '<t:Value>$size</t:Value></t:ExtendedProperty></t:Folder>';
      const mb = 1024 * 1024;
      final doc = XmlDocument.parse(_env(
          '<m:FindFolderResponse><m:ResponseMessages>'
          '<m:FindFolderResponseMessage ResponseClass="Success"><m:RootFolder><t:Folders>'
          '${folder('IPM', 'ROOT', 'Top of Information Store', 0)}'
          '${folder('F-in', 'IPM', 'Inbox', 400 * mb)}'
          // A folder of the user's own that happens to share a name.
          '${folder('F-mine', 'F-in', 'Deletions', 3 * mb)}'
          '${folder('R-root', 'ROOT', 'Recoverable Items', 0)}'
          '${folder('R-del', 'R-root', 'Deletions', 20 * mb)}'
          '${folder('R-purge', 'R-root', 'Purges', 2 * mb)}'
          '${folder('R-deep', 'R-del', 'Calendar Logging', mb)}'
          '</t:Folders></m:RootFolder></m:FindFolderResponseMessage>'
          '</m:ResponseMessages></m:FindFolderResponse>'));
      for (final id in ['R-root', null]) {
        // By the id the server gave, or else by the name.
        final (:folders, :recoverable) =
            parseFolderSizes(doc, const {}, recoverableRoot: id);
        expect(folders.fold(0, (n, f) => n + f.size), 403 * mb);
        expect([for (final f in folders) f.folder.name],
            ['Inbox', 'Deletions', 'Top of Information Store']);
        expect(recoverable, 23 * mb);
      }
    });

    test('auto reply: read as text, written as HTML, dates when scheduled', () {
      final r = parseAutoReply(XmlDocument.parse(_env(_autoReplyXml)));
      expect(r.state, AutoReplyState.scheduled);
      expect(r.message, 'В отпуске.\nОтвечу после 10 октября.');
      expect(r.start, DateTime.utc(2026, 10, 1).toLocal());
      expect(r.external, isFalse);

      final on = setAutoReplySoap(
          'KonkinNA@volgatech.net',
          const AutoReply(
              state: AutoReplyState.on, message: 'A & B\nC', external: true));
      expect(on, contains('<t:OofState>Enabled</t:OofState>'));
      expect(on, contains('<t:ExternalAudience>All</t:ExternalAudience>'));
      expect(on, isNot(contains('<t:Duration>')));
      // The HTML is escaped once more as XML text.
      expect(on, contains('A &amp;amp; B&lt;br&gt;C'));
      final dated = setAutoReplySoap(
          'a@b.ru',
          AutoReply(
              state: AutoReplyState.scheduled,
              start: DateTime.utc(2026, 10, 1),
              end: DateTime.utc(2026, 10, 11),
              external: false));
      expect(dated,
          contains('<t:StartTime>2026-10-01T00:00:00.000Z</t:StartTime>'));
      expect(dated, contains('<t:ExternalAudience>None</t:ExternalAudience>'));
    });

    test('system folders map to roles, a missing one is skipped', () {
      final roles = parseRoles(XmlDocument.parse(_env(_rolesXml)));
      expect(roles, {
        'F-in': FolderRole.inbox,
        'F-sent': FolderRole.sent,
        'F-drafts': FolderRole.drafts,
        'F-del': FolderRole.trash,
      });
    });

    test('folders: mail only, system ones first with Russian titles', () {
      final list = parseFolders(XmlDocument.parse(_env(_foldersXml)),
          {'F-in': FolderRole.inbox, 'F-sent': FolderRole.sent});
      expect([for (final f in list) f.title],
          ['Входящие', 'Отправленные', 'Проекты']);
      expect(list.first.unseen, 3);
    });

    test('folders: the web mail\'s archive, else one named «Архив»', () {
      final doc = XmlDocument.parse(_env(
          '<m:FindFolderResponse><m:ResponseMessages>'
          '<m:FindFolderResponseMessage ResponseClass="Success"><m:RootFolder><t:Folders>'
          '<t:Folder><t:FolderId Id="F-a"/><t:DisplayName>Архив</t:DisplayName><t:FolderClass>IPF.Note</t:FolderClass></t:Folder>'
          '<t:Folder><t:FolderId Id="F-old"/><t:DisplayName>Старое</t:DisplayName><t:FolderClass>IPF.Note</t:FolderClass></t:Folder>'
          '</t:Folders></m:RootFolder></m:FindFolderResponseMessage></m:ResponseMessages></m:FindFolderResponse>'));
      Map<String, FolderRole> roles(Map<String, FolderRole> known) =>
          {for (final f in parseFolders(doc, known)) f.path: f.role};
      expect(roles({}), {'F-a': FolderRole.archive, 'F-old': FolderRole.other});
      expect(roles({'F-old': FolderRole.archive}),
          {'F-a': FolderRole.other, 'F-old': FolderRole.archive});
      // The web mail's one isn't among them (gone, or another id form).
      expect(roles({'F-gone': FolderRole.archive})['F-a'], FolderRole.archive);
      expect(roles({})['F-old'], FolderRole.other);
      final named = parseFolders(doc, {}).first;
      expect(named.title, 'Архив');
    });

    test('pin and unpin: the two times Outlook on the web sets', () {
      final pin = setPinnedSoap('I1', pinned: true);
      XmlDocument.parse(_env(pin)); // well-formed
      expect('PropertyTag="0x0F01"'.allMatches(pin), hasLength(2));
      expect('PropertyTag="0x0F02"'.allMatches(pin), hasLength(2));
      expect('<t:Value>4500-09-01T00:00:00.000Z</t:Value>'.allMatches(pin),
          hasLength(2));
      expect(pin, contains('<t:Message><t:ExtendedProperty>'));
      expect(pin, contains('ConflictResolution="AlwaysOverwrite"'));

      final unpin = setPinnedSoap('I1',
          pinned: false, received: DateTime.utc(2026, 9, 28, 7, 15));
      XmlDocument.parse(_env(unpin));
      expect(unpin, isNot(contains('4500')));
      expect(unpin, contains('<t:Value>2026-09-28T07:15:00.000Z</t:Value>'));
      expect(
          unpin,
          contains('<t:DeleteItemField><t:ExtendedFieldURI '
              'PropertyTag="0x0F02" PropertyType="SystemTime"/>'));

      final item = setPinnedSoap('I2', pinned: true, kind: 'Item');
      expect(item, contains('<t:Item><t:ExtendedProperty>'));
      expect(item, isNot(contains('<t:Message>')));
    });

    test('a new folder: a mail folder, the name escaped', () {
      final soap = createFolderSoap('A & B');
      XmlDocument.parse(_env(soap));
      expect(
          soap,
          contains('<t:FolderClass>IPF.Note</t:FolderClass>'
              '<t:DisplayName>A &amp; B</t:DisplayName>'));
      expect(soap, contains('<t:DistinguishedFolderId Id="msgfolderroot"/>'));
    });

    test('items: sender, read state, replies, attachments, paging', () {
      final page = parseItems(XmlDocument.parse(_env(_itemsXml)), offset: 40);
      expect(page.hasMore, isTrue);
      final a = page.headers[0], b = page.headers[1];
      expect(a.id, 'I1');
      expect(a.seq, 40);
      expect(a.from, 'Иванов И.И.');
      expect(a.fromEmail, 'ivanov@volgatech.net');
      expect(a.subject, 'Расписание');
      expect(a.date, DateTime.utc(2026, 9, 28, 7, 15));
      expect(a.seen, isFalse);
      expect(a.answered, isTrue);
      expect(a.hasAttachments, isTrue);
      expect(a.size, 52340);
      expect(b.size, isNull);
      expect(a.pinned, isTrue); // renewed to 4500 by Outlook's pin
      expect(b.pinned, isFalse);
      final byId = parseItems(XmlDocument.parse(_env(_itemsXml)),
          offset: 0, pinnedIds: {'I2'});
      expect(byId.headers[1].pinned, isTrue);
      expect(b.fromEmail, ''); // Exchange-internal (EX) address
      expect(b.seen, isTrue);
      expect(b.seq, 41);
    });

    test('search: Outlook\'s query last, the subject fallback before sorting',
        () {
      final q = findItemsSoap('F-in', 0, 50, query: 'Иванов <x>');
      expect(
          q,
          endsWith('</m:ParentFolderIds>'
              '<m:QueryString>Иванов &lt;x&gt;</m:QueryString></m:FindItem>'));
      final s = findItemsSoap('F-in', 0, 50, subjectHas: 'план');
      expect(
          s.indexOf('<m:Restriction>'), lessThan(s.indexOf('<m:SortOrder>')));
      expect(s, contains('<t:Constant Value="план"/>'));
      expect(findItemsSoap('F-in', 0, 50), isNot(contains('QueryString')));
    });

    test('pins: Outlook\'s order needs a newer schema', () {
      final pinned = findItemsSoap('F-in', 0, 40, pins: true);
      expect(
          pinned,
          contains('<t:FieldOrder Order="Descending">'
              '<t:FieldURI FieldURI="item:ReceivedOrRenewTime"/>'));
      expect(findItemsSoap('F-in', 0, 40), isNot(contains('RenewTime')));
      expect(
          findPinnedSoap('F-in'),
          contains('<m:Restriction><t:IsGreaterThan>'
              '<t:FieldURI FieldURI="item:ReceivedOrRenewTime"/>'
              '<t:FieldURIOrConstant>'
              '<t:Constant Value="3000-01-01T00:00:00.000Z"/>'));
      // Option off: still says which are pinned, sorted by arrival.
      final dated =
          findItemsSoap('F-in', 0, 40, pins: true, pinnedFirst: false);
      expect(dated, contains('<t:AdditionalProperties>'));
      expect(dated, contains('item:ReceivedOrRenewTime'));
      expect(
          dated,
          contains('<t:FieldOrder Order="Descending">'
              '<t:FieldURI FieldURI="item:DateTimeReceived"/>'));
      expect(soapEnvelope('x', version: 'Exchange2016'),
          contains('<t:RequestServerVersion Version="Exchange2016"/>'));
    });

    late HttpServer server;
    late List<String> log;
    late Set<int> authed;

    /// Schema versions the fake server rejects, and the ones it was sent.
    late Set<String> unknownVersions;
    late List<String> versions;
    late bool rejectRestriction;
    late bool noSearchIndex;
    late bool rejectMessagePin;
    setUp(() async {
      log = [];
      authed = {};
      unknownVersions = {};
      versions = [];
      rejectRestriction = false;
      noSearchIndex = false;
      rejectMessagePin = false;
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((req) async {
        final auth = req.headers.value('authorization') ?? '';
        final body = await utf8.decodeStream(req);
        final port = req.connectionInfo!.remotePort;
        final msg =
            auth.startsWith('NTLM ') ? base64Decode(auth.substring(5)) : null;
        final res = req.response;
        final version = RegExp(r'RequestServerVersion Version="(\w+)"')
            .firstMatch(body)?[1];
        if (version != null && body.contains('<m:FindItem')) {
          versions.add(version);
        }
        if (msg != null && msg[8] == 1) {
          log.add('negotiate');
          res
            ..statusCode = 401
            ..headers.add('WWW-Authenticate', 'NTLM ${_challenge()}');
        } else if (msg != null && msg[8] == 3) {
          int u16(int at) => msg[at] | msg[at + 1] << 8;
          int u32(int at) => u16(at) | u16(at + 2) << 16;
          String text(int at) => String.fromCharCodes([
                for (var i = 0; i < u16(at); i += 2) msg[u32(at + 4) + i],
              ]);
          if (text(28) == 'MARSTU' && text(36) == 'konkinna') {
            authed.add(port);
            log.add('auth');
            res.write(_answer(body));
          } else {
            res.statusCode = 401;
          }
        } else if (authed.contains(port) &&
            (unknownVersions.contains(version) ||
                rejectRestriction && body.contains('<t:IsGreaterThan>') ||
                noSearchIndex && body.contains('<m:QueryString>') ||
                rejectMessagePin &&
                    body.contains('<t:Message><t:ExtendedProperty>'))) {
          log.add('call');
          res
            ..statusCode = 500
            ..write('<faultstring>The request failed schema validation'
                '</faultstring>');
        } else if (authed.contains(port)) {
          log.add('call');
          res.write(_answer(body));
        } else {
          res
            ..statusCode = 401
            ..headers.add('WWW-Authenticate', 'NTLM');
        }
        await res.close();
      });
    });
    tearDown(() => server.close(force: true));

    EwsMailService service() => EwsMailService(
        endpoint:
            Uri.parse('http://127.0.0.1:${server.port}/EWS/Exchange.asmx'));

    test('signs in once, then reuses the connection', () async {
      final s = service();
      await s.connect(const MailCredentials(r'MARSTU\konkinna', 'secret'));
      final folders = await s.folders();
      final page = await s.headers(folders.first);
      expect(page.headers, hasLength(2));
      final msg = await s.message(folders.first, 'I1');
      expect(msg.decodeSubject(), 'Проверка');
      await s.send(Uint8List.fromList(utf8.encode('Subject: hi\r\n\r\nhello')));
      await s.disconnect();
      // GetFolder, the web mail's settings, FindFolder, FindItem, the pinned
      // ids, GetItem, CreateItem.
      expect(log, [
        'negotiate',
        'auth',
        'call',
        'call',
        'call',
        'call',
        'call',
        'call'
      ]);
    });

    test('folders: the web mail\'s archive folder, asked once', () async {
      final s = service();
      await s.connect(const MailCredentials(r'MARSTU\konkinna', 'secret'));
      final list = await s.folders();
      expect(list.singleWhere((f) => f.role == FolderRole.archive).path, 'F-p');
      await s.folders();
      // GetFolder; then the settings and FindFolder; then FindFolder only.
      expect(log, ['negotiate', 'auth', 'call', 'call', 'call']);
    });

    test('pin: as a message, or as any item when that is refused', () async {
      final s = service();
      await s.connect(const MailCredentials(r'MARSTU\konkinna', 'secret'));
      final inbox = (await s.folders()).first;
      log.clear();
      await s.setPinned(inbox, 'I1', pinned: true);
      expect(log, ['call']);

      rejectMessagePin = true;
      log.clear();
      await s.setPinned(inbox, 'I2',
          pinned: false, received: DateTime.utc(2026, 9, 27));
      expect(log, ['call', 'call']);
    });

    test('a new folder: made at the top, with the id Exchange gave', () async {
      final s = service();
      await s.connect(const MailCredentials(r'MARSTU\konkinna', 'secret'));
      final f = await s.createFolder('Архив');
      expect(f.path, 'F-new');
      expect(f.role, FolderRole.archive);
    });

    test('pins: the first schema the server knows is kept', () async {
      unknownVersions = {'Exchange2016'};
      final s = service();
      await s.connect(const MailCredentials(r'MARSTU\konkinna', 'secret'));
      final inbox = (await s.folders()).first;
      final page = await s.headers(inbox);
      expect([for (final h in page.headers) h.pinned], [true, true]);
      await s.headers(inbox, before: 1);
      // Rejected, accepted, the pinned ids, then page 2.
      expect(versions,
          ['Exchange2016', 'V2015_10_05', 'V2015_10_05', 'V2015_10_05']);
    });

    test('pins: a rejected pinned query leaves the list as it is', () async {
      rejectRestriction = true;
      final s = service();
      await s.connect(const MailCredentials(r'MARSTU\konkinna', 'secret'));
      final page = await s.headers((await s.folders()).first);
      expect([for (final h in page.headers) h.pinned], [true, false]);
    });

    test('pins: a server that knows none gets the plain list', () async {
      unknownVersions = {'Exchange2016', 'V2015_10_05'};
      final s = service();
      await s.connect(const MailCredentials(r'MARSTU\konkinna', 'secret'));
      final inbox = (await s.folders()).first;
      expect((await s.headers(inbox)).headers, hasLength(2));
      await s.headers(inbox, before: 1);
      expect(versions,
          ['Exchange2016', 'V2015_10_05', 'Exchange2013', 'Exchange2013']);
    });

    test('search: without the server\'s index, by subject', () async {
      final s = service();
      await s.connect(const MailCredentials(r'MARSTU\konkinna', 'secret'));
      final inbox = (await s.folders()).first;
      expect(await s.search(inbox, 'Расписание'), hasLength(2));
      noSearchIndex = true;
      log.clear();
      expect(await s.search(inbox, 'Расписание'), hasLength(2));
      expect(log, ['call', 'call']); // the query, then the fallback
    });

    test('auto reply: the mailbox is found by the login, once', () async {
      final s = service();
      await s.connect(const MailCredentials(r'MARSTU\konkinna', 'secret'));
      expect((await s.autoReply()).state, AutoReplyState.scheduled);
      log.clear();
      await s.setAutoReply(const AutoReply());
      expect(log, ['call']); // no second address lookup
    });

    test('move: MoveItem to the chosen folder', () async {
      expect(
          moveSoap('I<1>', 'F-p'),
          '<m:MoveItem><m:ToFolderId><t:FolderId Id="F-p"/></m:ToFolderId>'
          '<m:ItemIds><t:ItemId Id="I&lt;1&gt;"/></m:ItemIds></m:MoveItem>');
      final s = service();
      await s.connect(const MailCredentials(r'MARSTU\konkinna', 'secret'));
      final folders = await s.folders();
      await s.move(folders.first, 'I1', folders.last);
    });

    test('address book: found, or empty when nothing matches', () async {
      final s = service();
      await s.connect(const MailCredentials(r'MARSTU\konkinna', 'secret'));
      expect(await s.searchDirectory('орл'), hasLength(2));
      expect(await s.searchDirectory('щщщ'), isEmpty);
    });

    test('a rejected password is an auth error', () async {
      await expectLater(
          service().connect(const MailCredentials(r'MARSTU\someone', 'x')),
          throwsA(isA<MailAuthException>()));
    });

    test('the domain from the challenge is used for a bare login', () {
      final c = NtlmChallenge.parse(_challenge());
      expect(c.targetName, 'MARSTU');
    });
  });
}

String _env(String body) =>
    '<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" '
    'xmlns:m="$ewsMessages" xmlns:t="$ewsTypes"><s:Body>$body</s:Body></s:Envelope>';

const _rolesXml = '<m:GetFolderResponse><m:ResponseMessages>'
    '<m:GetFolderResponseMessage ResponseClass="Success"><m:Folders><t:Folder><t:FolderId Id="F-in"/></t:Folder></m:Folders></m:GetFolderResponseMessage>'
    '<m:GetFolderResponseMessage ResponseClass="Success"><m:Folders><t:Folder><t:FolderId Id="F-sent"/></t:Folder></m:Folders></m:GetFolderResponseMessage>'
    '<m:GetFolderResponseMessage ResponseClass="Success"><m:Folders><t:Folder><t:FolderId Id="F-drafts"/></t:Folder></m:Folders></m:GetFolderResponseMessage>'
    '<m:GetFolderResponseMessage ResponseClass="Success"><m:Folders><t:Folder><t:FolderId Id="F-del"/></t:Folder></m:Folders></m:GetFolderResponseMessage>'
    '<m:GetFolderResponseMessage ResponseClass="Error"><m:MessageText>not found</m:MessageText></m:GetFolderResponseMessage>'
    '</m:ResponseMessages></m:GetFolderResponse>';

const _foldersXml = '<m:FindFolderResponse><m:ResponseMessages>'
    '<m:FindFolderResponseMessage ResponseClass="Success"><m:RootFolder><t:Folders>'
    '<t:Folder><t:FolderId Id="F-p"/><t:DisplayName>Проекты</t:DisplayName><t:FolderClass>IPF.Note</t:FolderClass><t:UnreadCount>0</t:UnreadCount></t:Folder>'
    '<t:CalendarFolder><t:FolderId Id="F-cal"/><t:DisplayName>Календарь</t:DisplayName></t:CalendarFolder>'
    '<t:Folder><t:FolderId Id="F-c"/><t:DisplayName>Контакты</t:DisplayName><t:FolderClass>IPF.Contact</t:FolderClass></t:Folder>'
    '<t:Folder><t:FolderId Id="F-sent"/><t:DisplayName>Отправленные</t:DisplayName><t:FolderClass>IPF.Note</t:FolderClass><t:UnreadCount>0</t:UnreadCount></t:Folder>'
    '<t:Folder><t:FolderId Id="F-in"/><t:DisplayName>Входящие</t:DisplayName><t:FolderClass>IPF.Note</t:FolderClass><t:UnreadCount>3</t:UnreadCount></t:Folder>'
    '</t:Folders></m:RootFolder></m:FindFolderResponseMessage></m:ResponseMessages></m:FindFolderResponse>';

const _itemsXml = '<m:FindItemResponse><m:ResponseMessages>'
    '<m:FindItemResponseMessage ResponseClass="Success">'
    '<m:RootFolder IndexedPagingOffset="42" TotalItemsInView="100" IncludesLastItemInRange="false"><t:Items>'
    '<t:Message><t:ItemId Id="I1" ChangeKey="k"/><t:Subject>Расписание</t:Subject>'
    '<t:DateTimeReceived>2026-09-28T07:15:00Z</t:DateTimeReceived><t:HasAttachments>true</t:HasAttachments><t:Size>52340</t:Size>'
    '<t:ExtendedProperty><t:ExtendedFieldURI PropertyTag="0x1081" PropertyType="Integer"/><t:Value>102</t:Value></t:ExtendedProperty>'
    '<t:From><t:Mailbox><t:Name>Иванов И.И.</t:Name><t:EmailAddress>ivanov@volgatech.net</t:EmailAddress><t:RoutingType>SMTP</t:RoutingType></t:Mailbox></t:From>'
    '<t:IsRead>false</t:IsRead><t:ReceivedOrRenewTime>4500-09-01T00:00:00Z</t:ReceivedOrRenewTime></t:Message>'
    '<t:MeetingRequest><t:ItemId Id="I2" ChangeKey="k"/><t:Subject>Совещание</t:Subject>'
    '<t:DateTimeReceived>2026-09-27T07:15:00Z</t:DateTimeReceived><t:HasAttachments>false</t:HasAttachments>'
    '<t:From><t:Mailbox><t:Name>Петрова</t:Name><t:EmailAddress>/O=MARSTU/OU=EXCHANGE/CN=PETROVA</t:EmailAddress><t:RoutingType>EX</t:RoutingType></t:Mailbox></t:From>'
    '<t:IsRead>true</t:IsRead><t:ReceivedOrRenewTime>2026-09-27T07:15:00Z</t:ReceivedOrRenewTime></t:MeetingRequest>'
    '</t:Items></m:RootFolder></m:FindItemResponseMessage></m:ResponseMessages></m:FindItemResponse>';

const _autoReplyXml = '<GetUserOofSettingsResponse xmlns="$ewsMessages">'
    '<ResponseMessage ResponseClass="Success"><ResponseCode>NoError</ResponseCode></ResponseMessage>'
    '<OofSettings xmlns="$ewsTypes"><OofState>Scheduled</OofState>'
    '<ExternalAudience>None</ExternalAudience>'
    '<Duration><StartTime>2026-10-01T00:00:00Z</StartTime><EndTime>2026-10-11T00:00:00Z</EndTime></Duration>'
    '<InternalReply><Message>&lt;html&gt;&lt;body&gt;В отпуске.&lt;br&gt;Отвечу после 10 октября.&lt;/body&gt;&lt;/html&gt;</Message></InternalReply>'
    '<ExternalReply><Message></Message></ExternalReply></OofSettings>'
    '<AllowExternalOof>All</AllowExternalOof></GetUserOofSettingsResponse>';

/// ResolveNames with several matches: a Warning, not an Error.
const _resolvedXml = '<m:ResolveNamesResponse><m:ResponseMessages>'
    '<m:ResolveNamesResponseMessage ResponseClass="Warning">'
    '<m:MessageText>Multiple results were found.</m:MessageText>'
    '<m:ResponseCode>ErrorNameResolutionMultipleResults</m:ResponseCode>'
    '<m:ResolutionSet TotalItemsInView="4" IncludesLastItemInRange="true">'
    '<t:Resolution><t:Mailbox><t:Name>Орлов Антон Дмитриевич</t:Name><t:EmailAddress>OrlovAD@volgatech.net</t:EmailAddress><t:RoutingType>SMTP</t:RoutingType><t:MailboxType>Mailbox</t:MailboxType></t:Mailbox></t:Resolution>'
    '<t:Resolution><t:Mailbox><t:Name>Орлов А.Д.</t:Name><t:EmailAddress>orlovad@volgatech.net</t:EmailAddress><t:RoutingType>SMTP</t:RoutingType><t:MailboxType>Contact</t:MailboxType></t:Mailbox></t:Resolution>'
    '<t:Resolution><t:Mailbox><t:Name>Кафедра информатики</t:Name><t:EmailAddress>kafedra@volgatech.net</t:EmailAddress><t:RoutingType>SMTP</t:RoutingType><t:MailboxType>PublicDL</t:MailboxType></t:Mailbox></t:Resolution>'
    '<t:Resolution><t:Mailbox><t:Name>Старый ящик</t:Name><t:EmailAddress>/O=MARSTU/CN=OLD</t:EmailAddress><t:RoutingType>EX</t:RoutingType></t:Mailbox></t:Resolution>'
    '</m:ResolutionSet></m:ResolveNamesResponseMessage></m:ResponseMessages></m:ResolveNamesResponse>';

/// The pinned ones: Exchange says which by id, not by their renew time.
const _pinnedXml = '<m:FindItemResponse><m:ResponseMessages>'
    '<m:FindItemResponseMessage ResponseClass="Success">'
    '<m:RootFolder IncludesLastItemInRange="true"><t:Items>'
    '<t:MeetingRequest><t:ItemId Id="I2" ChangeKey="k"/></t:MeetingRequest>'
    '</t:Items></m:RootFolder></m:FindItemResponseMessage></m:ResponseMessages></m:FindItemResponse>';

/// What the fake Exchange answers to each operation.
String _answer(String request) {
  if (request.contains('<m:GetFolder>')) return _env(_rolesXml);
  if (request.contains('<m:FindFolder')) return _env(_foldersXml);
  if (request.contains('<t:IsGreaterThan>')) return _env(_pinnedXml);
  if (request.contains('<m:GetUserOofSettingsRequest>')) {
    return request.contains('KonkinNA@volgatech.net')
        ? _env(_autoReplyXml)
        : _env('<m:X ResponseClass="Error"><m:MessageText>wrong mailbox'
            '</m:MessageText></m:X>');
  }
  if (request.contains('<m:SetUserOofSettingsRequest>')) return _successXml;
  if (request.contains('>konkinna<')) {
    return _env('<m:ResolveNamesResponse><m:ResponseMessages>'
        '<m:ResolveNamesResponseMessage ResponseClass="Warning"><m:ResolutionSet>'
        '<t:Resolution><t:Mailbox><t:Name>Конкин Н.А.</t:Name><t:EmailAddress>KonkinNA@volgatech.net</t:EmailAddress><t:RoutingType>SMTP</t:RoutingType></t:Mailbox></t:Resolution>'
        '<t:Resolution><t:Mailbox><t:Name>Петрова Е.</t:Name><t:EmailAddress>PetrovaE@volgatech.net</t:EmailAddress><t:RoutingType>SMTP</t:RoutingType></t:Mailbox></t:Resolution>'
        '</m:ResolutionSet></m:ResolveNamesResponseMessage></m:ResponseMessages></m:ResolveNamesResponse>');
  }
  if (request.contains('<m:ResolveNames')) {
    return request.contains('>орл<')
        ? _env(_resolvedXml)
        : _env('<m:ResolveNamesResponse><m:ResponseMessages>'
            '<m:ResolveNamesResponseMessage ResponseClass="Error">'
            '<m:MessageText>No results were found.</m:MessageText>'
            '<m:ResponseCode>ErrorNameResolutionNoResults</m:ResponseCode>'
            '</m:ResolveNamesResponseMessage></m:ResponseMessages></m:ResolveNamesResponse>');
  }
  if (request.contains('<m:GetUserConfiguration>')) {
    return _env('<m:GetUserConfigurationResponse><m:ResponseMessages>'
        '<m:GetUserConfigurationResponseMessage ResponseClass="Success">'
        '<m:UserConfiguration><t:Dictionary><t:DictionaryEntry>'
        '<t:DictionaryKey><t:Type>String</t:Type><t:Value>ArchiveFolderId</t:Value></t:DictionaryKey>'
        '<t:DictionaryValue><t:Type>String</t:Type><t:Value>F-p</t:Value></t:DictionaryValue>'
        '</t:DictionaryEntry></t:Dictionary></m:UserConfiguration>'
        '</m:GetUserConfigurationResponseMessage></m:ResponseMessages>'
        '</m:GetUserConfigurationResponse>');
  }
  if (request.contains('<m:CreateFolder>')) {
    return _env('<m:CreateFolderResponse><m:ResponseMessages>'
        '<m:CreateFolderResponseMessage ResponseClass="Success"><m:Folders>'
        '<t:Folder><t:FolderId Id="F-new" ChangeKey="k"/></t:Folder>'
        '</m:Folders></m:CreateFolderResponseMessage></m:ResponseMessages>'
        '</m:CreateFolderResponse>');
  }
  if (request.contains('<m:UpdateItem')) return _successXml;
  if (request.contains('<m:FindItem')) return _env(_itemsXml);
  if (request.contains('<m:GetItem>')) {
    final mime = base64Encode(utf8
        .encode('Subject: =?utf-8?B?0J/RgNC+0LLQtdGA0LrQsA==?=\r\n\r\nтело'));
    return _env('<m:GetItemResponse><m:ResponseMessages>'
        '<m:GetItemResponseMessage ResponseClass="Success"><m:Items><t:Message>'
        '<t:MimeContent CharacterSet="UTF-8">$mime</t:MimeContent>'
        '</t:Message></m:Items></m:GetItemResponseMessage></m:ResponseMessages></m:GetItemResponse>');
  }
  if (request.contains('SendAndSaveCopy')) return _successXml;
  if (request.contains('<m:MoveItem>')) return _successXml;
  return _env(
      '<m:X ResponseClass="Error"><m:MessageText>unexpected</m:MessageText></m:X>');
}
