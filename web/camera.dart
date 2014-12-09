library camera;

import 'dart:math' as math;
import 'package:vector_math/vector_math.dart';

class FPSCamera {
  Vector3 camera_pos, forward;
  Vector3 y_axis, x_axis;
  num angleX = 0.0, angleY = 0.0;
  Quaternion camera_rotX, camera_rotY;

  Matrix4 view_matrix;
  Matrix4 projection_matrix;

  num aspect_ratio;
  static const num FOV = math.PI/4;

  static const num LOOK_SPEED = 0.02;
  static const num MOVE_SPEED = 0.25;

  // enums implemented in 1.8, should really upgrade
  static const TURN_UP    = 0;
  static const TURN_DOWN  = 1;
  static const TURN_LEFT  = 2;
  static const TURN_RIGHT = 3;
  
  static const FORWARD = 4;
  static const BACK = 5;
  static const S_LEFT = 6;
  static const S_RIGHT = 7;
  static const DESCEND = 8;
  static const ASCEND = 9;

  FPSCamera(num aspect_ratio) {
    this.aspect_ratio = aspect_ratio;

    y_axis = new Vector3(0.0, 1.0, 0.0);
    x_axis = new Vector3(1.0, 0.0, 0.0);

    camera_pos = new Vector3(0.0, 3.0, 10.0);
    forward = new Vector3(0.0, 0.0, -1.0);

    camera_rotX = new Quaternion.axisAngle(y_axis, angleX);
    camera_rotY = new Quaternion.axisAngle(x_axis, angleY);
    
    projection_matrix = makePerspectiveMatrix(FOV,
        aspect_ratio, 1.0, 100.0);

    view_matrix = new Matrix4.identity();
    update_view();
  }

  void move_keyboard(List<int> directions) {
    Vector3 camera_move = new Vector3.zero();
    for (int direction in directions) {
      switch (direction) {
        // not sure how to limit the speed when looking up and sideways at the same time
        case (TURN_UP):
          angleY = math.min(angleY+LOOK_SPEED, math.PI/2);
          camera_rotY.setAxisAngle(x_axis, angleY);
          break;
        case (TURN_DOWN):
          angleY = math.max(angleY-LOOK_SPEED, -math.PI/2);
          camera_rotY.setAxisAngle(x_axis, angleY);
          break;
        case (TURN_LEFT):
          angleX+=LOOK_SPEED;
          camera_rotX.setAxisAngle(y_axis, angleX);
          break;
        case (TURN_RIGHT):
          angleX-=LOOK_SPEED;
          camera_rotX.setAxisAngle(y_axis, angleX);
          break;

        case (FORWARD):
          // not 100% sure why we have to rotate by the inverse 
          Vector3 dir = camera_rotX.inverted().rotated(forward);
          camera_move+=(dir);
          break;
        case (BACK):
          Vector3 dir = camera_rotX.inverted().rotated(forward);
          camera_move-=(dir);
          break;
        case (S_LEFT):
          Vector3 dir = camera_rotX.inverted().rotated(x_axis);
          camera_move-=(dir);
          break;
        case (S_RIGHT):
          Vector3 dir = camera_rotX.inverted().rotated(x_axis);
          camera_move+=(dir);
          break;
        case (ASCEND):
          camera_move+=(y_axis);
          break;
        case (DESCEND):
          camera_move-=(y_axis);
          break;
        default:
          break;
      }
    }
    camera_pos += camera_move.normalized()*MOVE_SPEED;
  }

  void move_mouse(num dx, dy) {
    angleY = (angleY-dy*LOOK_SPEED*0.05).clamp(-math.PI/2, math.PI/2);
    angleX -= dx*LOOK_SPEED*0.05;

    camera_rotX.setAxisAngle(y_axis, angleX);
    camera_rotY.setAxisAngle(x_axis, angleY);
  }

  void move_touch(num dx, dy) {
    angleY = (angleY-dy*LOOK_SPEED*0.5).clamp(-math.PI/2, math.PI/2);
    angleX -= dx*LOOK_SPEED*0.5;

    camera_rotX.setAxisAngle(y_axis, angleX);
    camera_rotY.setAxisAngle(x_axis, angleY);
  }

  void update_view() {
    // this is unoptimized
    view_matrix.setFromTranslationRotation(camera_pos,
        (camera_rotX*camera_rotY)
    ).invert();
  }
}
