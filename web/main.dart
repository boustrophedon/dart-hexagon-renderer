import 'dart:html';
import 'dart:web_gl' as WebGL;
import 'dart:typed_data';
import 'dart:math' as math;

import 'dart:js';

import 'package:vector_math/vector_math.dart';

import 'webgl_utils.dart';
import 'camera.dart';

// global rng
math.Random rng = new math.Random();

class Hexagon {
  Matrix4 model_matrix;
  num x_rotation = math.PI/2;
  num y_rotation = 0.0;
  num z_rotation = 0.0;
  num x,y,z;

  Hexagon(this.x, this.y, this.z) {
    model_matrix = new Matrix4.identity();
    model_matrix.setRotationX(x_rotation);
    model_matrix.rotateY(y_rotation);
    model_matrix.rotateZ(z_rotation);
    model_matrix.setTranslationRaw(x,y,z);
  }
  void update(num dt) {}
}

class HexagonRenderer {
  CanvasElement canvas;
  WebGL.RenderingContext gl;

  WebGL.Shader vertexShader;
  WebGL.Shader fragmentShader;
  WebGL.Program program;

  int positionLocation;
  int colorLocation;

  // it is silly that there's a uniformlocation class for uniforms but not attributes
  WebGL.UniformLocation mvMatrixLocation;
  WebGL.UniformLocation projectionMatrixLocation;
  
  Float32List hexagon_data;
  Float32List color_data;
  Uint16List index_data_top;
  Uint16List index_data_side;

  WebGL.Buffer hexagonBuffer;
  WebGL.Buffer colorBuffer;
  WebGL.Buffer indexBufferTop;
  WebGL.Buffer indexBufferSide;

  FPSCamera camera;

  List<Hexagon> hexagons;

  num dt = 0.0;
  num timestamp = 0.0;


  HexagonRenderer(CanvasElement canvas) {
    this.canvas = canvas;
    this.gl = canvas.getContext3d();

    if (canvas is! CanvasElement || gl is! WebGL.RenderingContext) {
      print("Failed to load canvas");
      return;
    }
    else {
      print("Loaded canvas successfully!");
    }
    gl.clearColor(0.0, 0.0, 0.0, 1.0);
    gl.enable(WebGL.DEPTH_TEST);
    gl.enable(WebGL.CULL_FACE);
    gl.cullFace(WebGL.BACK);

    gl.viewport(0, 0, canvas.width, canvas.height);

    hexagons = new List<Hexagon>();
    for (int i = -5; i<5; i++) {
      for (int j = -5; j < 5; j++) {
        add_hexagon(i, j);
      }
    }
    add_hexagon(4,4,1);
    add_hexagon(4,3,1);
    add_hexagon(4,3,2);
    add_hexagon(3,3,1);
    add_hexagon(2,3,1);

    camera = new FPSCamera(canvas.width/canvas.height);

    window.onKeyDown.listen(doKeydown);
    canvas.onMouseMove.listen(doMouse);
  }
  void doKeydown(KeyboardEvent e) {
    switch (e.keyCode) {
      case (KeyCode.UP):
        camera.move_keyboard(FPSCamera.TURN_UP);
        break;
      case (KeyCode.DOWN):
        camera.move_keyboard(FPSCamera.TURN_DOWN);
        break;
      case (KeyCode.LEFT):
        camera.move_keyboard(FPSCamera.TURN_LEFT);
        break;
      case (KeyCode.RIGHT):
        camera.move_keyboard(FPSCamera.TURN_RIGHT);
        break;
      case (KeyCode.COMMA):
        camera.move_keyboard(FPSCamera.FORWARD);
        break;
      case (KeyCode.O):
        camera.move_keyboard(FPSCamera.BACK);
        break;
      case (KeyCode.A):
        camera.move_keyboard(FPSCamera.S_LEFT);
        break;
      case (KeyCode.E):
        camera.move_keyboard(FPSCamera.S_RIGHT);
        break;
      case (KeyCode.PAGE_DOWN):
        camera.move_keyboard(FPSCamera.DESCEND);
        break;
      case (KeyCode.PAGE_UP):
        camera.move_keyboard(FPSCamera.ASCEND);
        break;
      default:
        break;
    }
  }
 
  void doMouse(MouseEvent e) {
    var js_event = new JsObject.fromBrowserObject(e);
    num dX, dY;
    if (js_event.hasProperty("mozMovementX")) {
      dX = js_event['mozMovementX'];
      dY = js_event['mozMovementY'];
    }
    else {
      dX = e.movement.x;
      dY = e.movement.y;
    }
    camera.move_mouse(dX, dY);
  }

