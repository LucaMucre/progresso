import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import 'package:flutter_image_compress/flutter_image_compress.dart';
// Avoid direct dart:html in non-web builds; use conditional helper instead
import '../utils/web_bytes_stub.dart'
    if (dart.library.html) '../utils/web_bytes_web.dart' as web_bytes;
import '../utils/web_file_picker_stub.dart'
    if (dart.library.html) '../utils/web_file_picker_web.dart' as web_file_picker;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/db_service.dart' as db_service;
import '../models/action_models.dart' as models;
import '../services/anonymous_user_service.dart';
import '../services/life_areas_service.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'optimized_image.dart';
import '../utils/image_utils.dart';

// Fullscreen image viewer widget
class _FullscreenImageViewer extends StatelessWidget {
  final String? imageUrl;
  final File? imageFile;
  
  const _FullscreenImageViewer({this.imageUrl, this.imageFile})
      : assert(imageUrl != null || imageFile != null, 'Either imageUrl or imageFile must be provided');
  
  bool _isBase64DataUrl(String url) {
    return url.startsWith('data:image/') && url.contains('base64,');
  }

  Widget _buildFullscreenImage(String imageUrl) {
    return ImageUtils.buildImageWidget(
      imageUrl: imageUrl,
      fit: BoxFit.contain,
      errorWidget: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error, color: Colors.white, size: 64),
            SizedBox(height: 16),
            Text(
              'Failed to load image',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Center(
        child: InteractiveViewer(
          child: imageUrl != null
              ? _buildFullscreenImage(imageUrl!)
              : Image.file(
                  imageFile!,
                  fit: BoxFit.contain,
                ),
        ),
      ),
    );
  }
}

class ActivityDetailsDialog extends StatefulWidget {
  final models.ActionLog log;
  final VoidCallback? onUpdate;

  const ActivityDetailsDialog({
    super.key,
    required this.log,
    this.onUpdate,
  });

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
  String _activityTitle = 'Activity';
  Color? _areaColor;

  @override
  void initState() {
    super.initState();
    _durationCtrl.text = widget.log.durationMin?.toString() ?? '';
    _notesCtrl.text = widget.log.notes ?? '';
    _initTitle();
    _initAreaColor();
    
    // Debug: Check if imageUrl is available
    if (kDebugMode) {
      debugPrint('ActivityDetailsDialog - imageUrl: ${widget.log.imageUrl}');
    }
  }

  bool _isBase64DataUrl(String url) {
    return url.startsWith('data:image/') && url.contains('base64,');
  }

  Widget _buildImageWidget({
    required String imageUrl,
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
    BorderRadius? borderRadius,
    Widget? errorWidget,
  }) {
    Widget image = ImageUtils.buildImageWidget(
      imageUrl: imageUrl,
      width: width,
      height: height,
      fit: fit,
      errorWidget: errorWidget ?? _buildImageErrorWidget(),
    );
    
    if (borderRadius != null && ImageUtils.isBase64DataUrl(imageUrl)) {
      // Only apply ClipRRect to base64 images, network images handle borderRadius internally
      image = ClipRRect(
        borderRadius: borderRadius,
        child: image,
      );
    }
    
    return image;
  }

