import 'dart:typed_data';

import '../data/volgatech_api.dart';
import 'cache.dart';

/// Person photos, kept on disk so the avatar appears instantly and offline
/// instead of being downloaded on every launch.
///
/// The photo file name is a GUID that changes when the photo does, so a cached
/// copy never needs revalidating.
class PhotoStore {
  PhotoStore(this._api, this._cache);
  final VolgatechApi _api;
  final JsonCache _cache;

  // One lookup per name, shared by every avatar on screen.
  final Map<String, Future<Uint8List?>> _pending = {};

  Future<Uint8List?> load(String photoName) =>
      _pending[photoName] ??= _load(photoName);

  Future<Uint8List?> _load(String photoName) async {
    final key = 'photo_$photoName';
    final saved = await _cache.getBytes(key);
    if (saved != null) return saved;
    try {
      final bytes = await _api.getPhotoBytes(photoName);
      await _cache.putBytes(key, bytes);
      return bytes;
    } catch (_) {
      // Offline or missing: forget the failure so the next open retries.
      // The removed value is this very future, so there is nothing to await.
      // ignore: unawaited_futures
      _pending.remove(photoName);
      return null;
    }
  }

  /// Drop the in-memory copies (the disk copies go with [JsonCache.clear]).
  void clear() => _pending.clear();
}
