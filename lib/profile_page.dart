import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({Key? key}) : super(key: key);

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _nameCtrl = TextEditingController();
  final _bioCtrl  = TextEditingController();
  File? _avatarFile;
  bool _loading = false;
  String? _error;

  final _supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final userId = _supabase.auth.currentUser!.id;
      final res = await _supabase
          .from('users')
          .select('name,bio,avatar_url,email')
          .eq('id', userId)
          .single();
      if (res != null) {
        _nameCtrl.text = res['name'] ?? '';
        _bioCtrl.text  = res['bio'] ?? '';
        setState(() {});
      }
    } catch (e) {
      print('Fehler beim Laden des Profils: $e');
      // Erstelle Standard-Profil wenn noch nicht vorhanden
      _nameCtrl.text = _supabase.auth.currentUser?.email?.split('@')[0] ?? 'User';
      _bioCtrl.text = 'Das ist meine Bio.';
      setState(() {});
    }
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final img = await picker.pickImage(source: ImageSource.gallery);
    if (img != null) {
      setState(() {
        _avatarFile = File(img.path);
      });
    }
  }

  Future<void> _saveProfile() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final currentUser = _supabase.auth.currentUser!;
    String? avatarUrl;

    try {
      if (_avatarFile != null) {
        final ext = _avatarFile!.path.split('.').last;
        final path = '${currentUser.id}/avatar.$ext';
        final bytes = await _avatarFile!.readAsBytes();
        await _supabase.storage
            .from('avatars')
            .uploadBinary(path, bytes, fileOptions: const FileOptions(upsert: true));
        avatarUrl = _supabase.storage.from('avatars').getPublicUrl(path);
      }

      final profile = {
        'id'         : currentUser.id,
        'email'      : currentUser.email,
        'name'       : _nameCtrl.text.trim(),
        'bio'        : _bioCtrl.text.trim(),
        'avatar_url' : avatarUrl,
      };
      await _supabase
          .from('users')
          .upsert(profile, onConflict: 'id');

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profil gespeichert!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (err) {
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
    final userId = _supabase.auth.currentUser?.id;
    final publicUrl = userId != null
        ? _supabase.storage.from('avatars').getPublicUrl('$userId/avatar.png')
        : null;
    final avatarProvider = _avatarFile != null
        ? FileImage(_avatarFile!)
        : (publicUrl != null
            ? NetworkImage(publicUrl) as ImageProvider
            : const AssetImage('assets/default_avatar.png'));

    return Scaffold(
      appBar: AppBar(title: const Text('Mein Profil')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            GestureDetector(
              onTap: _pickAvatar,
              child: CircleAvatar(
                radius: 50,
                backgroundImage: avatarProvider,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _bioCtrl,
              decoration: const InputDecoration(labelText: 'Bio'),
              maxLines: 3,
            ),
            const SizedBox(height: 24),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            ElevatedButton(
              onPressed: _loading ? null : _saveProfile,
              child: _loading
                  ? const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Speichern'),
            ),
          ],
        ),
      ),
    );
  }
}