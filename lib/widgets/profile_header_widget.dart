import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../profile_edit_page.dart';
import '../services/avatar_sync_service.dart';

class ProfileHeaderWidget extends StatefulWidget {
  final bool compact;
  const ProfileHeaderWidget({Key? key, this.compact = false}) : super(key: key);

  @override
  State<ProfileHeaderWidget> createState() => _ProfileHeaderWidgetState();
}

class _ProfileHeaderWidgetState extends State<ProfileHeaderWidget> {
  String? _userName;
  String? _userBio;
  String? _userAvatarUrl;
  bool _isLoading = true;
  RealtimeChannel? _usersChannel;
  int _cacheBust = 0;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    _subscribeToUserChanges();
    AvatarSyncService.avatarVersion.addListener(_loadUserProfile);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Lade das Profil neu, wenn die Abhängigkeiten sich ändern
    _loadUserProfile();
  }



  Future<void> _loadUserProfile() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        // Lade Avatar-URL direkt aus der users Tabelle
        final res = await Supabase.instance.client
            .from('users')
            .select('name,bio,avatar_url')
            .eq('id', user.id)
            .single();
        
        if (mounted) {
          setState(() {
            _userName = res['name'] ?? user.email?.split('@')[0] ?? 'User';
            _userBio = res['bio'] ?? '';
            _userAvatarUrl = res['avatar_url'];
            _isLoading = false;
            _cacheBust = DateTime.now().millisecondsSinceEpoch;
          });
          print('DEBUG: ProfileHeaderWidget - Loaded avatar_url: $_userAvatarUrl');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _userName = Supabase.instance.client.auth.currentUser?.email?.split('@')[0] ?? 'User';
          _userBio = '';
          _isLoading = false;
        });
      }
      print('Fehler beim Laden des User-Profils: $e');
    }
  }

  void _subscribeToUserChanges() {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) return;

    // Bestehenden Channel schließen
    _usersChannel?.unsubscribe();

    final channel = client
        .channel('public:users:id=eq.${user.id}')
        .on(
          RealtimeListenTypes.postgresChanges,
          ChannelFilter(
            event: 'UPDATE',
            schema: 'public',
            table: 'users',
            filter: 'id=eq.${user.id}',
          ),
          (payload, [ref]) async {
            // Bei Avatar-Änderung neu laden
            await _loadUserProfile();
            if (mounted) setState(() {});
          },
        );
    channel.subscribe();
    _usersChannel = channel;
  }

  @override
  void dispose() {
    _usersChannel?.unsubscribe();
    AvatarSyncService.avatarVersion.removeListener(_loadUserProfile);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Theme.of(context).colorScheme.primary,
              Theme.of(context).colorScheme.primary.withOpacity(0.8),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ),
      );
    }

    final double padding = widget.compact ? 10 : 24;
    final double avatarSize = widget.compact ? 40 : 60;
    final double titleFontSize = widget.compact ? 16 : 20;

    return Container(
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.primary.withOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: avatarSize,
            height: avatarSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: _userAvatarUrl != null
                ? ClipOval(
                    child: Image.network(
                      '${_userAvatarUrl!}?cb=$_cacheBust',
                      key: ValueKey('${_userAvatarUrl!}?cb=$_cacheBust'),
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.person,
                            size: 30,
                            color: Colors.white,
                          ),
                        );
                      },
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Center(
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              strokeWidth: 2,
                            ),
                          ),
                        );
                      },
                    ),
                  )
                : Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.person,
                      size: 30,
                      color: Colors.white,
                    ),
                  ),
          ),
          
          const SizedBox(width: 16),
          
          // User Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Willkommen zurück, ${_userName ?? 'User'}!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: titleFontSize,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          
          // Edit Button
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              onPressed: () async {
                final result = await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const ProfileEditPage(),
                  ),
                );
                // Force reload wenn Profil geändert wurde
                if (result == true) {
                  // Kurze Verzögerung für UI-Update
                  await Future.delayed(const Duration(milliseconds: 100));
                  _loadUserProfile();
                  // Force rebuild des Dashboards
                  if (mounted) {
                    setState(() {});
                  }
                }
              },
              icon: const Icon(
                Icons.edit,
                color: Colors.white,
                size: 20,
              ),
              tooltip: 'Profil bearbeiten',
            ),
          ),
        ],
      ),
    );
  }
} 