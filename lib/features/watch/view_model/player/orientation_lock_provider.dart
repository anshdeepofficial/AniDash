import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ani_dash/helpers/ui.dart';

final orientationLockProvider =
    NotifierProvider<OrientationLockNotifier, OrientationLockMode>(
  OrientationLockNotifier.new,
);

class OrientationLockNotifier extends Notifier<OrientationLockMode> {
  @override
  OrientationLockMode build() => OrientationLockMode.unlocked;

  Future<void> setMode(OrientationLockMode mode) async {
    state = mode;
    switch (mode) {
      case OrientationLockMode.unlocked:
        await UIHelper.enableLandscapeAutoRotate();
        break;
      case OrientationLockMode.lockedLandscape:
        await UIHelper.lockCurrentLandscape();
        break;
    }
  }

  Future<void> toggle() async {
    if (state == OrientationLockMode.unlocked) {
      await setMode(OrientationLockMode.lockedLandscape);
    } else {
      await setMode(OrientationLockMode.unlocked);
    }
  }
}
