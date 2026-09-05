// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'watch_progress_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(WatchProgressNotifier)
const watchProgressProvider = WatchProgressNotifierProvider._();

final class WatchProgressNotifierProvider
    extends $NotifierProvider<WatchProgressNotifier, void> {
  const WatchProgressNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'watchProgressProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$watchProgressNotifierHash();

  @$internal
  @override
  WatchProgressNotifier create() => WatchProgressNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(void value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<void>(value),
    );
  }
}

String _$watchProgressNotifierHash() =>
    r'5238745441e9bc32682b370a9b26d4ff7e53a34d';

abstract class _$WatchProgressNotifier extends $Notifier<void> {
  void build();
  @$mustCallSuper
  @override
  void runBuild() {
    build();
    final ref = this.ref as $Ref<void, void>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<void, void>,
              void,
              Object?,
              Object?
            >;
    element.handleValue(ref, null);
  }
}
