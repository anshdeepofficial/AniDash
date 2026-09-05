// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'player_ui_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(PlayerUIController)
const playerUIControllerProvider = PlayerUIControllerProvider._();

final class PlayerUIControllerProvider
    extends $NotifierProvider<PlayerUIController, PlayerUIState> {
  const PlayerUIControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'playerUIControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$playerUIControllerHash();

  @$internal
  @override
  PlayerUIController create() => PlayerUIController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PlayerUIState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PlayerUIState>(value),
    );
  }
}

String _$playerUIControllerHash() =>
    r'c809fc483d7562babf0e675c0f1f12393641a61a';

abstract class _$PlayerUIController extends $Notifier<PlayerUIState> {
  PlayerUIState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<PlayerUIState, PlayerUIState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<PlayerUIState, PlayerUIState>,
              PlayerUIState,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
