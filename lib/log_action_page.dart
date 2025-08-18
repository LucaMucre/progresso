import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_image_compress/flutter_image_compress.dart';
// Avoid direct dart:html in non-web builds; use conditional helper instead
import 'utils/web_bytes_stub.dart'
    if (dart.library.html) 'utils/web_bytes_web.dart' as web_bytes;
import 'utils/web_file_picker_stub.dart'
    if (dart.library.html) 'utils/web_file_picker_web.dart' as web_file_picker;
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:js' as js if (dart.library.html) 'dart:js';
import 'services/db_service.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'services/level_up_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'services/app_state.dart';
import 'services/offline_cache.dart';
import 'navigation.dart';
import 'home_shell.dart';

class LogActionPage extends StatefulWidget {
  final ActionTemplate? template;
  final String? selectedCategory;
  final String? selectedArea;
  final String? areaColorHex;
  final String? areaIcon;
  final ScrollController? scrollController;
  final bool isModal;
  
  const LogActionPage({
    super.key, 
    this.template,
    this.selectedCategory,
    this.selectedArea,
    this.areaColorHex,
    this.areaIcon,
    this.scrollController,
    this.isModal = false,
  });

  @override
  State<LogActionPage> createState() => _LogActionPageState();
}

class _LogActionPageState extends State<LogActionPage> {
  final _durationCtrl = TextEditingController();
  final _notesCtrl    = TextEditingController();
  final FocusNode _notesFocusNode = FocusNode();
  final FocusNode _quillFocusNode = FocusNode();
  final ScrollController _quillScrollController = ScrollController();
  late final quill.QuillController _quillCtrl;
  final _activityNameCtrl = TextEditingController();
  final _imagePicker = ImagePicker();
  bool _loading       = false;
  String? _error;
  File? _selectedImage;
  String? _selectedImageUrl;

