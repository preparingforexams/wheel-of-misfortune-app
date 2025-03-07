@JS()
library;

import 'package:js/js.dart';

void requestDeviceMotionEventPermission(void Function(String?) callback) {
  _requestDeviceMotionEventPermission(allowInterop(callback));
}

@JS('requestDeviceMotionEventPermission')
external void _requestDeviceMotionEventPermission(
  void Function(String?) callback,
);
