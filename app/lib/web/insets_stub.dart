import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Not in a browser: the platform tells the app its insets itself.
ValueListenable<EdgeInsets> browserInsets() => _none;

final _none = ValueNotifier(EdgeInsets.zero);
