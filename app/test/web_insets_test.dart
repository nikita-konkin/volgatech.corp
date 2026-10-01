import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:volgatech_pro/web/insets.dart';

void main() {
  test('Safari’s insets become the padding, less what the keyboard covers', () {
    const insets = EdgeInsets.only(top: 59, bottom: 34);
    final plain = withBrowserInsets(const MediaQueryData(), insets);
    expect(plain.viewPadding, insets);
    expect(plain.padding, insets);

    final typing = withBrowserInsets(
        const MediaQueryData(viewInsets: EdgeInsets.only(bottom: 300)), insets);
    expect(typing.viewPadding, insets);
    expect(typing.padding, const EdgeInsets.only(top: 59));
  });

  test('a bigger inset the engine already knows is kept', () {
    final data = withBrowserInsets(
        const MediaQueryData(viewPadding: EdgeInsets.only(top: 70)),
        const EdgeInsets.only(top: 59, bottom: 34));
    expect(data.viewPadding, const EdgeInsets.only(top: 70, bottom: 34));
  });

  test('turned sideways, the app is laid out between the side insets', () {
    final data = withoutSides(withBrowserInsets(
        const MediaQueryData(size: Size(852, 393)),
        const EdgeInsets.only(left: 59, right: 59, bottom: 21)));
    expect(data.size, const Size(734, 393));
    expect(data.padding, const EdgeInsets.only(bottom: 21));
    expect(data.viewPadding, const EdgeInsets.only(bottom: 21));
  });

  test('?insets= reads top, right, bottom, left', () {
    expect(insetsFromQuery('59,0,34,0'),
        const EdgeInsets.only(top: 59, bottom: 34));
    expect(insetsFromQuery('0,59,21,47'),
        const EdgeInsets.fromLTRB(47, 0, 59, 21));
    expect(insetsFromQuery(null), isNull);
    expect(insetsFromQuery('59,0,34'), isNull);
    expect(insetsFromQuery('59,x,34,0'), isNull);
    expect(insetsFromQuery('-1,0,0,0'), isNull);
  });
}
