import 'dart:async';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html';

import 'package:flutter/foundation.dart';

const kDeviceMotionEventType = 'devicemotion';

class _EventListener {
  final StreamSink<MotionEvent> _controller;

  _EventListener(this._controller);

  void call(Event event) {
    if (event is! DeviceMotionEvent) {
      return;
    }

    final acceleration = event.acceleration;

    if (acceleration == null) {
      // TODO: we could use accelerationIncludingGravity,
      // but honestly which smartphone doesn't have a gyroscope?
      return;
    }

    // TODO: chrome and firefox handle coordinates differently?
    final motionEvent = MotionEvent(
      x: acceleration.x?.toDouble() ?? 0,
      y: acceleration.y?.toDouble() ?? 0,
      z: acceleration.z?.toDouble() ?? 0,
    );

    _controller.add(motionEvent);
  }
}

@immutable
class MotionEvent {
  final double x, y, z;

  const MotionEvent({required this.x, required this.y, required this.z});

  @override
  String toString() {
    return 'x: ${x.toStringAsFixed(2)}, y: ${y.toStringAsFixed(2)}, z: ${z.toStringAsFixed(2)}';
  }
}

@immutable
class Motion {
  const Motion._();

  static StreamSubscription subscribe(void Function(MotionEvent) handler) {
    final controller = StreamController<MotionEvent>();
    final eventListener = _EventListener(controller);
    controller.onListen =
        () =>
            window.addEventListener(kDeviceMotionEventType, eventListener.call);
    controller.onCancel =
        () => window.removeEventListener(
          kDeviceMotionEventType,
          eventListener.call,
        );

    return controller.stream.listen(handler);
  }
}
