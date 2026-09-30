import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:volgatech_pro/mail/ntlm.dart';

Uint8List _hex(String s) {
  final h = s.replaceAll(RegExp(r'\s'), '');
  return Uint8List.fromList([
    for (var i = 0; i < h.length; i += 2)
      int.parse(h.substring(i, i + 2), radix: 16),
  ]);
}

String _toHex(List<int> b) =>
    b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();

/// CHALLENGE_MESSAGE from MS-NLMP 4.2.4.3 (NTLMv2 examples).
final _specChallenge = _hex('''
4e544c4d53535000 02000000 0c000c00 38000000 33828ae2
0123456789abcdef 0000000000000000 24002400 44000000
060070170000000f
530065007200760065007200
02000c00 44006f006d00610069006e00
01000c00 530065007200760065007200
00000000''');

void main() {
  // MS-NLMP 4.2.4: User / Domain / Password, client challenge 0xaa×8, time 0.
  final client = Uint8List.fromList(List.filled(8, 0xaa));
  final time = Uint8List(8);

  test('parses the spec challenge', () {
    final c = NtlmChallenge.parse(base64Encode(_specChallenge));
    expect(c.targetName, 'Server');
    expect(_toHex(c.serverChallenge), '0123456789abcdef');
    expect(c.targetInfo, hasLength(36));
    expect(c.timestamp, isNull);
  });

  test('NTOWFv2, NTProofStr and LMv2 match the spec', () {
    final c = NtlmChallenge.parse(base64Encode(_specChallenge));
    final key = ntowfV2('Password', 'User', 'Domain');
    expect(_toHex(key), '0c868a403bfd7a93a3001ef22ef02e3f');

    final nt = ntlmV2Response(
      key: key,
      serverChallenge: c.serverChallenge,
      clientChallenge: client,
      time: time,
      targetInfo: c.targetInfo,
    );
    expect(_toHex(nt.sublist(0, 16)), '68cd0ab851e51c96aabc927bebef6a1c');

    final lm = lmV2Response(
        key: key, serverChallenge: c.serverChallenge, clientChallenge: client);
    expect(_toHex(lm), '86c35097ac9cec102554764a57cccc19aaaaaaaaaaaaaaaa');
  });

  test('the AUTHENTICATE message points at the right fields', () {
    final c = NtlmChallenge.parse(base64Encode(_specChallenge));
    final m = base64Decode(ntlmAuthenticate(
      challenge: c,
      user: 'User',
      domain: 'Domain',
      password: 'Password',
      clientChallenge: client,
      time: time,
    ));
    int u16(int at) => m[at] | m[at + 1] << 8;
    int u32(int at) => u16(at) | u16(at + 2) << 16;
    List<int> field(int at) => m.sublist(u32(at + 4), u32(at + 4) + u16(at));
    String text(int at) => String.fromCharCodes([
          for (var i = 0; i < field(at).length; i += 2) field(at)[i],
        ]);

    expect(ascii.decode(m.sublist(0, 7)), 'NTLMSSP');
    expect(u32(8), 3);
    expect(
        _toHex(field(12)), '86c35097ac9cec102554764a57cccc19aaaaaaaaaaaaaaaa');
    expect(
        _toHex(field(20).sublist(0, 16)), '68cd0ab851e51c96aabc927bebef6a1c');
    expect(text(28), 'Domain');
    expect(text(36), 'User');
  });

  test('with a server timestamp the LM response is zeros', () {
    // Target info: MsvAvTimestamp (7) then EOL.
    final info = _hex('07000800 0102030405060708 00000000');
    final c = NtlmChallenge(
      flags: 0xe28a8233,
      serverChallenge: _hex('0123456789abcdef'),
      targetName: 'VOLGATECH',
      targetInfo: info,
    );
    expect(_toHex(c.timestamp!), '0102030405060708');
    final m = base64Decode(
        ntlmAuthenticate(challenge: c, user: 'u', domain: 'D', password: 'p'));
    final lmLen = m[12] | m[13] << 8;
    final lmOff = m[16] | m[17] << 8;
    expect(m.sublist(lmOff, lmOff + lmLen), List.filled(24, 0));
  });

  test('identity: DOMAIN\\user splits, a UPN stays whole', () {
    expect(ntlmIdentity(r'VOLGATECH\konkinna'),
        (domain: 'VOLGATECH', user: 'konkinna'));
    expect(ntlmIdentity('konkinna@volgatech.net'),
        (domain: '', user: 'konkinna@volgatech.net'));
  });

  test('negotiate message is well-formed', () {
    final m = base64Decode(ntlmNegotiate());
    expect(ascii.decode(m.sublist(0, 7)), 'NTLMSSP');
    expect(m[8], 1);
    expect(m, hasLength(32));
  });
}
