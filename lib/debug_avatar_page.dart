import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'services/avatar_sync_service.dart';

class DebugAvatarPage extends StatefulWidget {
  const DebugAvatarPage({super.key});

  @override
  State<DebugAvatarPage> createState() => _DebugAvatarPageState();
}

class _DebugAvatarPageState extends State<DebugAvatarPage> {
  String? _userAvatarUrl;
  String? _characterAvatarUrl;
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _userData;
  Map<String, dynamic>? _characterData;
  Map<String, String?> _syncStatus = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        // Lade User-Daten
        final userRes = await Supabase.instance.client
            .from('users')
            .select('*')
            .eq('id', user.id)
            .single();
        
        // Lade Character-Daten
        final characterRes = await Supabase.instance.client
            .from('characters')
            .select('*')
            .eq('user_id', user.id)
            .single();

        // Prüfe Synchronisation
        final syncStatus = await AvatarSyncService.checkAvatarSync();

        if (mounted) {
          setState(() {
            _userData = userRes;
            _characterData = characterRes;
            _userAvatarUrl = userRes['avatar_url'];
            _characterAvatarUrl = characterRes['avatar_url'];
            _syncStatus = syncStatus;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
      print('Fehler beim Laden der Avatar-Daten: $e');
    }
  }

  Future<void> _uploadTestAvatar() async {
    try {
      final picker = ImagePicker();
      final img = await picker.pickImage(source: ImageSource.gallery);
      if (img != null) {
        final user = Supabase.instance.client.auth.currentUser!;
        final bytes = await img.readAsBytes();
        final path = '${user.id}/test_avatar.jpg';
        
        print('DEBUG: Uploading test avatar to path: $path');
        print('DEBUG: File size: ${bytes.length} bytes');
        
        await Supabase.instance.client.storage
            .from('avatars')
            .uploadBinary(path, bytes, fileOptions: const FileOptions(upsert: true));
        
        final avatarUrl = Supabase.instance.client.storage.from('avatars').getPublicUrl(path);
        
        print('DEBUG: Test avatar URL: $avatarUrl');
        
        // Verwende den AvatarSyncService für konsistente Synchronisation
        await AvatarSyncService.syncAvatar(avatarUrl);
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Test Avatar hochgeladen und synchronisiert!')),
        );
        
        _loadData(); // Reload data
      }
    } catch (e) {
      print('Fehler beim Upload: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler: $e')),
      );
    }
  }

  Future<void> _forceSync() async {
    try {
      await AvatarSyncService.forceSync();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Force Sync durchgeführt!')),
      );
      _loadData(); // Reload data
    } catch (e) {
      print('Fehler beim Force Sync: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Avatar Debug'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Daten neu laden',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_error != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        'Fehler: $_error',
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  
                  // Sync Status
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Synchronisation Status:',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          if (_syncStatus.isNotEmpty) ...[
                            Text('Users Table: ${_syncStatus['users'] ?? 'null'}'),
                            Text('Characters Table: ${_syncStatus['characters'] ?? 'null'}'),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: _syncStatus['users'] == _syncStatus['characters'] 
                                    ? Colors.green.withValues(alpha: 0.1)
                                    : Colors.red.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: _syncStatus['users'] == _syncStatus['characters'] 
                                      ? Colors.green.withValues(alpha: 0.3)
                                      : Colors.red.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Text(
                                _syncStatus['users'] == _syncStatus['characters'] 
                                    ? '✅ Synchronisiert'
                                    : '❌ Nicht synchronisiert',
                                style: TextStyle(
                                  color: _syncStatus['users'] == _syncStatus['characters'] 
                                      ? Colors.green
                                      : Colors.red,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // User Data Section
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'User Table Data:',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          if (_userData != null) ...[
                            Text('ID: ${_userData!['id']}'),
                            Text('Name: ${_userData!['name'] ?? 'null'}'),
                            Text('Email: ${_userData!['email'] ?? 'null'}'),
                            Text('Avatar URL: ${_userData!['avatar_url'] ?? 'null'}'),
                            const SizedBox(height: 8),
                            if (_userAvatarUrl != null) ...[
                              const Text('User Avatar Image:'),
                              const SizedBox(height: 4),
                              Container(
                                width: 100,
                                height: 100,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.grey),
                                ),
                                child: ClipOval(
                                  child: Image.network(
                                    _userAvatarUrl!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        color: Colors.grey[200],
                                        child: const Icon(Icons.error),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Character Data Section
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Character Table Data:',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          if (_characterData != null) ...[
                            Text('User ID: ${_characterData!['user_id']}'),
                            Text('Name: ${_characterData!['name'] ?? 'null'}'),
                            Text('Level: ${_characterData!['level'] ?? 'null'}'),
                            Text('Avatar URL: ${_characterData!['avatar_url'] ?? 'null'}'),
                            const SizedBox(height: 8),
                            if (_characterAvatarUrl != null) ...[
                              const Text('Character Avatar Image:'),
                              const SizedBox(height: 4),
                              Container(
                                width: 100,
                                height: 100,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.grey),
                                ),
                                child: ClipOval(
                                  child: Image.network(
                                    _characterAvatarUrl!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        color: Colors.grey[200],
                                        child: const Icon(Icons.error),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _uploadTestAvatar,
                          child: const Text('Test Avatar hochladen'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _forceSync,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                          ),
                          child: const Text('Force Sync'),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Storage URLs
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Storage URLs:',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          if (Supabase.instance.client.auth.currentUser != null) ...[
                            Text('User ID: ${Supabase.instance.client.auth.currentUser!.id}'),
                            Text('Avatar Storage Path: ${Supabase.instance.client.auth.currentUser!.id}/avatar.jpg'),
                            Text('Avatar Public URL: ${Supabase.instance.client.storage.from('avatars').getPublicUrl('${Supabase.instance.client.auth.currentUser!.id}/avatar.jpg')}'),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
} 