  void _showFullscreenImage({String? imageUrl, File? imageFile}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _FullscreenImageViewer(
          imageUrl: imageUrl,
          imageFile: imageFile,
        ),
        fullscreenDialog: true,
      ),
    );
  }

  void _initAreaColor() {
    final notes = widget.log.notes;
    if (notes == null || notes.isEmpty) return;
    try {
      final obj = jsonDecode(notes);
      if (obj is Map<String, dynamic>) {
        final areaName = obj['area'] as String?;
        final category = obj['category'] as String?;
        if (areaName != null || category != null) {
          final user = Supabase.instance.client.auth.currentUser;
          if (user != null) {
            // For authenticated users, query the database with subcategory support
            Supabase.instance.client
                .from('life_areas')
                .select('id,name,category,color,parent_id')
                .eq('user_id', user.id)
                .then((res) {
              if (!mounted) return;
              final areas = res as List;
              final areaMap = <String, Map<String, dynamic>>{};
              
              // Build area map with both exact and lowercase keys
              for (final area in areas) {
                final name = area['name'] as String?;
                if (name != null) {
                  areaMap[name] = area;
                  areaMap[name.toLowerCase()] = area;
                }
              }
              
              final searchName = areaName?.trim() ?? category?.trim() ?? '';
              if (searchName.isNotEmpty) {
                // Try both exact match and lowercase match
                final foundArea = areaMap[searchName] ?? areaMap[searchName.toLowerCase()];
                if (foundArea != null) {
                  String colorString;
                  
                  // If this is a subcategory (has parent_id), use parent's color
                  if (foundArea['parent_id'] != null) {
                    // Find parent area and use its color
                    final parentArea = areas.firstWhere(
                      (area) => area['id'] == foundArea['parent_id'],
                      orElse: () => foundArea, // Fallback to own color
                    );
                    colorString = parentArea['color'] as String;
                  } else {
                    colorString = foundArea['color'] as String;
                  }
                  
                  setState(() {
                    _areaColor = Color(int.parse(colorString.replaceAll('#', '0xFF')));
                  });
                }
              }
            }).catchError((_) {});
          } else {
            // For anonymous users, load from local storage
            _loadAreaColorForAnonymousUser(areaName, category);
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _loadAreaColorForAnonymousUser(String? areaName, String? category) async {
    try {
      final areas = await LifeAreasService.getLifeAreas();
      final areaMap = <String, LifeArea>{};
      final allAreas = <LifeArea>[...areas]; // Start with top-level areas
      
      // First add all top-level areas
      for (final a in areas) {
        areaMap[a.name] = a;
        areaMap[a.name.toLowerCase()] = a; // Also add lowercase version for case-insensitive matching
      }
      
      // Then recursively add all subcategories
      for (final area in areas) {
        try {
          final childAreas = await LifeAreasService.getChildAreas(area.id);
          for (final child in childAreas) {
            allAreas.add(child); // Add to complete areas list for parent lookup
            areaMap[child.name] = child;
            areaMap[child.name.toLowerCase()] = child; // Also add lowercase version
          }
        } catch (e) {
          if (kDebugMode) {
            print('Error loading child areas for ${area.name}: $e');
          }
        }
      }
      
      final searchName = areaName?.trim() ?? category?.trim() ?? '';
      if (searchName.isNotEmpty) {
        // Try both exact match and lowercase match
        final areaObj = areaMap[searchName] ?? areaMap[searchName.toLowerCase()];
        if (areaObj != null) {
          if (mounted) {
            String colorString;
            
            // If this is a subcategory (has parentId), use parent's color
            if (areaObj.parentId != null) {
              // Find parent area and use its color
              final parentArea = allAreas.firstWhere(
                (area) => area.id == areaObj.parentId,
                orElse: () => areaObj, // Fallback to own color
              );
              colorString = parentArea.color;
            } else {
              colorString = areaObj.color;
            }
            
            setState(() {
              _areaColor = Color(int.parse(colorString.replaceAll('#', '0xFF')));
            });
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _initTitle() async {
    // Prefer the user-defined activity name if present (also try notes JSON fallback)
    final existing = widget.log.activityName;
    if (existing != null && existing.trim().isNotEmpty) {
      setState(() {
        _activityTitle = existing.trim();
      });
      return;
    }

    // Try to extract title from notes JSON for anonymous users
    final notes = widget.log.notes;
    if (notes != null && notes.isNotEmpty) {
      try {
        final obj = jsonDecode(notes);
        if (obj is Map<String, dynamic>) {
          final title = obj['title'] as String?;
          if (title != null && title.trim().isNotEmpty) {
            if (mounted) {
              setState(() {
                _activityTitle = title.trim();
              });
            }
            return;
          }
        }
      } catch (_) {}
    }

    // Fallback to template name if available (for authenticated users)
    final user = Supabase.instance.client.auth.currentUser;
    final templateId = widget.log.templateId;
    if (user != null && templateId != null) {
      try {
        final res = await Supabase.instance.client
            .from('action_templates')
            .select('name')
            .eq('id', templateId)
            .single();
        final name = (res['name'] as String?)?.trim();
        if (name != null && name.isNotEmpty) {
          if (mounted) {
            setState(() {
              _activityTitle = name;
            });
          }
          return;
        }
      } catch (e) {
        // ignore and keep default title
      }
    }
    // Default
    if (mounted) {
      setState(() {
        _activityTitle = 'Activity';
      });
    }
  }

  Widget _buildNotesOrPlain(String value) {
    // Try parse Quill Delta JSON; fallback to plain text
    try {
      final dynamic parsed = jsonDecode(value);
      if (parsed is Map<String, dynamic>) {
        final delta = parsed['delta'];
        if (delta is List) {
          final doc = quill.Document.fromJson(delta);
          final controller = quill.QuillController(
            document: doc,
            selection: const TextSelection.collapsed(offset: 0),
          );
          return SizedBox(
            height: 220,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: IgnorePointer(
                ignoring: true,
                child: quill.QuillEditor.basic(
                  controller: controller,
                  config: const quill.QuillEditorConfig(
                    padding: EdgeInsets.zero,
                  ),
                ),
              ),
            ),
          );
        }
      } else if (parsed is List) {
        final doc = quill.Document.fromJson(parsed);
        final controller = quill.QuillController(
          document: doc,
          selection: const TextSelection.collapsed(offset: 0),
        );
        return SizedBox(
          height: 220,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: IgnorePointer(
              ignoring: true,
              child: quill.QuillEditor.basic(
                controller: controller,
                config: const quill.QuillEditorConfig(
                  padding: EdgeInsets.zero,
                ),
              ),
            ),
          ),
        );
      }
    } catch (_) {
      // not a json delta -> show as plain text
    }
    return Container(
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
    );
  }

  @override
  void dispose() {
    _durationCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      if (kIsWeb) {
        // Use custom web file picker to avoid password manager popup
        final result = await web_file_picker.pickImageFile();
        if (result != null) {
          setState(() {
            _selectedImageUrl = result['dataUrl'];
            _selectedImage = null;
          });
        }
      } else {
        // For Mobile: Use standard ImagePicker
        final XFile? image = await _imagePicker.pickImage(
          source: ImageSource.gallery,
          maxWidth: 1024,
          maxHeight: 1024,
          imageQuality: 80,
        );
        
        if (image != null) {
          setState(() {
            _selectedImage = File(image.path);
            _selectedImageUrl = null;
          });
        }
      }
    } catch (e) {
      setState(() {
        _error = 'Error selecting image: $e';
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
          final fetched = await web_bytes.fetchBytesFromUrl(_selectedImageUrl!);
          if (fetched == null) {
            return 'https://via.placeholder.com/400x300/FF0000/FFFFFF?text=Upload+Failed';
          }
          bytes = fetched;
        } catch (e) {
          if (kDebugMode) debugPrint('Error converting web image: $e');
          return 'https://via.placeholder.com/400x300/FF0000/FFFFFF?text=Upload+Failed';
        }
      } else if (_selectedImage != null) {
        fileName = '${DateTime.now().millisecondsSinceEpoch}_${_selectedImage!.path.split('/').last}';
        bytes = await _selectedImage!.readAsBytes();
        if (bytes.length > 800000) {
          try {
            final result = await FlutterImageCompress.compressWithList(
              bytes,
              quality: 80,
              minWidth: 1600,
              minHeight: 1600,
            );
            if (result.isNotEmpty) bytes = Uint8List.fromList(result);
          } catch (_) {}
        }
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
      if (kDebugMode) debugPrint('Upload error: $e');
      throw Exception('Error uploading image: $e');
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
          if (kDebugMode) debugPrint('Image upload failed: $e');
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
          content: Text('Changes saved!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (err) {
      setState(() {
        _error = 'Error saving: $err';
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteLog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
            title: const Text('Delete activity'),
            content: const Text('Do you really want to delete this activity?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        _isLoading = true;
      });

      try {
        final user = Supabase.instance.client.auth.currentUser;
        
        if (user != null) {
          // Authenticated user - delete from database
          await Supabase.instance.client
              .from('action_logs')
              .delete()
              .eq('id', widget.log.id);
        } else {
          // Anonymous user - delete from local storage
          await db_service.deleteLog(widget.log.id);
        }

        widget.onUpdate?.call();
        Navigator.of(context).pop();
      } catch (err) {
        setState(() {
          _error = 'Error deleting: $err';
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
                color: (_areaColor ?? Theme.of(context).primaryColor).withValues(alpha: 0.12),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _activityTitle,
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 2),
                        Text(
          'Activity details',
                          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                color: Colors.black.withValues(alpha: 0.6),
                              ),
                        ),
                      ],
                    ),
                  ),
                  if (!_isEditing) ...[
                    IconButton(
                      onPressed: () => setState(() => _isEditing = true),
                      icon: const Icon(Icons.edit),
                      tooltip: 'Edit',
                    ),
                    IconButton(
                      onPressed: _deleteLog,
                      icon: const Icon(Icons.delete, color: Colors.red),
                      tooltip: 'Delete',
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
                      GestureDetector(
                        onTap: () {
                          // Determine which image to show (URL or file)
                          if (_selectedImage != null) {
                            _showFullscreenImage(imageFile: _selectedImage);
                          } else if (_selectedImageUrl != null) {
                            _showFullscreenImage(imageUrl: _selectedImageUrl);
                          } else if (widget.log.imageUrl != null) {
                            _showFullscreenImage(imageUrl: widget.log.imageUrl);
                          }
                        },
                        child: Container(
                          height: 300,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                          ),
                          child: Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: _selectedImage != null || _selectedImageUrl != null
                                    ? (kIsWeb && _selectedImageUrl != null
                                        ? OptimizedImage(
                                            imageUrl: _selectedImageUrl!,
                                            fit: BoxFit.cover,
                                            width: double.infinity,
                                            height: 300,
                                            memCacheWidth: 800,
                                            memCacheHeight: 600,
                                            borderRadius: BorderRadius.circular(12),
                                            errorWidget: _buildImageErrorWidget(),
                                          )
                                        : Image.file(
                                            _selectedImage!,
                                            fit: BoxFit.cover,
                                            width: double.infinity,
                                            height: double.infinity,
                                          ))
                                    : _buildImageWidget(
                                        imageUrl: widget.log.imageUrl!,
                                        fit: BoxFit.cover,
                                        width: double.infinity,
                                        height: 300,
                                        borderRadius: BorderRadius.circular(12),
                                        errorWidget: _buildImageErrorWidget(),
                                      ),
                              ),
                              // Overlay icon to indicate clickability
                              Positioned(
                                top: 8,
                                right: 8,
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.5),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Icon(
                                    Icons.fullscreen,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ],
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
                              label: const Text('Change Image'),
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
                              label: const Text('Remove Image', style: TextStyle(color: Colors.red)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Activity details condensed row
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: _buildDetailChip(
                              label: 'Date',
                              value: _formatDate(widget.log.occurredAt),
                              icon: Icons.event,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildDetailChip(
                              label: 'XP',
                              value: '${widget.log.earnedXp}',
                              icon: Icons.star,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildDetailChip(
                              label: 'Duration',
                              value: widget.log.durationMin != null ? '${widget.log.durationMin} min' : '-',
                              icon: Icons.timer_outlined,
                            ),
                          ),
                        ],
                      ),
                    ),

                    if (_isEditing) ...[
                      _buildDetailSection(
                        title: 'Duration (Minutes)',
                        value: _durationCtrl.text,
                        isEditable: true,
                        controller: _durationCtrl,
                        keyboardType: TextInputType.number,
                      ),
                      
                      _buildDetailSection(
                        title: 'Notes',
                        value: _notesCtrl.text,
                        isEditable: true,
                        controller: _notesCtrl,
                        maxLines: 3,
                      ),
                    ] else ...[
                      // Dauer separat nicht mehr nötig (oben zusammengefasst)
                      
                      if (widget.log.notes != null && widget.log.notes!.isNotEmpty)
                        _buildDetailSection(
                          title: 'Notes',
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
                          color: Colors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
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
                  color: Colors.grey.withValues(alpha: 0.05),
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
            child: const Text('Cancel'),
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
                            : const Text('Save'),
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
              autofillHints: const [],
              enableSuggestions: false,
              autocorrect: false,
              maxLines: maxLines ?? 1,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
            )
          else
            _buildNotesOrPlain(value),
        ],
      ),
    );
  }

  Widget _buildDetailChip({required String label, required String value, required IconData icon}) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: theme.textTheme.labelSmall?.copyWith(color: Colors.grey[600])),
                const SizedBox(height: 2),
                Text(value, style: theme.textTheme.bodyMedium),
              ],
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
              'Image not available',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
} 