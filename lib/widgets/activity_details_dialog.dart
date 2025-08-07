import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import 'dart:typed_data';
import 'dart:html' as html;
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../services/db_service.dart';

class ActivityDetailsDialog extends StatefulWidget {
  final ActionLog log;
  final VoidCallback? onUpdate;

  const ActivityDetailsDialog({
    Key? key,
    required this.log,
    this.onUpdate,
  }) : super(key: key);

  @override
  State<ActivityDetailsDialog> createState() => _ActivityDetailsDialogState();
}

class _ActivityDetailsDialogState extends State<ActivityDetailsDialog> {
  final _durationCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _imagePicker = ImagePicker();
  
  bool _isEditing = false;
  bool _isLoading = false;
  String? _error;
  File? _selectedImage;
  String? _selectedImageUrl;
  String? _uploadedImageUrl;

  @override
  void initState() {
    super.initState();
    _durationCtrl.text = widget.log.durationMin?.toString() ?? '';
    _notesCtrl.text = widget.log.notes ?? '';
  }

  @override
  void dispose() {
    _durationCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
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

  Future<String?> _uploadImage() async {
    if (_selectedImage == null && _selectedImageUrl == null) return null;

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception('User nicht angemeldet');

      String fileName;
      Uint8List bytes;

      if (kIsWeb && _selectedImageUrl != null) {
        fileName = '${DateTime.now().millisecondsSinceEpoch}_web_image.jpg';
        
        try {
          final response = await html.HttpRequest.request(
            _selectedImageUrl!,
            responseType: 'arraybuffer',
          );
          
          final arrayBuffer = response.response as dynamic;
          bytes = Uint8List.fromList(arrayBuffer.asUint8List());
        } catch (e) {
          print('Error converting web image: $e');
          return 'https://via.placeholder.com/400x300/FF0000/FFFFFF?text=Upload+Failed';
        }
      } else if (_selectedImage != null) {
        fileName = '${DateTime.now().millisecondsSinceEpoch}_${_selectedImage!.path.split('/').last}';
        bytes = await _selectedImage!.readAsBytes();
      } else {
        throw Exception('Kein Bild ausgewählt');
      }

      final filePath = '${user.id}/$fileName';
      await Supabase.instance.client.storage
          .from('activity-images')
          .uploadBinary(filePath, bytes);

      final imageUrl = Supabase.instance.client.storage
          .from('activity-images')
          .getPublicUrl(filePath);

      return imageUrl;
    } catch (e) {
      print('Upload error: $e');
      throw Exception('Fehler beim Hochladen des Bildes: $e');
    }
  }

  Future<void> _saveChanges() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Upload new image if selected
      String? imageUrl;
      if (_selectedImage != null || _selectedImageUrl != null) {
        try {
          imageUrl = await _uploadImage();
        } catch (e) {
          print('Image upload failed: $e');
          setState(() {
            _error = 'Bild-Upload fehlgeschlagen: $e';
          });
        }
      }

      // Parse duration
      int? duration;
      if (_durationCtrl.text.trim().isNotEmpty) {
        duration = int.tryParse(_durationCtrl.text.trim());
        if (duration == null) {
          setState(() {
            _error = 'Bitte eine gültige Zahl für Minuten eingeben.';
          });
          return;
        }
      }

      // Update the log in database
      final updateData = <String, dynamic>{
        'duration_min': duration,
        'notes': _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      };

      if (imageUrl != null) {
        updateData['image_url'] = imageUrl;
      }

      await Supabase.instance.client
          .from('action_logs')
          .update(updateData)
          .eq('id', widget.log.id);

      setState(() {
        _isEditing = false;
        _isLoading = false;
      });

