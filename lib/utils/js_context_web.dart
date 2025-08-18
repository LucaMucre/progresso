// Web implementation using dart:js
import 'dart:js' as js;

void preventPasswordManagerOnLogPage() {
  try {
    // Call JavaScript function to aggressively prevent password manager
    js.context.callMethod('preventPasswordManagerOnLogPage', []);
  } catch (e) {
    // Silently ignore if the function doesn't exist
  }
}