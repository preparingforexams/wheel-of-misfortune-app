import 'dart:async';
import 'dart:math';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:misfortune_app/client.dart';
import 'package:misfortune_app/motion.dart';
import 'package:misfortune_app/safari_permissions.dart';
import 'package:web_browser_detect/web_browser_detect.dart';

abstract class _MisfortuneEvent {}

class PressButtonEvent implements _MisfortuneEvent {
  const PressButtonEvent();
}

class ScanQrEvent implements _MisfortuneEvent {
  final String wheelId;
  final String code;

  ScanQrEvent({required this.code, required this.wheelId});
}

class _PermissionResultEvent implements _MisfortuneEvent {
  final String? result;

  _PermissionResultEvent(this.result);
}

class _AccelEvent implements _MisfortuneEvent {
  final MotionEvent event;

  _AccelEvent(this.event);
}

enum Stage {
  wrongBrowser,
  awaitingPermissions,
  awaitingPress,
  scanningCode,
  awaitingSpin,
  spinning,
  failed,
}

class MisfortuneState {
  final Stage stage;
  final bool tooSlow;
  final String? wheelId;
  final String? movement;
  final String? code;
  final String? error;

  const MisfortuneState._({
    required this.stage,
    required this.tooSlow,
    this.wheelId,
    this.movement,
    this.code,
    this.error,
  });

  factory MisfortuneState.initial({
    required String? code,
    required String? wheelId,
  }) {
    final browser = Browser();
    if (browser.browserAgent == BrowserAgent.Safari) {
      return MisfortuneState._(
        stage: Stage.awaitingPermissions,
        tooSlow: false,
        code: code,
        wheelId: wheelId,
      );
    } else if (code == null || wheelId == null) {
      return const MisfortuneState._(
        stage: Stage.awaitingPress,
        tooSlow: false,
      );
    } else {
      return MisfortuneState._(
        stage: Stage.awaitingSpin,
        tooSlow: false,
        code: code,
        wheelId: wheelId,
      );
    }
  }

  MisfortuneState copy({
    Stage? stage,
    bool? tooSlow,
    String? wheelId,
    required String? movement,
    required String? code,
    required String? error,
  }) {
    return MisfortuneState._(
      stage: stage ?? this.stage,
      tooSlow: tooSlow ?? this.tooSlow,
      movement: movement,
      code: code,
      wheelId: wheelId ?? this.wheelId,
      error: error,
    );
  }

  MisfortuneState permissionGranted() {
    if (wheelId != null && code != null) {
      return copy(
        stage: Stage.awaitingSpin,
        movement: movement,
        code: code,
        error: error,
      );
    } else {
      return copy(
        stage: Stage.awaitingPress,
        movement: movement,
        code: null,
        wheelId: null,
        error: error,
      );
    }
  }

  MisfortuneState failed(double speed, String error) {
    return copy(
      stage: Stage.failed,
      tooSlow: false,
      movement: speed.toString(),
      code: null,
      error: error,
    );
  }

  MisfortuneState awaitPress() {
    return copy(
      stage: Stage.awaitingPress,
      tooSlow: false,
      movement: null,
      code: null,
      wheelId: null,
      error: null,
    );
  }

  MisfortuneState awaitCode() {
    return const MisfortuneState._(
      stage: Stage.scanningCode,
      tooSlow: false,
      code: null,
      wheelId: null,
      movement: null,
    );
  }

  MisfortuneState awaitSpin({
    required bool tooSlow,
    required double? speed,
    String? code,
    String? wheelId,
    String? movement,
  }) {
    return copy(
      stage: Stage.awaitingSpin,
      tooSlow: tooSlow,
      movement: movement ?? speed?.toString(),
      code: code ?? this.code,
      wheelId: wheelId ?? this.wheelId,
      error: null,
    );
  }

  MisfortuneState spinning(double speed) {
    return copy(
      stage: Stage.spinning,
      tooSlow: false,
      movement: speed.toString(),
      code: null,
      error: null,
    );
  }
}

class MisfortuneBloc extends Bloc<_MisfortuneEvent, MisfortuneState> {
  final MisfortuneClient _client;
  StreamSubscription? _subscription;

  MisfortuneBloc({
    required MisfortuneClient client,
    required String? code,
    required String? wheelId,
  }) : _client = client,
       super(MisfortuneState.initial(code: code, wheelId: wheelId)) {
    if (state.stage == Stage.awaitingPermissions) {
      requestSafariPermissions();
    } else if (code != null) {
      _subscribe();
    }
    on<_AccelEvent>(_accel, transformer: sequential());
    on<_PermissionResultEvent>(_receivedPermissionResult);
    on<PressButtonEvent>(_pressButton);
    on<ScanQrEvent>(_scanQr);
  }

  void requestSafariPermissions() {
    requestDeviceMotionEventPermission(
      (result) => add(_PermissionResultEvent(result)),
    );
  }

  double generalNorm(List<double> axes) {
    double sum = 0;
    for (final axis in axes) {
      sum += pow(axis, 2);
    }
    final result = pow(sum, 1 / axes.length);
    return result.toDouble();
  }

  double norm({required double x, required double y}) {
    return sqrt(pow(x, 2) + pow(y, 2));
  }

  FutureOr<void> _accel(
    _AccelEvent event,
    Emitter<MisfortuneState> emit,
  ) async {
    if (state.stage != Stage.awaitingSpin) {
      return;
    }

    final accel = event.event;
    final speed = accel.x.abs();

    if (speed < 20) {
      if (speed > 5) {
        emit(state.awaitSpin(tooSlow: true, speed: speed));
      }
      return;
    }

    try {
      final result = await _client.spin(
        wheelId: state.wheelId!,
        code: state.code!,
        speed: speed,
      );
      if (result) {
        emit(state.spinning(speed));
      } else {
        emit(state.failed(speed, 'Jemand anderes war schneller'));
      }
    } on Exception catch (e) {
      emit(state.failed(speed, e.toString()));
    }

    _subscription?.cancel();
    await Future.delayed(const Duration(seconds: 5));
    emit(state.awaitPress());
  }

  void _subscribe() {
    _subscription = Motion.subscribe((event) => add(_AccelEvent(event)));
  }

  FutureOr<void> _receivedPermissionResult(
    _PermissionResultEvent event,
    Emitter<MisfortuneState> emit,
  ) {
    if (event.result == 'granted') {
      emit(state.permissionGranted());
    } else {
      emit(
        state.copy(
          movement: null,
          code: null,
          error: 'Did not get permission: ${event.result}',
        ),
      );
    }
  }

  FutureOr<void> _scanQr(ScanQrEvent event, Emitter<MisfortuneState> emit) {
    _subscribe();
    emit(
      state.awaitSpin(
        tooSlow: false,
        speed: null,
        code: event.code,
        wheelId: event.wheelId,
      ),
    );
  }

  FutureOr<void> _pressButton(
    PressButtonEvent event,
    Emitter<MisfortuneState> emit,
  ) {
    emit(state.awaitCode());
  }
}
