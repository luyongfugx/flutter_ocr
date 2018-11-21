// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'dart:math' as math;


/// The possible states of a [ScaleGestureRecognizer].
enum _ScaleRotateState {
  /// The recognizer is ready to start recognizing a gesture.
  ready,

  /// The sequence of pointer events seen thus far is consistent with a scale
  /// gesture but the gesture has not been accepted definitively.
  possible,

  /// The sequence of pointer events seen thus far has been accepted
  /// definitively as a scale gesture.
  accepted,

  /// The sequence of pointer events seen thus far has been accepted
  /// definitively as a scale gesture and the pointers established a focal point
  /// and initial scale.
  started,
}

/// Details for [GestureScaleStartCallback].
class ScaleRotateStartDetails {
  /// Creates details for [GestureScaleStartCallback].
  ///
  /// The [focalPoint] argument must not be null.
  ScaleRotateStartDetails({ this.focalPoint: Offset.zero })
      : assert(focalPoint != null);

  /// The initial focal point of the pointers in contact with the screen.
  /// Reported in global coordinates.
  final Offset focalPoint;

  @override
  String toString() => 'ScaleRotateStartDetails(focalPoint: $focalPoint)';
}

/// Details for [GestureScaleUpdateCallback].
class ScaleRotateUpdateDetails {
  /// Creates details for [GestureScaleUpdateCallback].
  ///
  /// The [focalPoint], [scale] and [rotation] arguments must not be null. The [scale]
  /// argument must be greater than or equal to zero.
  ScaleRotateUpdateDetails({
    this.focalPoint: Offset.zero,
    this.scale: 1.0,
    this.rotation: 0.0,
  }) : assert(focalPoint != null),
        assert(scale != null && scale >= 0.0),
        assert(rotation != null);

  /// The focal point of the pointers in contact with the screen. Reported in
  /// global coordinates.
  final Offset focalPoint;

  /// The scale implied by the pointers in contact with the screen. A value
  /// greater than or equal to zero.
  final double scale;

  /// The Rotation implied by the first two pointers to enter in contact with
  /// the screen. Expressed in radians.
  final double rotation;

  @override
  String toString() => 'ScaleRotateUpdateDetails(focalPoint: $focalPoint, scale: $scale, rotation: $rotation)';
}

/// Details for [GestureScaleEndCallback].
class ScaleRotateEndDetails {
  /// Creates details for [GestureScaleEndCallback].
  ///
  /// The [velocity] argument must not be null.
  ScaleRotateEndDetails({ this.velocity: Velocity.zero })
      : assert(velocity != null);

  /// The velocity of the last pointer to be lifted off of the screen.
  final Velocity velocity;

  @override
  String toString() => 'ScaleRotateEndDetails(velocity: $velocity)';
}

/// Signature for when the pointers in contact with the screen have established
/// a focal point and initial scale of 1.0.
typedef void GestureRotateScaleStartCallback(ScaleRotateStartDetails details);

/// Signature for when the pointers in contact with the screen have indicated a
/// new focal point and/or scale.
typedef void GestureRotateScaleUpdateCallback(ScaleRotateUpdateDetails details);

/// Signature for when the pointers are no longer in contact with the screen.
typedef void GestureRotateScaleEndCallback(ScaleRotateEndDetails details);

bool _isFlingGesture(Velocity velocity) {
  assert(velocity != null);
  final double speedSquared = velocity.pixelsPerSecond.distanceSquared;
  return speedSquared > kMinFlingVelocity * kMinFlingVelocity;
}


/// Defines a line between two pointers on screen.
///
/// [_LineBetweenPointers] is an abstraction of a line between two pointers in
/// contact with the screen. Used to track the rotation of a scale gesture.
class _LineBetweenPointers{

  /// Creates a [_LineBetweenPointers]. None of the [pointerStartLocation], [pointerStartId]
  /// [pointerEndLocation] and [pointerEndId] must be null. [pointerStartId] and [pointerEndId]
  /// should be different.
  _LineBetweenPointers({
    this.pointerStartLocation,
    this.pointerStartId,
    this.pointerEndLocation,
    this.pointerEndId
  }) : assert(pointerStartLocation != null && pointerEndLocation != null),
        assert(pointerStartId != null && pointerEndId != null),
        assert(pointerStartId != pointerEndId);

  /// The location and the id of the pointer that marks the start of the line,
  final Offset pointerStartLocation;
  final int pointerStartId;

  /// The location and the id of the pointer that marks the end of the line,
  final Offset pointerEndLocation;
  final int pointerEndId;

}


