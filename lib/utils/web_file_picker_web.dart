import 'dart:js' as js;
import 'dart:async';

// Web-specific implementation using custom JavaScript file picker
Future<Map<String, dynamic>?> pickImageFile() async {
  final completer = Completer<Map<String, dynamic>?>();
  
  try {
    // Call the custom JavaScript function which returns a Promise
    final jsPromise = js.context.callMethod('customFilePicker', []);
    
    // Handle Promise resolution using proper JS interop
    final onSuccess = js.allowInterop((result) {
      if (result != null && !completer.isCompleted) {
        try {
          final jsResult = result as js.JsObject;
          final map = {
            'name': jsResult['name'],
            'size': jsResult['size'],
            'type': jsResult['type'],
            'dataUrl': jsResult['dataUrl'],
          };
          completer.complete(map);
        } catch (e) {
          completer.complete(null);
        }
      } else if (!completer.isCompleted) {
        completer.complete(null);
      }
    });
    
    final onError = js.allowInterop((error) {
      if (!completer.isCompleted) {
        completer.complete(null);
      }
    });
    
    // Use proper Promise.then chaining
    final promise = jsPromise as js.JsObject;
    promise.callMethod('then', [onSuccess]);
    promise.callMethod('catch', [onError]);
    
  } catch (e) {
    completer.complete(null);
  }
  
  return completer.future;
}