      // Call the update callback to refresh the parent
      widget.onUpdate?.call();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Änderungen gespeichert!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (err) {
      setState(() {
        _error = 'Fehler beim Speichern: $err';
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteLog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Aktivität löschen'),
        content: const Text('Möchtest du diese Aktivität wirklich löschen?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        _isLoading = true;
      });

      try {
        await Supabase.instance.client
            .from('action_logs')
            .delete()
            .eq('id', widget.log.id);

        widget.onUpdate?.call();
        Navigator.of(context).pop();
      } catch (err) {
        setState(() {
          _error = 'Fehler beim Löschen: $err';
          _isLoading = false;
        });
      }
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}.${date.month}.${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        width: double.infinity,
        height: MediaQuery.of(context).size.height * 0.9,
        constraints: const BoxConstraints(maxWidth: 800),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Aktivitäts-Details',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (!_isEditing) ...[
                    IconButton(
                      onPressed: () => setState(() => _isEditing = true),
                      icon: const Icon(Icons.edit),
                      tooltip: 'Bearbeiten',
                    ),
                    IconButton(
                      onPressed: _deleteLog,
                      icon: const Icon(Icons.delete, color: Colors.red),
                      tooltip: 'Löschen',
                    ),
                  ],
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Image section
                    if (widget.log.imageUrl != null || _selectedImage != null || _selectedImageUrl != null) ...[
                      Container(
                        height: 300,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.withOpacity(0.3)),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: _selectedImage != null || _selectedImageUrl != null
                              ? (kIsWeb && _selectedImageUrl != null
                                  ? Image.network(
                                      _selectedImageUrl!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) {
                                        return _buildImageErrorWidget();
                                      },
                                    )
                                  : Image.file(
                                      _selectedImage!,
                                      fit: BoxFit.cover,
                                    ))
                              : Image.network(
                                  widget.log.imageUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return _buildImageErrorWidget();
                                  },
                                ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Edit image button
                    if (_isEditing) ...[
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _pickImage,
                              icon: const Icon(Icons.photo_library),
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
                              label: const Text('Bild entfernen', style: TextStyle(color: Colors.red)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Activity details
                    _buildDetailSection(
                      title: 'Datum',
                      value: _formatDate(widget.log.occurredAt),
                      isEditable: false,
                    ),
                    
                    _buildDetailSection(
                      title: 'XP verdient',
                      value: '${widget.log.earnedXp}',
                      isEditable: false,
                    ),

                    if (_isEditing) ...[
                      _buildDetailSection(
                        title: 'Dauer (Minuten)',
                        value: _durationCtrl.text,
                        isEditable: true,
                        controller: _durationCtrl,
                        keyboardType: TextInputType.number,
                      ),
                      
                      _buildDetailSection(
                        title: 'Notizen',
                        value: _notesCtrl.text,
                        isEditable: true,
                        controller: _notesCtrl,
                        maxLines: 3,
                      ),
                    ] else ...[
                      if (widget.log.durationMin != null)
                        _buildDetailSection(
                          title: 'Dauer',
                          value: '${widget.log.durationMin} Minuten',
                          isEditable: false,
                        ),
                      
                      if (widget.log.notes != null && widget.log.notes!.isNotEmpty)
                        _buildDetailSection(
                          title: 'Notizen',
                          value: widget.log.notes!,
                          isEditable: false,
                        ),
                    ],

                    // Error message
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.withOpacity(0.3)),
                        ),
                        child: Text(
                          _error!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Footer with action buttons
            if (_isEditing)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.05),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isLoading ? null : () {
                          setState(() {
                            _isEditing = false;
                            _durationCtrl.text = widget.log.durationMin?.toString() ?? '';
                            _notesCtrl.text = widget.log.notes ?? '';
                            _selectedImage = null;
                            _selectedImageUrl = null;
                          });
                        },
                        child: const Text('Abbrechen'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _saveChanges,
                        child: _isLoading
                            ? const SizedBox(
                                height: 16,
                                width: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Speichern'),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailSection({
    required String title,
    required String value,
    required bool isEditable,
    TextEditingController? controller,
    TextInputType? keyboardType,
    int? maxLines,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          if (isEditable && controller != null)
            TextField(
              controller: controller,
              keyboardType: keyboardType,
              maxLines: maxLines ?? 1,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Text(
                value,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildImageErrorWidget() {
    return Container(
      color: Colors.grey[200],
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.image,
              color: Colors.grey,
              size: 48,
            ),
            SizedBox(height: 8),
            Text(
              'Bild nicht verfügbar',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
} 