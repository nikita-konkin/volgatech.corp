import 'package:flutter/foundation.dart';

/// Build switch for the built-in mail client:
///
///     flutter build apk --dart-define=MAIL=true
///
/// Without it «Почта» stays OWA in a WebView and the app never stores the
/// corporate password (see [MailCredentialStore.clear] at startup). Never in
/// a browser: the mail server takes no requests from other sites.
const kNativeMail = bool.fromEnvironment('MAIL') && !kIsWeb;

const kMailHost = 'mail.volgatech.net';
const kImapPort = 993;
const kWebMailUrl = 'https://$kMailHost/owa/';
const kEwsUrl = 'https://$kMailHost/EWS/Exchange.asmx';

/// Mail domain of the addresses (name@volgatech.net).
const kMailDomain = 'volgatech.net';

/// The Windows (Active Directory) domain behind Exchange, which still carries
/// the university's old name: accounts sign in as `MARSTU\name` or
/// `name@marstu.net`, not with the mail address. Seen in the NTLM challenge
/// of /EWS/Exchange.asmx (NetBIOS MARSTU, DNS marstu.net).
const kAdDomain = 'MARSTU';
const kAdUpnSuffix = 'marstu.net';
