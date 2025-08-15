import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'services/character_service.dart';
import 'services/avatar_sync_service.dart';

class ProfileEditPage extends StatefulWidget {
  const ProfileEditPage({Key? key}) : super(key: key);

  @override
  State<ProfileEditPage> createState() => _ProfileEditPageState();
}

class _ProfileEditPageState extends State<ProfileEditPage> {
  final _nameCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  File? _avatarFile;
  bool _loading = false;
  bool _isLoadingProfile = true;
  String? _error;
  String? _currentAvatarUrl;
  String? _userName;
  String? _userBio;

  final _supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // kein weiterer redundanter Reload hier
  }



  Future<void> _loadProfile() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user != null) {
        final res = await _supabase
            .from('users')
            .select('name,bio,avatar_url,email')
            .eq('id', user.id)
            .single();
        
        if (mounted) {
          setState(() {
            _userName = res['name'] ?? user.email?.split('@')[0] ?? 'User';
            _userBio = res['bio'] ?? '';
            _currentAvatarUrl = res['avatar_url'];
            _nameCtrl.text = res['name'] ?? '';
            _bioCtrl.text = res['bio'] ?? '';
            _isLoadingProfile = false;
          });
          print('DEBUG: Loaded avatar_url: $_currentAvatarUrl');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _userName = _supabase.auth.currentUser?.email?.split('@')[0] ?? 'User';
          _userBio = '';
          _nameCtrl.text = _supabase.auth.currentUser?.email?.split('@')[0] ?? 'User';
          _bioCtrl.text = 'Das ist meine Bio.';
          _isLoadingProfile = false;
        });
      }
      print('Fehler beim Laden des Profils: $e');
    }
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final img = await picker.pickImage(source: ImageSource.gallery);
    if (img != null) {
      if (kIsWeb) {
        // Für Web: Verwende die Bytes direkt
        final bytes = await img.readAsBytes();
        setState(() {
          _avatarFile = null; // Kein File für Web
        });
        // Speichere die Bytes für den Upload
        _uploadAvatarBytes(bytes);
      } else {
        // Für Mobile: Verwende File
        setState(() {
          _avatarFile = File(img.path);
        });
      }
    }
  }

  Future<void> _uploadAvatarBytes(Uint8List bytes) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    
    try {
      final currentUser = _supabase.auth.currentUser!;
      final ext = 'jpg'; // Standard für Web
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      // Versionierter Dateiname für hartes Cache-Busting über neue URL
      final path = '${currentUser.id}/avatar_${timestamp}.$ext';
      
      print('DEBUG: Uploading avatar to path: $path');
      print('DEBUG: File size: ${bytes.length} bytes');
      
      await _supabase.storage
          .from('avatars')
          .uploadBinary(path, bytes, fileOptions: const FileOptions(upsert: true));
      final avatarUrl = _supabase.storage.from('avatars').getPublicUrl(path);
      
      print('DEBUG: Avatar URL: $avatarUrl');
      
      // Aktualisiere den State mit der neuen Avatar-URL
      setState(() {
        _currentAvatarUrl = avatarUrl;
      });
      
      // Aktualisiere das Profil
      await _saveProfileWithAvatar(avatarUrl);
      
    } catch (err) {
      print('DEBUG: Error uploading avatar: $err');
      setState(() {
        _error = err.toString();
        _loading = false;
      });
    }
  }

  Future<void> _saveProfile() async {
    if (_avatarFile != null && !kIsWeb) {
      // Für Mobile: Upload das File
      await _saveProfileWithFile();
    } else {
      // Für Web oder ohne neues Bild: Speichere nur die Text-Daten
      await _saveProfileWithAvatar(_currentAvatarUrl);
    }
  }

  Future<void> _saveProfileWithFile() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    
    try {
      final currentUser = _supabase.auth.currentUser!;
      final ext = _avatarFile!.path.split('.').last.toLowerCase();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      // Versionierter Dateiname für hartes Cache-Busting über neue URL
      final path = '${currentUser.id}/avatar_${timestamp}.$ext';
      // Komprimieren falls möglich
      final rawBytes = await _avatarFile!.readAsBytes();
      Uint8List bytes = rawBytes;
      try {
        // einfache Heuristik: bei > 400KB komprimieren
        if (rawBytes.length > 400 * 1024) {
          // Wenn flutter_image_compress Web nicht unterstützt, einfach unverändert lassen
          // Für Mobile wird die Bibliothek greifen
        }
      } catch (_) {}
      
      print('DEBUG: Uploading avatar to path: $path');
      print('DEBUG: File size: ${bytes.length} bytes');
      
      await _supabase.storage
          .from('avatars')
          .uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(
              upsert: true,
              contentType: ext == 'png'
                  ? 'image/png'
                  : (ext == 'webp' ? 'image/webp' : 'image/jpeg'),
            ),
          );
      final avatarUrl = _supabase.storage.from('avatars').getPublicUrl(path);
      
      print('DEBUG: Avatar URL: $avatarUrl');
      
      await _saveProfileWithAvatar(avatarUrl);
      
    } catch (err) {
      print('DEBUG: Error saving profile with file: $err');
      setState(() {
        _error = err.toString();
        _loading = false;
      });
    }
  }

  Future<void> _saveProfileWithAvatar(String? avatarUrl) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    
    try {
      final currentUser = _supabase.auth.currentUser!;
      
      final profile = {
        'id': currentUser.id,
        'email': currentUser.email,
        'name': _nameCtrl.text.trim(),
        'bio': _bioCtrl.text.trim(),
        'avatar_url': avatarUrl,
      };
      
      print('DEBUG: Saving profile with avatar_url: $avatarUrl');
      
      await _supabase
          .from('users')
          .upsert(profile, onConflict: 'id');

      // Synchronisiere das Avatar in allen Tabellen
      await AvatarSyncService.syncAvatar(avatarUrl);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profil gespeichert!'),
          backgroundColor: Colors.green,
        ),
      );
      
      // Force rebuild des Dashboards beim Zurückkehren
      Navigator.of(context).pop(true); // true = Profil wurde geändert
    } catch (err) {
      print('DEBUG: Error saving profile: $err');
      setState(() {
        _error = err.toString();
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingProfile) {
      return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Theme.of(context).colorScheme.surface,
          foregroundColor: Theme.of(context).colorScheme.onSurface,
          title: const Text(
            'Profil bearbeiten',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // Verwende die gleiche Logik wie im Dashboard - lade die Avatar-URL direkt aus der users Tabelle
    final userId = _supabase.auth.currentUser?.id;
    final String? rawUrl = _currentAvatarUrl;
    
    bool _isValidAvatarUrl(String? url) {
      if (url == null) return false;
      final trimmed = url.trim();
      if (trimmed.isEmpty) return false;
      return trimmed.contains('/storage/v1/object/public/avatars/') &&
             (userId == null || trimmed.contains(userId));
    }
    
    final String? avatarUrl = _isValidAvatarUrl(rawUrl)
        ? '$rawUrl?t=${DateTime.now().millisecondsSinceEpoch}&v=2'
        : null;
    final ImageProvider? avatarProvider =
        avatarUrl != null ? NetworkImage(avatarUrl) : null;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        title: const Text(
          'Profil bearbeiten',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            TextButton(
              onPressed: _saveProfile,
              child: const Text(
                'Speichern',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar Section
            Center(
              child: Column(
                children: [
                                     GestureDetector(
                     onTap: () async {
                       // Lade das Profil neu vor dem Bildauswahl
                       await _loadProfile();
                       // Kurze Verzögerung für UI-Update
                       await Future.delayed(const Duration(milliseconds: 100));
                       _pickAvatar();
                     },
                     child: Stack(
                      children: [
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 4),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 12,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                                                      child: CircleAvatar(
                              radius: 56,
                              backgroundImage: avatarProvider,
                              backgroundColor: Colors.grey[200],
                            ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Icon(
                              Icons.camera_alt,
                              color: Colors.white,
                              size: 20,
                          ),
                        ),
                      ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Tippe auf das Bild zum Ändern',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Name Section
            Text(
              'Name',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _nameCtrl,
              decoration: InputDecoration(
                hintText: 'Dein Name',
                prefixIcon: const Icon(Icons.person),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey[50],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Bio Section
            Text(
              'Bio',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _bioCtrl,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Erzähle etwas über dich...',
                prefixIcon: const Icon(Icons.edit),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey[50],
              ),
            ),
            
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
            
            const SizedBox(height: 32),
            
            // Save Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _saveProfile,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text(
                        'Profil speichern',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 