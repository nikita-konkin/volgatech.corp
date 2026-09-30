import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:pointycastle/digests/md4.dart';

/// NTLMv2 for HTTP, as Exchange Web Services asks for (MS-NLMP). Only the
/// authentication handshake — HTTP needs no signing or sealing, so no session
/// key is exchanged.

const _signature = [0x4e, 0x54, 0x4c, 0x4d, 0x53, 0x53, 0x50, 0x00]; // NTLMSSP

const _negotiateUnicode = 0x00000001;
const _negotiateOem = 0x00000002;
const _requestTarget = 0x00000004;
const _negotiateNtlm = 0x00000200;
const _alwaysSign = 0x00008000;
const _extendedSessionSecurity = 0x00080000;
const _negotiateTargetInfo = 0x00800000;
const _negotiate128 = 0x20000000;
const _negotiate56 = 0x80000000;

const _clientFlags = _negotiateUnicode |
    _negotiateOem |
    _requestTarget |
    _negotiateNtlm |
    _alwaysSign |
    _extendedSessionSecurity |
    _negotiate128 |
    _negotiate56;

const _avEol = 0;
const _avTimestamp = 7;

/// The NEGOTIATE message, base64 for `Authorization: NTLM …`.
String ntlmNegotiate() {
  final b = BytesBuilder()
    ..add(_signature)
    ..add(_u32(1))
    ..add(_u32(_clientFlags))
    ..add(Uint8List(16)); // empty domain and workstation
  return base64Encode(b.toBytes());
}

/// What the server's CHALLENGE message carries.
class NtlmChallenge {
  const NtlmChallenge({
    required this.flags,
    required this.serverChallenge,
    required this.targetName,
    required this.targetInfo,
  });

  final int flags;
  final Uint8List serverChallenge;

  /// The server's domain (NetBIOS), used when the login names none.
  final String targetName;
  final Uint8List targetInfo;

  /// Parses the base64 blob from `WWW-Authenticate: NTLM …`.
  factory NtlmChallenge.parse(String b64) {
    final m = base64Decode(b64.trim());
    if (m.length < 32 || !_startsWithSignature(m) || _read32(m, 8) != 2) {
      throw const FormatException('not an NTLM challenge');
    }
    final flags = _read32(m, 20);
    Uint8List field(int at) {
      if (m.length < at + 8) return Uint8List(0);
      final len = _read16(m, at);
      final off = _read32(m, at + 4);
      if (off + len > m.length) return Uint8List(0);
      return Uint8List.sublistView(m, off, off + len);
    }

    final name = field(12);
    return NtlmChallenge(
      flags: flags,
      serverChallenge: Uint8List.fromList(m.sublist(24, 32)),
      targetName: flags & _negotiateUnicode != 0
          ? _fromUtf16le(name)
          : latin1.decode(name),
      targetInfo: flags & _negotiateTargetInfo != 0 && m.length >= 48
          ? Uint8List.fromList(field(40))
          : Uint8List(0),
    );
  }

  /// The server's clock from the target info (MsvAvTimestamp), if sent.
  Uint8List? get timestamp {
    var i = 0;
    while (i + 4 <= targetInfo.length) {
      final id = _read16(targetInfo, i);
      final len = _read16(targetInfo, i + 2);
      if (id == _avEol) break;
      if (id == _avTimestamp && len == 8 && i + 12 <= targetInfo.length) {
        return Uint8List.fromList(targetInfo.sublist(i + 4, i + 12));
      }
      i += 4 + len;
    }
    return null;
  }
}

