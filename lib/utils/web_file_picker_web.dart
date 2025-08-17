// Web-specific file picker using modern dart:js_interop
import 'dart:async';
import 'dart:js_interop';
import 'package:web/web.dart' as web;

@JS()
external JSFunction get createFileInput;

@JS()
external void setupFileReader();

// Create a file input element and trigger file selection
Future<Map<String, dynamic>?> pickImageFile() async {
  final completer = Completer<Map<String, dynamic>?>();
  
  try {
    // Create a file input element
    final input = web.document.createElement('input') as web.HTMLInputElement;
    input.type = 'file';
    input.accept = 'image/*';
    input.style.display = 'none';
    
    // Add event listener for file selection
    input.addEventListener('change', (web.Event event) {
      try {
        web.document.body!.removeChild(input);
      } catch (e) {
        // Element might already be removed
      }
      
      final files = input.files;
      if (files != null && files.length > 0) {
        final file = files.item(0)!;
        
        // Create FileReader to read the file
        final reader = web.FileReader();
        
        reader.addEventListener('load', (web.Event loadEvent) {
          final result = reader.result;
          if (result != null) {
            completer.complete({
              'name': file.name,
              'dataUrl': result.toString(),
            });
          } else {
            completer.complete(null);
          }
        }.toJS);
        
        reader.addEventListener('error', (web.Event errorEvent) {
          completer.complete(null);
        }.toJS);
        
        // Read file as data URL
        reader.readAsDataURL(file);
      } else {
        // User cancelled
        completer.complete(null);
      }
    }.toJS);
    
    // Add to DOM temporarily and trigger click
    web.document.body!.appendChild(input);
    input.click();
    
    // Set timeout to handle cases where user doesn't select anything
    Timer(const Duration(seconds: 30), () {
      if (!completer.isCompleted) {
        try {
          web.document.body!.removeChild(input);
        } catch (e) {
          // Element might already be removed
        }
        completer.complete(null);
      }
    });
    
  } catch (e) {
    completer.complete(null);
  }
  
  return completer.future;
}