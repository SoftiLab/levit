part of '../../levit_flutter.dart';

/// A mixin that automatically pauses execution loops when the app goes to background.
///
/// It requires [LevitLoopExecutionMixin] to function.
/// LevitLoopExecutionMixin
mixin LevitLoopExecutionLifecycleMixin
    on LevitController, LevitLoopExecutionMixin {
  late final _LifecycleLoopObserver _lifecycleObserver;

  @override
  void onInit() {
    super.onInit();
    _lifecycleObserver = _LifecycleLoopObserver(this);
    WidgetsBinding.instance.addObserver(_lifecycleObserver);
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(_lifecycleObserver);
    super.onClose();
  }

  /// Override this to return true if you want to force pause even permanent tasks
  /// when the app goes to background.
  ///
  /// Defaults to `false`.
  bool get pauseLifecycleServicesForce => false;
}

class _LifecycleLoopObserver with WidgetsBindingObserver {
  final LevitLoopExecutionLifecycleMixin _mixin;

  _LifecycleLoopObserver(this._mixin);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
        _mixin.loopEngine
            .pauseAllServices(force: _mixin.pauseLifecycleServicesForce);
        break;
      case AppLifecycleState.resumed:
        _mixin.loopEngine
            .resumeAllServices(force: _mixin.pauseLifecycleServicesForce);
        break;
      default:
        // Do nothing for inactive or detached
        break;
    }
  }
}