/// Recognizes a scale gesture.
///
/// [ScaleGestureRecognizer] tracks the pointers in contact with the screen and
/// calculates their focal point, indicated scale and rotation. When a focal pointer is
/// established, the recognizer calls [onStart]. As the focal point, scale and rotation
/// change, the recognizer calls [onUpdate]. When the pointers are no longer in
/// contact with the screen, the recognizer calls [onEnd].
class ScaleRotateGestureRecognizer extends OneSequenceGestureRecognizer {
  /// Create a gesture recognizer for interactions intended for scaling content.
  ScaleRotateGestureRecognizer({ Object debugOwner }) : super(debugOwner: debugOwner);

  /// The pointers in contact with the screen have established a focal point and
  /// initial scale of 1.0.
  GestureRotateScaleStartCallback onStart;

  /// The pointers in contact with the screen have indicated a new focal point
  /// and/or scale.
  GestureRotateScaleUpdateCallback onUpdate;

  /// The pointers are no longer in contact with the screen.
  GestureRotateScaleEndCallback onEnd;

  _ScaleRotateState _state = _ScaleRotateState.ready;

  Offset _initialFocalPoint;
  Offset _currentFocalPoint;
  double _initialSpan;
  double _currentSpan;
  _LineBetweenPointers _initialLine;
  _LineBetweenPointers _currentLine;
  Map<int, Offset> _pointerLocations;
  /// A queue to sort pointers in order of entrance
  List<int> _pointerQueue;
  final Map<int, VelocityTracker> _velocityTrackers = <int, VelocityTracker>{};

  double get _scaleFactor => _initialSpan > 0.0 ? _currentSpan / _initialSpan : 1.0;

  double _rotationFactor () {
    if(_initialLine == null || _currentLine == null){
      return 0.0;
    }
    final double fx = _initialLine.pointerStartLocation.dx;
    final double fy = _initialLine.pointerStartLocation.dy;
    final double sx = _initialLine.pointerEndLocation.dx;
    final double sy = _initialLine.pointerEndLocation.dy;

    final double nfx = _currentLine.pointerStartLocation.dx;
    final double nfy = _currentLine.pointerStartLocation.dy;
    final double nsx = _currentLine.pointerEndLocation.dx;
    final double nsy = _currentLine.pointerEndLocation.dy;

    final double angle1 = math.atan2(fy - sy, fx - sx);
    final double angle2 = math.atan2(nfy - nsy, nfx - nsx);

    return angle2 - angle1;
  }

  @override
  void addPointer(PointerEvent event) {
    startTrackingPointer(event.pointer);
    _velocityTrackers[event.pointer] = new VelocityTracker();
    if (_state == _ScaleRotateState.ready) {
      _state = _ScaleRotateState.possible;
      _initialSpan = 0.0;
      _currentSpan = 0.0;
      _pointerLocations = <int, Offset>{};
      _pointerQueue = [];
    }
  }

  @override
  void handleEvent(PointerEvent event) {
    assert(_state != _ScaleRotateState.ready);
    bool didChangeConfiguration = false;
    bool shouldStartIfAccepted = false;
    if (event is PointerMoveEvent) {
      final VelocityTracker tracker = _velocityTrackers[event.pointer];
      assert(tracker != null);
      if (!event.synthesized)
        tracker.addPosition(event.timeStamp, event.position);
      _pointerLocations[event.pointer] = event.position;
      shouldStartIfAccepted = true;
    } else if (event is PointerDownEvent) {
      _pointerLocations[event.pointer] = event.position;
      _pointerQueue.add(event.pointer);
      didChangeConfiguration = true;
      shouldStartIfAccepted = true;
    } else if (event is PointerUpEvent || event is PointerCancelEvent) {
      _pointerLocations.remove(event.pointer);
      _pointerQueue.remove(event.pointer);
      didChangeConfiguration = true;
    }

    _updateLines();
    _update();

    if (!didChangeConfiguration || _reconfigure(event.pointer))
      _advanceStateMachine(shouldStartIfAccepted);
    stopTrackingIfPointerNoLongerDown(event);
  }

  void _update() {
    final int count = _pointerLocations.keys.length;

    // Compute the focal point
    Offset focalPoint = Offset.zero;
    for (int pointer in _pointerLocations.keys)
      focalPoint += _pointerLocations[pointer];
    _currentFocalPoint = count > 0 ? focalPoint / count.toDouble() : Offset.zero;

    // Span is the average deviation from focal point
    double totalDeviation = 0.0;
    for (int pointer in _pointerLocations.keys)
      totalDeviation += (_currentFocalPoint - _pointerLocations[pointer]).distance;
    _currentSpan = count > 0 ? totalDeviation / count : 0.0;
  }