  void add_hexagon(num x, num z, [num y]) {
    if (y == null) { y = 0.0; }
    hexagons.add(new Hexagon((x*3.0)+(z%2)*1.5, y*0.4, z*0.86));
  }

  void setup_shaders() {
    vertexShader = createShaderFromScriptElement(gl, "#v3d-vertex-shader");
    //print(gl.getShaderInfoLog(vertexShader));
    fragmentShader = createShaderFromScriptElement(gl, "#f3d-fragment-shader");
    //print(gl.getShaderInfoLog(fragmentShader));
    program = createProgram(gl, [vertexShader, fragmentShader]);

    gl.useProgram(program);

    setup_attribs();
    setup_uniforms();
  }
  void setup_attribs() {
    positionLocation = gl.getAttribLocation(program, "a_position");
    colorLocation = gl.getAttribLocation(program, "a_color");
    // enable vertex attribs moved here! 
    gl.enableVertexAttribArray(positionLocation);
    gl.enableVertexAttribArray(colorLocation);
  }
  void setup_uniforms() {
    mvMatrixLocation = gl.getUniformLocation(program, "u_mvMatrix");
    projectionMatrixLocation = gl.getUniformLocation(program, "u_pMatrix");
  }

  void setup_buffers() {
    setup_hexagon_buffer();
    setup_hexagon_color_buffer();
    setup_hexagon_index_buffer_top();
    setup_hexagon_index_buffer_side();
  }

  void setup_hexagon_buffer() {
    // 8 vertices of the hexagon, with points (x,y,z)
    // specified counterclockwise from the first quadrant
    hexagon_data = new Float32List.fromList([
         1.000,  0.000, 0.2,
         0.500,  0.866, 0.2,
        -0.500,  0.866, 0.2,
        -1.000,  0.000, 0.2,
        -0.500, -0.866, 0.2,
         0.500, -0.866, 0.2,

         1.000,  0.000, -0.2,
         0.500,  0.866, -0.2,
        -0.500,  0.866, -0.2,
        -1.000,  0.000, -0.2,
        -0.500, -0.866, -0.2,
         0.500, -0.866, -0.2
    ]);

    hexagonBuffer = gl.createBuffer();

    gl.bindBuffer(WebGL.RenderingContext.ARRAY_BUFFER, hexagonBuffer);
    gl.bufferDataTyped(WebGL.RenderingContext.ARRAY_BUFFER, hexagon_data, WebGL.RenderingContext.STATIC_DRAW);
  }

  void bind_hexagon_buffer() {
    gl.bindBuffer(WebGL.RenderingContext.ARRAY_BUFFER, hexagonBuffer);
      
    gl.vertexAttribPointer(positionLocation, 3, WebGL.RenderingContext.FLOAT, false, 0, 0);
  }

  void setup_hexagon_index_buffer_top() {
    index_data_top = new Uint16List.fromList([
        0, 1, 2, 3, 4, 5,
        6,11,10, 9, 8, 7 
    ]);

    indexBufferTop = gl.createBuffer();

    gl.bindBuffer(WebGL.RenderingContext.ELEMENT_ARRAY_BUFFER, indexBufferTop);
    gl.bufferDataTyped(WebGL.RenderingContext.ELEMENT_ARRAY_BUFFER, index_data_top, WebGL.RenderingContext.STATIC_DRAW);
  }

  void bind_hexagon_index_buffer_top() {
    gl.bindBuffer(WebGL.RenderingContext.ELEMENT_ARRAY_BUFFER, indexBufferTop);
  }

  void setup_hexagon_index_buffer_side() {
    index_data_side = new Uint16List.fromList([
        0, 6, 1, 7, 2, 8, 3, 9, 4, 10, 5, 11, 0, 6
    ]);

    indexBufferSide = gl.createBuffer();

    gl.bindBuffer(WebGL.RenderingContext.ELEMENT_ARRAY_BUFFER, indexBufferSide);
    gl.bufferDataTyped(WebGL.RenderingContext.ELEMENT_ARRAY_BUFFER, index_data_side, WebGL.RenderingContext.STATIC_DRAW);
  }

  void bind_hexagon_index_buffer_side() {
    gl.bindBuffer(WebGL.RenderingContext.ELEMENT_ARRAY_BUFFER, indexBufferSide);
  }

