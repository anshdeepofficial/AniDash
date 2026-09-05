// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'aniskip_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(AniSkipNotifier)
const aniSkipProvider = AniSkipNotifierProvider._();

final class AniSkipNotifierProvider
    extends $NotifierProvider<AniSkipNotifier, List<AniSkipResultItem>> {
  const AniSkipNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'aniSkipProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$aniSkipNotifierHash();

  @$internal
  @override
  AniSkipNotifier create() => AniSkipNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<AniSkipResultItem> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<AniSkipResultItem>>(value),
    );
  }
}

String _$aniSkipNotifierHash() => r'99109ea79ee911750dd604c2ea83b94edf6a151f';

abstract class _$AniSkipNotifier extends $Notifier<List<AniSkipResultItem>> {
  List<AniSkipResultItem> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref =
        this.ref as $Ref<List<AniSkipResultItem>, List<AniSkipResultItem>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<List<AniSkipResultItem>, List<AniSkipResultItem>>,
              List<AniSkipResultItem>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
