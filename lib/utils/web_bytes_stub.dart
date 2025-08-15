import 'dart:typed_data';

// Non-web fallback. Returns null to indicate unsupported environment.
Future<Uint8List?> fetchBytesFromUrl(String url) async {
  return null;
}

