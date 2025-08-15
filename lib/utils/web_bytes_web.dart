// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';

// Web implementation: fetch blob/asset URL into bytes.
Future<Uint8List?> fetchBytesFromUrl(String url) async {
  try {
    final resp = await html.HttpRequest.request(
      url,
      responseType: 'arraybuffer',
    );
    final buffer = resp.response as dynamic;
    return Uint8List.fromList(buffer.asUint8List());
  } catch (_) {
    return null;
  }
}

