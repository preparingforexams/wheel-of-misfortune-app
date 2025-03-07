import 'dart:async';
import 'package:web/web.dart';

import 'package:flutter/foundation.dart';

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

  static MotionEvent? _convertEvent(DeviceMotionEvent event) {
    final acceleration = event.acceleration;

    if (acceleration == null) {
      // TODO: we could use accelerationIncludingGravity,
      // but honestly which smartphone doesn't have a gyroscope?
      return null;
    }

    // TODO: chrome and firefox handle coordinates differently?
    final motionEvent = MotionEvent(
      x: acceleration.x?.toDouble() ?? 0,
      y: acceleration.y?.toDouble() ?? 0,
      z: acceleration.z?.toDouble() ?? 0,
    );

    return motionEvent;
  }

  static StreamSubscription subscribe(void Function(MotionEvent) handler) {
    return EventStreamProviders.deviceMotionEvent
        .forTarget(window)
        .map(_convertEvent)
        .where((e) => e != null)
        .cast<MotionEvent>()
        .listen(handler);
  }
}
