// Fallback for non-web platforms. No-ops.

Future<String?> readLocalStorage(String key) async {
  return null;
}

Future<void> writeLocalStorage(String key, String value) async {
  // no-op on non-web
}