  @override
  void initState() {
    super.initState();
    // Pre-fill activity name if we have a template
    if (widget.template != null) {
      _activityNameCtrl.text = widget.template!.name;
    }
    _quillCtrl = quill.QuillController.basic();
    
    // On web, call JavaScript to prevent password manager
    if (kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _preventPasswordManager();
      });
    }
  }
  
  void _preventPasswordManager() {
    if (kIsWeb) {
      try {
        // Call JavaScript function to aggressively prevent password manager
        js.context.callMethod('preventPasswordManagerOnLogPage', []);
      } catch (e) {
        // Silently ignore if the function doesn't exist
      }
    }
  }



  Future<void> _showImageSourceDialog() async {
    // Navigate to completely separate page for image picking to avoid password popup
    final result = await Navigator.of(context).push<dynamic>(
      MaterialPageRoute(
        builder: (context) => const _ImagePickerPage(),
        fullscreenDialog: true,
      ),
    );
    
    if (result != null) {
      await _handleImageResult(result);
    }
  }
  
  Future<void> _handleImageResult(dynamic image) async {
    if (kIsWeb) {
      if (image is _WebFile) {
        // For web: use custom file data
        final url = image.path; // Already a data URL
        setState(() {
          _selectedImage = null;
          _selectedImageUrl = url;
        });
      } else if (image is XFile) {
        // Fallback for regular XFile
        final bytes = await image.readAsBytes();
        final url = 'data:image/jpeg;base64,${base64Encode(bytes)}';
        setState(() {
          _selectedImage = null;
          _selectedImageUrl = url;
        });
      }
    } else {
      // For mobile: use File
      if (image is XFile) {
        setState(() {
          _selectedImage = File(image.path);
          _selectedImageUrl = null;
        });
      }
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
          // Convert blob URL to bytes using web helper
          final fetched = await web_bytes.fetchBytesFromUrl(_selectedImageUrl!);
          if (fetched == null) {
            return 'https://via.placeholder.com/400x300/FF0000/FFFFFF?text=Upload+Failed';
          }
          bytes = fetched;
          
          if (kDebugMode) debugPrint('Web image size: ${bytes.length} bytes');
        } catch (e) {
          if (kDebugMode) debugPrint('Error converting web image: $e');
          // Fallback to placeholder if conversion fails
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
        if (kDebugMode) debugPrint('Image size: ${bytes.length} bytes');
      } else {
        throw Exception('Kein Bild ausgewählt');
      }

      final filePath = '${user.id}/$fileName';
      if (kDebugMode) debugPrint('Uploading to path: $filePath');

      await Supabase.instance.client.storage
          .from('activity-images')
          .uploadBinary(filePath, bytes);

      final imageUrl = Supabase.instance.client.storage
          .from('activity-images')
          .getPublicUrl(filePath);

      if (kDebugMode) debugPrint('Image uploaded successfully: $imageUrl');
      return imageUrl;
    } catch (e) {
      if (kDebugMode) debugPrint('Detailed upload error: $e');
      throw Exception('Fehler beim Hochladen des Bildes: $e');
    }
  }

  Future<void> _submitLog() async {
    // Validate inputs
    if (_activityNameCtrl.text.trim().isEmpty) {
      setState(() { _error = 'Please enter a name for the activity.'; });
      return;
    }

    final raw = _durationCtrl.text.trim();
    int? duration;
    if (raw.isNotEmpty) {
      duration = int.tryParse(raw);
      if (duration == null) {
        setState(() { _error = 'Please enter a valid number of minutes.'; });
        return;
      }
    }
    setState(() { _loading = true; _error = null; });
    final messenger = ScaffoldMessenger.of(context);
    if (mounted) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Saving... XP is being calculated'),
          duration: Duration(milliseconds: 900),
        ),
      );
    }

    try {
      // Upload image if selected
      String? imageUrl;
      if (_selectedImage != null || _selectedImageUrl != null) {
        try {
          imageUrl = await _uploadImage();
        } catch (e) {
          // If image upload fails, continue without image but show a warning
          if (kDebugMode) debugPrint('Image upload failed: $e');
          setState(() {
            _error = 'Image upload failed: $e\n\nThe activity will be saved without an image.';
          });
          // Don't fail the entire log creation, but show error to user
        }
      }

      ActionLog log;
      
      if (widget.template != null) {
        // Use existing template
        // Ensure we also persist context (area, category, title) in notes wrapper for later display
        final String wrappedNotes = jsonEncode({
          'area': widget.selectedArea ?? '',
          'category': widget.selectedCategory ?? 'General',
          'title': widget.template!.name,
          'delta': _quillCtrl.document.toDelta().toJson(),
        });
        log = await createLog(
          templateId : widget.template!.id,
          durationMin: duration,
          notes      : wrappedNotes,
          imageUrl   : imageUrl,
        );
      } else {
        // Create a quick log without template
        final activityName = _activityNameCtrl.text.trim();
        final areaName = widget.selectedArea ?? '';
        final category = widget.selectedCategory ?? 'General';
        // Immer den Wrapper speichern, auch wenn der Delta-Inhalt leer ist,
        // damit die Zuordnung zum Lebensbereich sicher ist
        final String notesDeltaJson = jsonEncode({
          'area': areaName,
          'category': category,
          'title': activityName,
          'delta': _quillCtrl.document.toDelta().toJson(),
        });
        
        log = await createQuickLog(
          activityName: activityName,
          category: category,
          durationMin: duration,
          notes: notesDeltaJson,
          imageUrl: imageUrl,
        );
      }
      
      // Prüfe Level-Up: vergleiche Level vorher/nachher anhand total XP
      final totalAfter = await fetchTotalXp();
      final newLevel = calculateLevel(totalAfter);
      final prevLevel = calculateLevel(totalAfter - log.earnedXp);
      final bool didLevelUp = newLevel > prevLevel;

      // Auf Erfolg hinweisen und zuverlässig zur Liste zurück
      if (!mounted) return;
      // Wenn XP noch 0 (Edge Function evtl. asynchron) → Hinweis anzeigen
      final xpText = (log.earnedXp > 0)
          ? '+${log.earnedXp} XP'
          : 'XP wird berechnet…';
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text('Log created: $xpText'),
          duration: const Duration(milliseconds: 1600),
        ),
      );
      // Tastatur schließen und zur Dashboard zurücknavigieren
      FocusScope.of(context).unfocus();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      
      // Zurück zur Startseite (Dashboard) navigieren
      if (mounted) {
        // Zum Dashboard-Tab wechseln
        goToHomeTab(0);
        // Zurück zum tab system navigieren (alle routes entfernen bis HomeShell)
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const HomeShell()),
          (route) => false,
        );
      }

      // Cache löschen und Provider invalidieren, damit Dashboard-Header/Charts/Streak/XP aktualisieren
      try {
        if (mounted) {
          // Import und Cache löschen, um sicherzustellen, dass frische Daten geladen werden
          await OfflineCache.clearCache();
          final container = ProviderScope.containerOf(context, listen: false);
          container.refresh(logsNotifierProvider);
          container.refresh(xpNotifierProvider);
          container.refresh(streakNotifierProvider);
        }
      } catch (e) {
        if (kDebugMode) debugPrint('Error refreshing providers: $e');
      }

      // Level-Up-Event SOFORT setzen (vor Achievement-Prüfung), damit Reihenfolge stimmt
      if (didLevelUp) {
        LevelUpService.notifyLevelUp(newLevel);
      }
    } catch (err) {
      setState(() { _error = 'Error while saving: $err'; });
    } finally {
      if (mounted) {
        setState(() { _loading = false; });
      }
    }
  }

  @override
  void dispose() {
    _durationCtrl.dispose();
    _notesCtrl.dispose();
    _notesFocusNode.dispose();
    _quillFocusNode.dispose();
    _quillScrollController.dispose();
    _quillCtrl.dispose();
    _activityNameCtrl.dispose();
    super.dispose();
  }

  void _wrapSelection({required String prefix, String? suffix}) {
    final selection = _notesCtrl.selection;
    final fullText = _notesCtrl.text;
    if (!selection.isValid) return;

    final start = selection.start;
    final end = selection.end;

    final String selected = fullText.substring(start, end);
    final String effectiveSuffix = suffix ?? prefix;

    // Toggle behavior: if already wrapped exactly, unwrap
    final bool alreadyWrapped = selected.startsWith(prefix) && selected.endsWith(effectiveSuffix);
    String replacement;
    int deltaStart = 0;
    int deltaEnd = 0;
    if (alreadyWrapped) {
      replacement = selected.substring(prefix.length, selected.length - effectiveSuffix.length);
      deltaStart = 0;
      deltaEnd = -(prefix.length + effectiveSuffix.length);
    } else {
      replacement = '$prefix$selected$effectiveSuffix';
      deltaStart = 0;
      deltaEnd = prefix.length + effectiveSuffix.length;
    }

    final newText = fullText.replaceRange(start, end, replacement);
    _notesCtrl.value = TextEditingValue(
      text: newText,
      selection: TextSelection(baseOffset: start, extentOffset: end + deltaEnd),
    );
  }

  void _toggleLinePrefix(String prefix) {
    final selection = _notesCtrl.selection;
    final text = _notesCtrl.text;
    if (!selection.isValid) return;

    // Determine line range covering the selection
    int lineStart = text.lastIndexOf('\n', selection.start - 1) + 1;
    int lineEnd = text.indexOf('\n', selection.end);
    if (lineEnd == -1) lineEnd = text.length;

    final block = text.substring(lineStart, lineEnd);
    final lines = block.split('\n');
    bool allPrefixed = lines.isNotEmpty && lines.every((l) => l.startsWith(prefix));

    final String transformed = lines
        .map((l) => allPrefixed ? l.replaceFirst(prefix, '') : '$prefix$l')
        .join('\n');

    final newText = text.replaceRange(lineStart, lineEnd, transformed);
    final int diff = transformed.length - block.length;
    _notesCtrl.value = TextEditingValue(
      text: newText,
      selection: TextSelection(baseOffset: selection.start, extentOffset: selection.end + diff),
    );
  }

  // Consistent section container
  Widget _sectionCard({
    required Widget child,
    String? title,
    IconData? leadingIcon,
    Color? accentColor,
    EdgeInsetsGeometry padding = const EdgeInsets.all(12),
  }) {
    final theme = Theme.of(context);
    final Color stripeColor = (accentColor ?? theme.colorScheme.primary).withAlpha(140);
    final Color bgColor = theme.colorScheme.surface;

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Accent stripe on the left
          Positioned.fill(
            left: 0,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                width: 4,
                decoration: BoxDecoration(
                  color: stripeColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    bottomLeft: Radius.circular(12),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: padding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null) ...[
                  Row(
                    children: [
                      if (leadingIcon != null)
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: stripeColor.withAlpha(38),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(leadingIcon, size: 18, color: stripeColor),
                        ),
                      if (leadingIcon != null) const SizedBox(width: 8),
                      Text(
                        title,
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
                child,
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Unified input decoration
  InputDecoration _buildInputDecoration({required String hint, required IconData icon, Color? accentColor}) {
    final theme = Theme.of(context);
    final Color focusColor = accentColor ?? theme.colorScheme.primary;
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, color: focusColor.withAlpha(204)),
      filled: true,
      fillColor: theme.colorScheme.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.2)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.2)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: focusColor, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      hintStyle: TextStyle(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
        fontSize: 16,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tpl = widget.template;
    final title = tpl != null ? 'Log: ${tpl.name}' : 'Neue Aktion loggen';
    final selectedArea = widget.selectedArea;
    final selectedCategory = widget.selectedCategory;
    final Color? areaColor = (widget.areaColorHex != null && widget.areaColorHex!.isNotEmpty)
        ? Color(int.parse(widget.areaColorHex!.replaceAll('#', '0xFF')))
        : null;
    IconData? areaIcon;
    if (widget.areaIcon != null && widget.areaIcon!.isNotEmpty) {
      switch (widget.areaIcon) {
        case 'fitness_center':
          areaIcon = Icons.fitness_center; break;
        case 'restaurant':
          areaIcon = Icons.restaurant; break;
        case 'school':
          areaIcon = Icons.school; break;
        case 'account_balance':
          areaIcon = Icons.account_balance; break;
        case 'palette':
          areaIcon = Icons.palette; break;
        case 'people':
          areaIcon = Icons.people; break;
        case 'self_improvement':
          areaIcon = Icons.self_improvement; break;
        case 'work':
          areaIcon = Icons.work; break;
        default:
          areaIcon = Icons.category;
      }
    }
    
    final Color accent = areaColor ?? Theme.of(context).colorScheme.primary;

    // Use different layout for modal vs fullscreen
    if (widget.isModal) {
      return Column(
        children: [
          // Modal header with handle and close button
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const Spacer(),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: AutofillGroup(
              child: SingleChildScrollView(
                controller: widget.scrollController,
                padding: const EdgeInsets.all(16),
                child: _buildFormContent(selectedArea, selectedCategory, areaIcon, accent, areaColor),
              ),
            ),
          ),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: AutofillGroup(
        // Explicitly disable autofill for the entire form to prevent password manager
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: _buildFormContent(selectedArea, selectedCategory, areaIcon, accent, areaColor),
        ),
      ),
    );
  }

  Widget _buildFormContent(String? selectedArea, String? selectedCategory, IconData? areaIcon, Color accent, Color? areaColor) {
    return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
            if (selectedArea != null && selectedArea.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: (areaColor ?? Theme.of(context).colorScheme.primary).withValues(alpha: 0.2)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: (areaColor ?? Theme.of(context).colorScheme.primary).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        areaIcon ?? Icons.category,
                        color: areaColor ?? Theme.of(context).colorScheme.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Life Area',
                            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                  color: (areaColor ?? Theme.of(context).colorScheme.onSurface).withValues(alpha: 0.6),
                                ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            selectedCategory != null && selectedCategory.isNotEmpty
                                ? '$selectedArea • $selectedCategory'
                                : selectedArea,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: areaColor ?? Theme.of(context).colorScheme.onSurface,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            // Activity name field (only show if no template)
            if (widget.template == null) ...[
              _sectionCard(
                accentColor: accent,
                title: 'Activity Name',
                leadingIcon: Icons.task_alt,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _activityNameCtrl,
                      autocorrect: false,
                      autofillHints: const [],
                      enableSuggestions: false,
                      keyboardType: TextInputType.text,
                      textInputAction: TextInputAction.next,
                      decoration: _buildInputDecoration(
                        hint: 'e.g. Running, Reading, Meditation...',
                        icon: Icons.task_alt,
                        accentColor: accent,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            
            _sectionCard(
              accentColor: accent,
              title: 'Duration in Minutes (optional)',
              leadingIcon: Icons.timer_outlined,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _durationCtrl,
                    keyboardType: TextInputType.number,
                    autofillHints: const [],
                    enableSuggestions: false,
                    autocorrect: false,
                    textInputAction: TextInputAction.done,
                    inputFormatters: const [],
                    decoration: _buildInputDecoration(hint: 'e.g. 45', icon: Icons.timer_outlined, accentColor: accent),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            _sectionCard(
              accentColor: accent,
              title: 'Note (optional)',
              leadingIcon: Icons.notes,
              child: Stack(
                children: [
                  Column(
                    children: [
                      // Toolbar
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        child: quill.QuillSimpleToolbar(
                          controller: _quillCtrl,
                          config: const quill.QuillSimpleToolbarConfig(
                            multiRowsDisplay: false,
                            showAlignmentButtons: false,
                            showUnderLineButton: false,
                            showStrikeThrough: false,
                            showInlineCode: false,
                            showCodeBlock: false,
                            showSearchButton: false,
                            showSubscript: false,
                            showSuperscript: false,
                            showQuote: false,
                            showListCheck: false,
                            showClipboardCut: false,
                            showClipboardCopy: false,
                            showClipboardPaste: false,
                          ),
                        ),
                      ),
                      const Divider(height: 1),
                      // Editor area (WYSIWYG)
                      SizedBox(
                        height: 260,
                        child: quill.QuillEditor.basic(
                          controller: _quillCtrl,
                          config: const quill.QuillEditorConfig(
                            placeholder: 'Your thoughts…',
                            padding: EdgeInsets.all(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Image upload section
            Text('Add Image (optional):', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            
            // Selected image preview
            if (_selectedImage != null || _selectedImageUrl != null) ...[
              Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: accent.withValues(alpha: 0.3)),
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
                      onPressed: _showImageSourceDialog,
                      icon: const Icon(Icons.edit),
                      label: const Text('Change Image'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: accent,
                        side: BorderSide(color: accent.withValues(alpha: 0.6)),
                      ),
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
                      icon: Icon(Icons.delete, color: accent),
                      label: Text('Remove', style: TextStyle(color: accent)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: accent,
                        side: BorderSide(color: accent.withValues(alpha: 0.6)),
                      ),
                    ),
                  ),
                ],
              ),
            ] else ...[
              _sectionCard(
                accentColor: accent,
                child: Center(
                  child: OutlinedButton.icon(
                    onPressed: _showImageSourceDialog,
                    icon: const Icon(Icons.add_a_photo),
                    label: const Text('Add Image'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: accent,
                      side: BorderSide(color: accent.withValues(alpha: 0.6)),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                  ),
                ),
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
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _loading
                ? const SizedBox(
                    height: 16, width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save Log'),
            ),
            ],
          );
  }
}

class _MarkdownPreview extends StatefulWidget {
  final TextEditingController textStream;
  const _MarkdownPreview({required this.textStream});

  @override
  State<_MarkdownPreview> createState() => _MarkdownPreviewState();
}

class _MarkdownPreviewState extends State<_MarkdownPreview> {
  late String _text;

  @override
  void initState() {
    super.initState();
    _text = widget.textStream.text;
    widget.textStream.addListener(_onChange);
  }

  void _onChange() {
    if (!mounted) return;
    setState(() {
      _text = widget.textStream.text;
    });
  }

  @override
  void dispose() {
    widget.textStream.removeListener(_onChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Minimal markdown highlighting using RichText to avoid heavy deps
    final spans = <TextSpan>[];
    final lines = _text.split('\n');
    final boldRegex = RegExp(r"\*\*(.*?)\*\*");
    final italicRegex = RegExp(r"\*(.*?)\*");
    for (final line in lines) {
      TextStyle base = Theme.of(context).textTheme.bodyMedium!;
      if (line.startsWith('# ')) {
        spans.add(TextSpan(text: line.substring(2) + '\n', style: base.copyWith(fontSize: 18, fontWeight: FontWeight.w700)));
        continue;
      }
      if (line.startsWith('- ')) {
        spans.add(TextSpan(text: '• ' + line.substring(2) + '\n', style: base));
        continue;
      }
      // Bold
      String remaining = line;
      while (true) {
        final match = boldRegex.firstMatch(remaining);
        if (match == null) break;
        final pre = remaining.substring(0, match.start);
        final content = match.group(1)!;
        spans.add(TextSpan(text: pre, style: base));
        spans.add(TextSpan(text: content, style: base.copyWith(fontWeight: FontWeight.bold)));
        remaining = remaining.substring(match.end);
      }
      // Italic
      String rem2 = remaining;
      while (true) {
        final match = italicRegex.firstMatch(rem2);
        if (match == null) break;
        final pre = rem2.substring(0, match.start);
        final content = match.group(1)!;
        spans.add(TextSpan(text: pre, style: base));
        spans.add(TextSpan(text: content, style: base.copyWith(fontStyle: FontStyle.italic)));
        rem2 = rem2.substring(match.end);
      }
      spans.add(TextSpan(text: rem2 + '\n', style: base));
    }

    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(left: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
        ),
        child: SingleChildScrollView(
          child: RichText(text: TextSpan(children: spans)),
        ),
      ),
    );
  }
}

// Custom XFile-like class for web
class _WebFile {
  final String name;
  final Uint8List bytes;
  final String path;
  
  _WebFile({
    required this.name,
    required this.bytes,
    required this.path,
  });
  
  Future<Uint8List> readAsBytes() async => bytes;
}

// Separate page for image picking to avoid password manager popup
class _ImagePickerPage extends StatelessWidget {
  const _ImagePickerPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Image'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.add_a_photo,
              size: 80,
              color: Colors.grey,
            ),
            const SizedBox(height: 24),
            const Text(
              'Choose how to add your image',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _pickFromGallery(context),
                icon: const Icon(Icons.photo_library),
                label: const Text('Choose from Gallery'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _takePhoto(context),
                icon: const Icon(Icons.camera_alt),
                label: const Text('Take Photo'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                ),
              ),
            ),
            if (!kIsWeb) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _takeSelfie(context),
                  icon: const Icon(Icons.camera_front),
                  label: const Text('Take Selfie'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _pickFromGallery(BuildContext context) async {
    if (kIsWeb) {
      final result = await web_file_picker.pickImageFile();
      if (result != null && context.mounted) {
        // Create a fake XFile-like object for web
        final fakeFile = _WebFile(
          name: result['name'],
          bytes: _dataUrlToBytes(result['dataUrl']),
          path: result['dataUrl'],
        );
        Navigator.of(context).pop(fakeFile);
      } else if (context.mounted) {
        Navigator.of(context).pop(); // User cancelled
      }
    } else {
      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );
      if (image != null && context.mounted) {
        Navigator.of(context).pop(image);
      }
    }
  }
  
  Uint8List _dataUrlToBytes(String dataUrl) {
    final base64String = dataUrl.split(',')[1];
    return base64Decode(base64String);
  }

  Future<void> _takePhoto(BuildContext context) async {
    if (kIsWeb) {
      // Camera not fully supported in web file picker, close dialog
      if (context.mounted) {
        Navigator.of(context).pop();
      }
      return;
    }
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 80,
    );
    if (image != null && context.mounted) {
      Navigator.of(context).pop(image);
    }
  }

  Future<void> _takeSelfie(BuildContext context) async {
    if (kIsWeb) {
      // Camera not fully supported in web file picker, close dialog
      if (context.mounted) {
        Navigator.of(context).pop();
      }
      return;
    }
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.front,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 80,
    );
    if (image != null && context.mounted) {
      Navigator.of(context).pop(image);
    }
  }
}