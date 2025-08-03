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
String _$templatesNotifierHash() => r'4972959032f0cce40b7a5a71bda41577b6c8aecc';

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
String _$logsNotifierHash() => r'8f3dd2d9b5631f08d34c092a3e1806e36138fb74';

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
String _$xpNotifierHash() => r'49ec37aef121eaadc213d53b8706143cf1ab734b';

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
String _$streakNotifierHash() => r'a37673866bb3ec8dc90da34e07fdc3207deec671';

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
    r'bdd396512b9dc6803e6d842d51a3a4b553c02371';

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