/// Splits `DOMAIN\user`; a UPN (`user@domain`) or a bare name has no domain.
({String domain, String user}) ntlmIdentity(String login) {
  final slash = login.indexOf(r'\');
  if (slash > 0) {
    return (
      domain: login.substring(0, slash),
      user: login.substring(slash + 1)
    );
  }
  return (domain: '', user: login);
}

/// NTOWFv2: the key both responses are made with.
Uint8List ntowfV2(String password, String user, String domain) {
  final ntHash = MD4Digest().process(_utf16le(password));
  return _hmac(ntHash, _utf16le(user.toUpperCase() + domain));
}

/// The AUTHENTICATE message answering [challenge], base64.
///
/// [clientChallenge] and [time] are for tests; normally random and "now".
String ntlmAuthenticate({
  required NtlmChallenge challenge,
  required String user,
  required String domain,
  required String password,
  String workstation = '',
  Uint8List? clientChallenge,
  Uint8List? time,
}) {
  final key = ntowfV2(password, user, domain);
  final client = clientChallenge ?? _random(8);
  final serverTime = challenge.timestamp;
  final timestamp = time ?? serverTime ?? _fileTimeNow();

  final ntResponse = ntlmV2Response(
    key: key,
    serverChallenge: challenge.serverChallenge,
    clientChallenge: client,
    time: timestamp,
    targetInfo: challenge.targetInfo,
  );
  // With a server timestamp the LMv2 response must be zeros (MS-NLMP 3.1.5.1.2).
  final lmResponse = serverTime != null
      ? Uint8List(24)
      : lmV2Response(
          key: key,
          serverChallenge: challenge.serverChallenge,
          clientChallenge: client);

  final unicode = challenge.flags & _negotiateUnicode != 0;
  Uint8List text(String s) => unicode ? _utf16le(s) : latin1.encode(s);
  final domainBytes = text(domain);
  final userBytes = text(user);
  final hostBytes = text(workstation);

  const headerLength = 64;
  var offset = headerLength;
  final header = BytesBuilder()
    ..add(_signature)
    ..add(_u32(3));
  final payload = BytesBuilder();
  void field(Uint8List data) {
    header
      ..add(_u16(data.length))
      ..add(_u16(data.length))
      ..add(_u32(offset));
    payload.add(data);
    offset += data.length;
  }

  // Order in the header is fixed; order in the payload is free.
  final lmAt = header.length;
  header.add(Uint8List(8));
  final ntAt = header.length;
  header.add(Uint8List(8));
  field(domainBytes);
  field(userBytes);
  field(hostBytes);
  final lmOffset = offset;
  payload.add(lmResponse);
  offset += lmResponse.length;
  final ntOffset = offset;
  payload.add(ntResponse);
  offset += ntResponse.length;
  header
    ..add(Uint8List(8)) // no encrypted session key
    ..add(_u32(_clientFlags & challenge.flags | _negotiateNtlm));

  final msg = Uint8List.fromList([...header.toBytes(), ...payload.toBytes()]);
  void patch(int at, int len, int off) {
    msg.setAll(at, [..._u16(len), ..._u16(len), ..._u32(off)]);
  }

  patch(lmAt, lmResponse.length, lmOffset);
  patch(ntAt, ntResponse.length, ntOffset);
  return base64Encode(msg);
}

/// NTProofStr followed by the client blob (MS-NLMP 3.3.2).
Uint8List ntlmV2Response({
  required Uint8List key,
  required Uint8List serverChallenge,
  required Uint8List clientChallenge,
  required Uint8List time,
  required Uint8List targetInfo,
}) {
  final blob = BytesBuilder()
    ..add([1, 1, 0, 0, 0, 0, 0, 0])
    ..add(time)
    ..add(clientChallenge)
    ..add(Uint8List(4))
    ..add(targetInfo)
    ..add(Uint8List(4));
  final temp = blob.toBytes();
  final proof = _hmac(key, Uint8List.fromList([...serverChallenge, ...temp]));
  return Uint8List.fromList([...proof, ...temp]);
}

Uint8List lmV2Response({
  required Uint8List key,
  required Uint8List serverChallenge,
  required Uint8List clientChallenge,
}) =>
    Uint8List.fromList([
      ..._hmac(
          key, Uint8List.fromList([...serverChallenge, ...clientChallenge])),
      ...clientChallenge,
    ]);

// --- bytes ---

Uint8List _hmac(List<int> key, List<int> data) =>
    Uint8List.fromList(Hmac(md5, key).convert(data).bytes);

Uint8List _utf16le(String s) {
  final out = Uint8List(s.length * 2);
  for (var i = 0; i < s.length; i++) {
    final c = s.codeUnitAt(i);
    out[2 * i] = c & 0xff;
    out[2 * i + 1] = c >> 8;
  }
  return out;
}

String _fromUtf16le(List<int> b) => String.fromCharCodes([
      for (var i = 0; i + 1 < b.length; i += 2) b[i] | (b[i + 1] << 8),
    ]);

Uint8List _u16(int v) =>
    Uint8List(2)..buffer.asByteData().setUint16(0, v, Endian.little);
Uint8List _u32(int v) =>
    Uint8List(4)..buffer.asByteData().setUint32(0, v, Endian.little);
int _read16(List<int> b, int at) => b[at] | (b[at + 1] << 8);
int _read32(List<int> b, int at) =>
    b[at] | (b[at + 1] << 8) | (b[at + 2] << 16) | (b[at + 3] << 24);

bool _startsWithSignature(List<int> m) {
  for (var i = 0; i < _signature.length; i++) {
    if (m[i] != _signature[i]) return false;
  }
  return true;
}

final _rng = Random.secure();
Uint8List _random(int n) =>
    Uint8List.fromList([for (var i = 0; i < n; i++) _rng.nextInt(256)]);

/// Windows FILETIME (100 ns since 1601-01-01), little-endian.
Uint8List _fileTimeNow() {
  const epochDiff = 11644473600000000; // µs between 1601 and 1970
  final ticks =
      (DateTime.now().toUtc().microsecondsSinceEpoch + epochDiff) * 10;
  return Uint8List(8)..buffer.asByteData().setUint64(0, ticks, Endian.little);
}
