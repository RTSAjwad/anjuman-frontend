import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

mixin SafeNotify on ChangeNotifier {
  /// Calls notifyListeners, deferring to a post-frame callback if called
  /// during the build/layout phase (persistentCallbacks).
  void safeNotify() {
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        notifyListeners();
      });
    } else {
      notifyListeners();
    }
  }
}
