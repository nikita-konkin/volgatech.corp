import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/photo_store.dart';

/// Round profile photo from [PhotoStore], decoded at the size it is drawn
/// (not the full camera resolution), with an icon while missing or loading.
class PersonAvatar extends StatefulWidget {
  const PersonAvatar({
    super.key,
    required this.photoName,
    required this.radius,
    required this.backgroundColor,
    required this.iconColor,
    required this.iconSize,
  });

  final String? photoName;
  final double radius;
  final Color backgroundColor;
  final Color iconColor;
  final double iconSize;

  @override
  State<PersonAvatar> createState() => _PersonAvatarState();
}

class _PersonAvatarState extends State<PersonAvatar> {
  Future<Uint8List?>? _photo;

  @override
  void initState() {
    super.initState();
    _photo = _load();
  }

  @override
  void didUpdateWidget(covariant PersonAvatar old) {
    super.didUpdateWidget(old);
    if (old.photoName != widget.photoName) _photo = _load();
  }

  Future<Uint8List?>? _load() {
    final name = widget.photoName;
    if (name == null || name.isEmpty) return null;
    return context.read<PhotoStore>().load(name);
  }

  @override
  Widget build(BuildContext context) {
    // Width only, so the aspect ratio is kept; staff photos are portrait, so
    // the width is the side the circle crops to.
    final px =
        (widget.radius * 2 * MediaQuery.devicePixelRatioOf(context)).round();
    return FutureBuilder<Uint8List?>(
      future: _photo,
      builder: (context, snap) {
        final bytes = snap.data;
        return CircleAvatar(
          radius: widget.radius,
          backgroundColor: widget.backgroundColor,
          backgroundImage: bytes == null
              ? null
              : ResizeImage(MemoryImage(bytes), width: px),
          child: bytes == null
              ? Icon(Icons.person, size: widget.iconSize, color: widget.iconColor)
              : null,
        );
      },
    );
  }
}
