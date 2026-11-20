import 'package:flutter/services.dart';

/// System settings that can let mail checks run on Honor and Huawei phones.
abstract interface class MailBackgroundSettings {
  Future<({bool hasAppLaunch, bool canRequestBatteryExemption})> status();
  Future<bool> openAppLaunch();
  Future<bool> requestBatteryExemption();
}

/// Reads device restrictions and opens Android's settings through the app host.
class AndroidMailBackgroundSettings implements MailBackgroundSettings {
  const AndroidMailBackgroundSettings();

  static const _channel = MethodChannel('volgatech/mail_background');

  Future<T?> _invoke<T>(String method) async {
    try {
      return await _channel.invokeMethod<T>(method);
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  @override
  Future<({bool hasAppLaunch, bool canRequestBatteryExemption})>
      status() async {
    final value = await _invoke<Map<Object?, Object?>>('status');
    return (
      hasAppLaunch: value?['hasAppLaunch'] == true,
      canRequestBatteryExemption: value?['canRequestBatteryExemption'] == true,
    );
  }

  @override
  Future<bool> openAppLaunch() async =>
      await _invoke<bool>('openAppLaunch') ?? false;

  @override
  Future<bool> requestBatteryExemption() async =>
      await _invoke<bool>('requestBatteryExemption') ?? false;
}