  void setup_hexagon_color_buffer() {
    color_data = new Float32List.fromList( [0.0, 0.3, 0.3, 1.0,
                                            0.0, 0.3, 0.3, 1.0,
                                            0.0, 0.3, 0.3, 1.0,
                                            0.0, 0.3, 0.3, 1.0,
                                            0.0, 0.3, 0.3, 1.0,
                                            0.0, 0.3, 0.3, 1.0,

                                            0.0, 0.6, 0.2, 1.0,
                                            0.0, 0.6, 0.2, 1.0,
                                            0.3, 0.6, 0.4, 1.0,
                                            0.3, 0.6, 0.4, 1.0,
                                            0.0, 0.6, 0.2, 1.0,
                                            0.0, 0.6, 0.2, 1.0]);

    colorBuffer = gl.createBuffer();
    gl.bindBuffer(WebGL.RenderingContext.ARRAY_BUFFER, colorBuffer);
    gl.bufferDataTyped(WebGL.RenderingContext.ARRAY_BUFFER, color_data, WebGL.RenderingContext.STATIC_DRAW);
  }
  void bind_hexagon_color_buffer() {
    gl.bindBuffer(WebGL.RenderingContext.ARRAY_BUFFER, colorBuffer);
    gl.vertexAttribPointer(colorLocation, 4, WebGL.RenderingContext.FLOAT, false, 0, 0);
  }

  void set_matrix_uniforms(Matrix4 model_matrix) {
    Matrix4 mvMatrix = (camera.view_matrix)*model_matrix;
    gl.uniformMatrix4fv(mvMatrixLocation, false, mvMatrix.storage);
    gl.uniformMatrix4fv(projectionMatrixLocation,
        false, camera.projection_matrix.storage);
  }

  void draw(num timestamp) {
    this.dt = timestamp - this.timestamp;
    this.timestamp = timestamp;

    gl.clear(WebGL.COLOR_BUFFER_BIT | WebGL.DEPTH_BUFFER_BIT);
    bind_hexagon_color_buffer();
    bind_hexagon_buffer();
    bind_hexagon_index_buffer_top();

    camera.update_view();
    for (Hexagon hexagon in hexagons) {
      set_matrix_uniforms(hexagon.model_matrix);

      gl.drawElements(WebGL.RenderingContext.TRIANGLE_FAN, 6, WebGL.UNSIGNED_SHORT, 0);
      gl.drawElements(WebGL.RenderingContext.TRIANGLE_FAN, 6, WebGL.UNSIGNED_SHORT, 6*Uint16List.BYTES_PER_ELEMENT);
    }

    bind_hexagon_index_buffer_side();
    for (Hexagon hexagon in hexagons) {
      set_matrix_uniforms(hexagon.model_matrix);

      gl.drawElements(WebGL.RenderingContext.TRIANGLE_STRIP, index_data_side.length, WebGL.UNSIGNED_SHORT, 0);
    }

    window.requestAnimationFrame(draw);
  }

  void start() {
    setup_shaders();
    setup_buffers();
    window.requestAnimationFrame(draw);
  }
}

void fullscreenWorkaround(CanvasElement canvas) {
  var canv = new JsObject.fromBrowserObject(canvas);

  if (canv.hasProperty("requestFullscreen")) {
    canv.callMethod("requestFullscreen");
  }
  else {
    List<String> vendors = ['moz', 'webkit', 'ms', 'o'];
    for (String vendor in vendors) {
      String vendorFullscreen = "${vendor}RequestFullscreen";
      if (vendor == 'moz') {
        vendorFullscreen = "${vendor}RequestFullScreen";
      }
      if (canv.hasProperty(vendorFullscreen)) {
        canv.callMethod(vendorFullscreen);
        return;
      }
    }
  }
}

void pointerlock_workaround(CanvasElement canvas) {
  var canv = new JsObject.fromBrowserObject(canvas);

  if (canv.hasProperty("requestPointerLock")) {
    canv.callMethod("requestPointerLock");
  }
  else {
    List<String> vendors = ['moz', 'webkit', 'ms', 'o'];
    for (String vendor in vendors) {
      String vendorPointerLock = "${vendor}RequestPointerLock";
      if (canv.hasProperty(vendorPointerLock)) {
        canv.callMethod(vendorPointerLock);
        return;
      }
    }
    print("your browser does not appear to support the pointerlock api");
  }
}

void main() {
  CanvasElement canvas = querySelector("#canvas-area");
  canvas.height = window.innerHeight;
  canvas.width = window.innerWidth;

  window.onResize.listen((e) {
    canvas.height = window.innerHeight;
    canvas.width = window.innerWidth;
  });
  canvas.onClick.listen((e) {
    fullscreenWorkaround(canvas);
    pointerlock_workaround(canvas);
  });
  HexagonRenderer r = new HexagonRenderer(canvas);
  r.start();
}