  /// Updates [_initialLine] and [_currentLine] accordingly to the situation of
  /// the registered pointers
  void _updateLines(){
    final int count = _pointerLocations.keys.length;

    /// In case of just one pointer registered, reconfigure [_initialLine]
    if(count < 2 ){
      _initialLine = _currentLine;
    } else if(_initialLine != null
        && _initialLine.pointerStartId == _pointerQueue[0]
        && _initialLine.pointerEndId == _pointerQueue[1]){
      /// Rotation updated, set the [_currentLine]
      _currentLine = new _LineBetweenPointers(
          pointerStartId: _pointerQueue[0],
          pointerStartLocation: _pointerLocations[_pointerQueue[0]],
          pointerEndId: _pointerQueue[1],
          pointerEndLocation: _pointerLocations[ _pointerQueue[1]]
      );
    } else {
      /// A new rotation process is on the way, set the [_initialLine]
      _initialLine = new _LineBetweenPointers(
          pointerStartId: _pointerQueue[0],
          pointerStartLocation: _pointerLocations[_pointerQueue[0]],
          pointerEndId: _pointerQueue[1],
          pointerEndLocation: _pointerLocations[ _pointerQueue[1]]
      );
      _currentLine = null;
    }
  }

  bool _reconfigure(int pointer) {
    _initialFocalPoint = _currentFocalPoint;
    _initialSpan = _currentSpan;
    _initialLine = _currentLine;
    if (_state == _ScaleRotateState.started) {
      if (onEnd != null) {
        final VelocityTracker tracker = _velocityTrackers[pointer];
        assert(tracker != null);

        Velocity velocity = tracker.getVelocity();
        if (_isFlingGesture(velocity)) {
          final Offset pixelsPerSecond = velocity.pixelsPerSecond;
          if (pixelsPerSecond.distanceSquared > kMaxFlingVelocity * kMaxFlingVelocity)
            velocity = new Velocity(pixelsPerSecond: (pixelsPerSecond / pixelsPerSecond.distance) * kMaxFlingVelocity);
          invokeCallback<void>('onEnd', () => onEnd(new ScaleRotateEndDetails(velocity: velocity)));
        } else {
          invokeCallback<void>('onEnd', () => onEnd(new ScaleRotateEndDetails(velocity: Velocity.zero)));
        }
      }
      _state = _ScaleRotateState.accepted;
      return false;
    }
    return true;
  }

  void _advanceStateMachine(bool shouldStartIfAccepted) {
    if (_state == _ScaleRotateState.ready)
      _state = _ScaleRotateState.possible;

    if (_state == _ScaleRotateState.possible) {
      final double spanDelta = (_currentSpan - _initialSpan).abs();
      final double focalPointDelta = (_currentFocalPoint - _initialFocalPoint).distance;
      if (spanDelta > kScaleSlop || focalPointDelta > kPanSlop)
        resolve(GestureDisposition.accepted);
    } else if (_state.index >= _ScaleRotateState.accepted.index) {
      resolve(GestureDisposition.accepted);
    }

    if (_state == _ScaleRotateState.accepted && shouldStartIfAccepted) {
      _state = _ScaleRotateState.started;
      _dispatchOnStartCallbackIfNeeded();
    }

    if (_state == _ScaleRotateState.started && onUpdate != null)
      invokeCallback<void>('onUpdate', () => onUpdate(new ScaleRotateUpdateDetails(scale: _scaleFactor, focalPoint: _currentFocalPoint, rotation: _rotationFactor())));
  }

  void _dispatchOnStartCallbackIfNeeded() {
    assert(_state == _ScaleRotateState.started);
    if (onStart != null)
      invokeCallback<void>('onStart', () => onStart(new ScaleRotateStartDetails(focalPoint: _currentFocalPoint)));
  }

  @override
  void acceptGesture(int pointer) {
    if (_state == _ScaleRotateState.possible) {
      _state = _ScaleRotateState.started;
      _dispatchOnStartCallbackIfNeeded();
    }
  }

  @override
  void rejectGesture(int pointer) {
    stopTrackingPointer(pointer);
  }

  @override
  void didStopTrackingLastPointer(int pointer) {
    switch (_state) {
      case _ScaleRotateState.possible:
        resolve(GestureDisposition.rejected);
        break;
      case _ScaleRotateState.ready:
        assert(false); // We should have not seen a pointer yet
        break;
      case _ScaleRotateState.accepted:
        break;
      case _ScaleRotateState.started:
        assert(false); // We should be in the accepted state when user is done
        break;
    }
    _state = _ScaleRotateState.ready;
  }

  @override
  void dispose() {
    _velocityTrackers.clear();
    super.dispose();
  }

  @override
  String get debugDescription => 'scale';
}