import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import 'dart:typed_data';
import 'dart:html' as html;
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'services/db_service.dart';

class LogActionPage extends StatefulWidget {
  final ActionTemplate? template;
  final String? selectedCategory;
  final String? selectedArea;
  
  const LogActionPage({
    Key? key, 
    this.template,
    this.selectedCategory,
    this.selectedArea,
  }) : super(key: key);

  @override
  State<LogActionPage> createState() => _LogActionPageState();
}

class _LogActionPageState extends State<LogActionPage> {
  final _durationCtrl = TextEditingController();
  final _notesCtrl    = TextEditingController();
  final _activityNameCtrl = TextEditingController();
  final _imagePicker = ImagePicker();
  bool _loading       = false;
  String? _error;
  File? _selectedImage;
  String? _selectedImageUrl;
  String? _uploadedImageUrl;

  @override
  void initState() {
    super.initState();
    // Pre-fill activity name if we have a template
    if (widget.template != null) {
      _activityNameCtrl.text = widget.template!.name;
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );
      
      if (image != null) {
        setState(() {
          if (kIsWeb) {
            _selectedImageUrl = image.path;
          } else {
            _selectedImage = File(image.path);
          }
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Fehler beim Auswählen des Bildes: $e';
      });
    }
  }

  Future<void> _takePhoto() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );
      
      if (image != null) {
        setState(() {
          if (kIsWeb) {
            _selectedImageUrl = image.path;
          } else {
            _selectedImage = File(image.path);
          }
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Fehler beim Aufnehmen des Fotos: $e';
      });
    }
  }

  Future<String?> _uploadImage() async {
    if (_selectedImage == null && _selectedImageUrl == null) return null;

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception('User nicht angemeldet');

      String fileName;
      Uint8List bytes;

      if (kIsWeb && _selectedImageUrl != null) {
        // For web, we need to handle blob URLs properly
        fileName = '${DateTime.now().millisecondsSinceEpoch}_web_image.jpg';
        
        try {
          // Convert blob URL to bytes using html.HttpRequest
          final response = await html.HttpRequest.request(
            _selectedImageUrl!,
            responseType: 'arraybuffer',
          );
          
          final arrayBuffer = response.response as dynamic;
          bytes = Uint8List.fromList(arrayBuffer.asUint8List());
          
          print('Web image size: ${bytes.length} bytes');
        } catch (e) {
          print('Error converting web image: $e');
          // Fallback to placeholder if conversion fails
          return 'https://via.placeholder.com/400x300/FF0000/FFFFFF?text=Upload+Failed';
        }
      } else if (_selectedImage != null) {
        fileName = '${DateTime.now().millisecondsSinceEpoch}_${_selectedImage!.path.split('/').last}';
        bytes = await _selectedImage!.readAsBytes();
        print('Image size: ${bytes.length} bytes');
      } else {
        throw Exception('Kein Bild ausgewählt');
      }

      final filePath = '${user.id}/$fileName';
      print('Uploading to path: $filePath');

      await Supabase.instance.client.storage
          .from('activity-images')
          .uploadBinary(filePath, bytes);

      final imageUrl = Supabase.instance.client.storage
          .from('activity-images')
          .getPublicUrl(filePath);

      print('Image uploaded successfully: $imageUrl');
      return imageUrl;
    } catch (e) {
      print('Detailed upload error: $e');
      throw Exception('Fehler beim Hochladen des Bildes: $e');
    }
  }

  Future<void> _submitLog() async {
    // Validate inputs
    if (_activityNameCtrl.text.trim().isEmpty) {
      setState(() { _error = 'Bitte gib einen Namen für die Aktivität ein.'; });
      return;
    }

    final raw = _durationCtrl.text.trim();
    int? duration;
    if (raw.isNotEmpty) {
      duration = int.tryParse(raw);
      if (duration == null) {
        setState(() { _error = 'Bitte eine gültige Zahl für Minuten eingeben.'; });
        return;
      }
    }
    setState(() { _loading = true; _error = null; });

    try {
      // Upload image if selected
      String? imageUrl;
      if (_selectedImage != null || _selectedImageUrl != null) {
        try {
          imageUrl = await _uploadImage();
        } catch (e) {
          // If image upload fails, continue without image but show a warning
          print('Image upload failed: $e');
          setState(() {
            _error = 'Bild-Upload fehlgeschlagen: $e\n\nDie Aktivität wird ohne Bild gespeichert.';
          });
          // Don't fail the entire log creation, but show error to user
        }
      }

      ActionLog log;
      
      if (widget.template != null) {
        // Use existing template
        log = await createLog(
          templateId : widget.template!.id,
          durationMin: duration,
          notes      : _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
          imageUrl   : imageUrl,
        );
      } else {
        // Create a quick log without template
        final activityName = _activityNameCtrl.text.trim();
        final notes = _notesCtrl.text.trim();
        final areaName = widget.selectedArea ?? '';
        final category = widget.selectedCategory ?? 'Allgemein';
        
        // Combine activity name, area, and notes for better filtering
        final combinedNotes = notes.isEmpty 
          ? '$activityName ($areaName)' 
          : '$activityName ($areaName): $notes';
        
        log = await createQuickLog(
          activityName: activityName,
          category: category,
          durationMin: duration,
          notes: combinedNotes,
          imageUrl: imageUrl,
        );
      }
      
      // Auf Erfolg hinweisen und zurück zur Liste
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Log angelegt: +${log.earnedXp} XP')),
      );
      Navigator.of(context).pop();  // zurück
    } catch (err) {
      setState(() { _error = 'Fehler beim Speichern: $err'; });
    } finally {
      setState(() { _loading = false; });
    }
  }

  @override
  void dispose() {
    _durationCtrl.dispose();
    _notesCtrl.dispose();
    _activityNameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tpl = widget.template;
    final title = tpl != null ? 'Log: ${tpl.name}' : 'Neue Aktion loggen';
    
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Activity name field (only show if no template)
            if (widget.template == null) ...[
              Text('Aktivitätsname:', style: Theme.of(context).textTheme.bodyMedium),
              TextField(
                controller: _activityNameCtrl,
                decoration: const InputDecoration(
                  hintText: 'z. B. Laufen, Lesen, Meditation...',
                ),
              ),
              const SizedBox(height: 16),
            ],
            
            Text('Dauer in Minuten (optional):', style: Theme.of(context).textTheme.bodyMedium),
            TextField(
              controller: _durationCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(hintText: 'z. B. 45'),
            ),
            const SizedBox(height: 16),
            
            Text('Notiz (optional):', style: Theme.of(context).textTheme.bodyMedium),
            TextField(
              controller: _notesCtrl,
              maxLines: 3,
              decoration: const InputDecoration(hintText: 'Deine Gedanken…'),
            ),
            const SizedBox(height: 16),

            // Image upload section
            Text('Bild hinzufügen (optional):', style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 8),
            
            // Selected image preview
            if (_selectedImage != null || _selectedImageUrl != null) ...[
              Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.withOpacity(0.3)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: kIsWeb && _selectedImageUrl != null
                      ? Image.network(
                          _selectedImageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: Colors.grey[200],
                              child: const Center(
                                child: Icon(Icons.broken_image, color: Colors.grey, size: 48),
                              ),
                            );
                          },
                        )
                      : Image.file(
                          _selectedImage!,
                          fit: BoxFit.cover,
                        ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickImage,
                      icon: const Icon(Icons.edit),
                      label: const Text('Bild ändern'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        setState(() {
                          _selectedImage = null;
                          _selectedImageUrl = null;
                        });
                      },
                      icon: const Icon(Icons.delete, color: Colors.red),
                      label: const Text('Entfernen', style: TextStyle(color: Colors.red)),
                    ),
                  ),
                ],
              ),
            ] else ...[
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickImage,
                      icon: const Icon(Icons.photo_library),
                      label: const Text('Aus Galerie'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _takePhoto,
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Foto aufnehmen'),
                    ),
                  ),
                ],
              ),
            ],
            
            const SizedBox(height: 24),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            ElevatedButton(
              onPressed: _loading ? null : _submitLog,
              child: _loading
                ? const SizedBox(
                    height: 16, width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Log speichern'),
            ),
          ],
        ),
      ),
    );
  }
}