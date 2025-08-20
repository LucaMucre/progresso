/// Stub implementation for non-web platforms
void downloadFile(String content, String filename, String mimeType) {
  throw UnsupportedError('File download is only supported on web platform');
}