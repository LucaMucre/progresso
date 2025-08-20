// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_state.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$supabaseClientHash() => r'36e9cae00709545a85bfe4a5a2cb98d8686a01ea';

/// See also [supabaseClient].
@ProviderFor(supabaseClient)
final supabaseClientProvider = AutoDisposeProvider<SupabaseClient>.internal(
  supabaseClient,
  name: r'supabaseClientProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$supabaseClientHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef SupabaseClientRef = AutoDisposeProviderRef<SupabaseClient>;
String _$currentUserHash() => r'd08b081f0aa7e11d26f3a04c926185fe582382fc';

/// See also [currentUser].
@ProviderFor(currentUser)
final currentUserProvider = AutoDisposeProvider<User?>.internal(
  currentUser,
  name: r'currentUserProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$currentUserHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef CurrentUserRef = AutoDisposeProviderRef<User?>;
String _$templatesNotifierHash() => r'c025dd3e952bc9fea8df8fbf3a5603dba363464d';

/// See also [TemplatesNotifier].
@ProviderFor(TemplatesNotifier)
final templatesNotifierProvider = AutoDisposeAsyncNotifierProvider<
    TemplatesNotifier, List<ActionTemplate>>.internal(
  TemplatesNotifier.new,
  name: r'templatesNotifierProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$templatesNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$TemplatesNotifier = AutoDisposeAsyncNotifier<List<ActionTemplate>>;
String _$logsNotifierHash() => r'63d01bac90adf9bd52c843b83a5d8acc981ef655';

/// See also [LogsNotifier].
@ProviderFor(LogsNotifier)
final logsNotifierProvider =
    AutoDisposeAsyncNotifierProvider<LogsNotifier, List<ActionLog>>.internal(
  LogsNotifier.new,
  name: r'logsNotifierProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$logsNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$LogsNotifier = AutoDisposeAsyncNotifier<List<ActionLog>>;
String _$xpNotifierHash() => r'38e406ee8dc64147642cd8957f8c28a9b3995558';

/// See also [XpNotifier].
@ProviderFor(XpNotifier)
final xpNotifierProvider =
    AutoDisposeAsyncNotifierProvider<XpNotifier, int>.internal(
  XpNotifier.new,
  name: r'xpNotifierProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$xpNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$XpNotifier = AutoDisposeAsyncNotifier<int>;
String _$streakNotifierHash() => r'ec67deed6ccbe73f8ac23a2dea0f4a2abe7e5b3e';

/// See also [StreakNotifier].
@ProviderFor(StreakNotifier)
final streakNotifierProvider =
    AutoDisposeAsyncNotifierProvider<StreakNotifier, int>.internal(
  StreakNotifier.new,
  name: r'streakNotifierProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$streakNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$StreakNotifier = AutoDisposeAsyncNotifier<int>;
String _$userProfileNotifierHash() =>
    r'17ba096494c5d453e9453b9f7eb02395f9ec3a1c';

/// See also [UserProfileNotifier].
@ProviderFor(UserProfileNotifier)
final userProfileNotifierProvider = AutoDisposeAsyncNotifierProvider<
    UserProfileNotifier, Map<String, dynamic>?>.internal(
  UserProfileNotifier.new,
  name: r'userProfileNotifierProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$userProfileNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$UserProfileNotifier = AutoDisposeAsyncNotifier<Map<String, dynamic>?>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
