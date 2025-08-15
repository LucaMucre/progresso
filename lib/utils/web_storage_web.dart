// Web implementation backed by window.localStorage
import 'dart:html' as html;

Future<String?> readLocalStorage(String key) async {
  try {
    return html.window.localStorage[key];
  } catch (_) {
    return null;
  }
}

Future<void> writeLocalStorage(String key, String value) async {
  try {
    html.window.localStorage[key] = value;
  } catch (_) {
    // ignore
  }
}

