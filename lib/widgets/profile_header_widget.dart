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
    print('Error loading user profile: $e');
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
        child: const SizedBox(
          height: 32,
          width: 32,
          child: Center(
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
        ),
      );
    }

    final double padding = widget.compact ? 6 : 14; // reduce height
    final double avatarSize = widget.compact ? 32 : 44; // smaller avatar
    final double titleFontSize = widget.compact ? 15 : 18;

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
          SizedBox(
            width: avatarSize,
            height: avatarSize,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(avatarSize / 2), // perfect circle
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                ),
                child: _userAvatarUrl != null
                    ? FadeInImage.assetNetwork(
                        placeholder: 'assets/default_avatar.png',
                        image: '${_userAvatarUrl!}?cb=$_cacheBust',
                        key: ValueKey('${_userAvatarUrl!}?cb=$_cacheBust'),
                        fit: BoxFit.cover,
                        placeholderFit: BoxFit.cover,
                      )
                    : const Icon(Icons.person, color: Colors.white, size: 22),
              ),
            ),
          ),
          
          const SizedBox(width: 16),
          
          // User Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
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
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
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
              icon: const Icon(Icons.edit, color: Colors.white, size: 18),
              tooltip: 'Profil bearbeiten',
            ),
          ),
        ],
      ),
    );
  }
} 