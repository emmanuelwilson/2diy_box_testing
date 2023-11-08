import processing.serial.*;
import static java.util.concurrent.TimeUnit.*;
import java.util.concurrent.*;
import java.lang.System;
import controlP5.*;
import netP5.*;
import oscP5.*;

private final ScheduledExecutorService scheduler = Executors.newScheduledThreadPool(2);

public enum HaplyVersion {
  V2,
  V3,
  V3_1
}

final HaplyVersion version = HaplyVersion.V3_1;
ControlP5 cp5;
Knob k, b, maxAL, maxAH;
long currTime, lastTime = 0;

/** 2DIY setup */
Board haplyBoard;
Device widget;
Mechanisms pantograph;

byte widgetID = 5;
int CW = 0;
int CCW = 1;
boolean renderingForce = false; 
long baseFrameRate = 120;
ScheduledFuture<?> handle;
Filter filt;
Table log;

PVector angles = new PVector(0, 0);
PVector torques = new PVector(0, 0);
PVector posEE = new PVector(0, 0);
PVector posEELast = new PVector(0, 0);
PVector velEE = new PVector(0, 0);
PVector fEE = new PVector(0, 0);

final float targetRate = 1000f;
final float textureConst = 2*PI/targetRate;
PVector fText = new PVector(0, 0);
int boxnum = 0;

/** Params */
//HapticBox[] boxes = {
//  new HapticBox(-0.02, 0.06, 0.01),
//  new HapticBox(0.02, 0.06, 0.01),
//  new HapticBox(-0.02, 0.10, 0.01),
//  new HapticBox(0.02, 0.10, 0.01),
//  new HapticBox(-0.06, 0.06, 0.01),
//  new HapticBox(-0.06, 0.10, 0.01),
//  new HapticBox(-0.10, 0.06, 0.01),
//  new HapticBox(-0.10, 0.10, 0.01),
//  new HapticBox(0.06, 0.06, 0.01),
//  new HapticBox(0.06, 0.10, 0.01)
//};

HapticBox[] boxes = {
   new HapticBox(-0.03,0.05,0.01,0.01),
   new HapticBox(0.01,0.05,0.01,0.01),
   new HapticBox(-0.03,0.09,0.01,0.01),
   new HapticBox(0.01,0.09,0.01,0.01),
   new HapticBox(-0.07,0.05,0.01,0.01),
   new HapticBox(-0.07,0.09,0.01,0.01),
   new HapticBox(-0.11,0.05,0.01,0.01),
   new HapticBox(-0.11,0.09,0.01,0.01),
   new HapticBox(0.05,0.05,0.01,0.01),
   new HapticBox(0.05,0.09,0.01,0.01)
};

String selText = "Upper Left";
float maxSpeed = 0f;

/** OSC */
final int destination = 8080;
final int source = 8081;
final NetAddress oscDestination = new NetAddress("127.0.0.1", destination);
OscP5 oscp5 = new OscP5(this, source);

/** Main thread */
void setup() {
  size(1000, 650);
  frameRate(baseFrameRate);
  filt = new Butter2();
  log = new Table();
  log.addColumn("force");
  
  /** Controls */
  cp5 = new ControlP5(this);
  k = cp5.addKnob("k")
    .plugTo(boxes[0])
    .setRange(0, 500)
    .setValue(0)
    .setPosition(50, 25)
    .setRadius(50)
    .setCaptionLabel("Spring k")
    .setColorCaptionLabel(color(20, 20, 20))
    .setDragDirection(Knob.VERTICAL);
  b = cp5.addKnob("mu")
    .plugTo(boxes[0])
    .setRange(0, 1.0)
    .setValue(0) // unitless
    .setPosition(50, 150)
    .setRadius(50)
    .setCaptionLabel("Friction mu")
    .setColorCaptionLabel(color(20, 20, 20))
    .setDragDirection(Knob.VERTICAL);
  maxAL = cp5.addKnob("maxAL")
    .plugTo(boxes[0])
    .setRange(0, 2)
    .setValue(0)
    .setPosition(50, 275)
    .setRadius(50)
    .setCaptionLabel("Low Texture Amp. (N)")
    .setColorCaptionLabel(color(20, 20, 20))
    .setDragDirection(Knob.VERTICAL);
  maxAH = cp5.addKnob("maxAH")
    .plugTo(boxes[0])
    .setRange(0, 2)
    .setValue(0)
    .setPosition(50, 400)
    .setRadius(50)
    .setCaptionLabel("Texture Amp. (N)")
    .setColorCaptionLabel(color(20, 20, 20))
    .setDragDirection(Knob.VERTICAL);
    
  /** Haply */
  haplyBoard = new Board(this, Serial.list()[0], 0);
  widget = new Device(widgetID, haplyBoard);
  if (version == HaplyVersion.V2) {
    pantograph = new Pantograph();
    widget.set_mechanism(pantograph);
    widget.add_actuator(1, CCW, 2);
    widget.add_actuator(2, CW, 1);
    widget.add_encoder(1, CCW, 241, 10752, 2);
    widget.add_encoder(2, CW, -61, 10752, 1);
  } else if (version == HaplyVersion.V3 || version == HaplyVersion.V3_1) {
    pantograph = new Pantographv3();
    widget.set_mechanism(pantograph);
    widget.add_actuator(1, CCW, 2);
    widget.add_actuator(2, CCW, 1);
    if (version == HaplyVersion.V3) {
      widget.add_encoder(1, CCW, 97.23, 2048*2.5*1.0194*1.0154, 2);   //right in theory
      widget.add_encoder(2, CCW, 82.77, 2048*2.5*1.0194, 1);    //left in theory
    } else {
      widget.add_encoder(1, CCW, 168, 4880, 2);
      widget.add_encoder(2, CCW, 12, 4880, 1); 

    }
  }
  widget.device_set_parameters();
  panto_setup();
  
  /** Spawn haptics thread */
  SimulationThread st = new SimulationThread();
  OscThread ot = new OscThread();
  handle = scheduler.scheduleAtFixedRate(st, 1000, (long)(1000000f / targetRate), MICROSECONDS);
  scheduler.scheduleAtFixedRate(ot, 1, 10, MILLISECONDS);
}

void exit() {
  handle.cancel(true);
  scheduler.shutdown();
  widget.set_device_torques(new float[]{0, 0});
  widget.device_write_torques();
  saveTable(log, "log.csv");
  super.exit();
}

void draw() {
  if (renderingForce == false) {
    background(255);
    for (HapticBox s : boxes) {
      shape(create_box(s.topLeft.x, s.topLeft.y, s.L, s.W));
    }
    update_animation(angles.x * radsPerDegree, angles.y * radsPerDegree, posEE.x, posEE.y);
    fill(0, 0, 0);
    textAlign(RIGHT);
    text("Delay (us): " + nf((int)((currTime - lastTime) / 1000), 4), 800, 40);
    text("Vel (mm/s): " + nf((int)(velEE.mag() * 1000), 3), 800, 60);
    text("Max speed (mm/s): " + nf((int)(maxSpeed * 1000), 3), 800, 80);
    text("Texture (N): " + nf((int)fText.mag()), 800, 100);
    textAlign(CENTER);
    text(selText, 100, 20);
    fill(255, 255, 255);
  }
}

void keyPressed() {
  if (key == 'r' || key == 'R') {
    maxSpeed = 0;
  }
  else if (key == '1') {
    for (HapticBox s : boxes) {
      k.unplugFrom(s);
      b.unplugFrom(s);
      maxAL.unplugFrom(s);
      maxAH.unplugFrom(s);
    }
    boxnum = 0;
    k.plugTo(boxes[boxnum]).setValue(boxes[boxnum].k);
    b.plugTo(boxes[boxnum]).setValue(boxes[boxnum].mu);
    maxAL.plugTo(boxes[boxnum]).setValue(boxes[boxnum].maxAL);
    maxAH.plugTo(boxes[boxnum]).setValue(boxes[boxnum].maxAH);
    selText = "Upper middle";
    
    print("  Top Left: " + boxes[boxnum].getTopLeft());
    print("  Top Right: " + boxes[boxnum].getTopRight());
    print("  Bottom Left: " + boxes[boxnum].getBottomLeft());
    print("  Bottom Rightz: " + boxes[boxnum].getBottomRight());
  }
  else if (key == '2') {
    for (HapticBox s : boxes) {
      k.unplugFrom(s);
      b.unplugFrom(s);
      maxAL.unplugFrom(s);
      maxAH.unplugFrom(s);
    }
    boxnum = 1;
    k.plugTo(boxes[boxnum]).setValue(boxes[boxnum].k);
    b.plugTo(boxes[boxnum]).setValue(boxes[boxnum].mu);
    maxAL.plugTo(boxes[boxnum]).setValue(boxes[boxnum].maxAL);
    maxAH.plugTo(boxes[boxnum]).setValue(boxes[boxnum].maxAH);
    selText = "Upper middle Right";
  }
  else if (key == '3') {
    for (HapticBox s : boxes) {
      k.unplugFrom(s);
      b.unplugFrom(s);
      maxAL.unplugFrom(s);
      maxAH.unplugFrom(s);
    }
    boxnum = 2;
    k.plugTo(boxes[boxnum]).setValue(boxes[boxnum].k);
    b.plugTo(boxes[boxnum]).setValue(boxes[boxnum].mu);
    maxAL.plugTo(boxes[boxnum]).setValue(boxes[boxnum].maxAL);
    maxAH.plugTo(boxes[boxnum]).setValue(boxes[boxnum].maxAH);
    selText = "Bottom middle";
  }
  else if (key == '4') {
    for (HapticBox s : boxes) {
      k.unplugFrom(s);
      b.unplugFrom(s);
      maxAL.unplugFrom(s);
      maxAH.unplugFrom(s);
    }
    boxnum = 3;
    k.plugTo(boxes[boxnum]).setValue(boxes[boxnum].k);
    b.plugTo(boxes[boxnum]).setValue(boxes[boxnum].mu);
    maxAL.plugTo(boxes[boxnum]).setValue(boxes[boxnum].maxAL);
    maxAH.plugTo(boxes[boxnum]).setValue(boxes[boxnum].maxAH);
    selText = "Bottom middle Right";
  }
  else if (key == '5') {
    for (HapticBox s : boxes) {
      k.unplugFrom(s);
      b.unplugFrom(s);
      maxAL.unplugFrom(s);
      maxAH.unplugFrom(s);
    }
    boxnum = 4;
    k.plugTo(boxes[boxnum]).setValue(boxes[boxnum].k);
    b.plugTo(boxes[boxnum]).setValue(boxes[boxnum].mu);
    maxAL.plugTo(boxes[boxnum]).setValue(boxes[boxnum].maxAL);
    maxAH.plugTo(boxes[boxnum]).setValue(boxes[boxnum].maxAH);
    selText = "Upper middle left";
  }
  else if (key == '6') {
    for (HapticBox s : boxes) {
      k.unplugFrom(s);
      b.unplugFrom(s);
      maxAL.unplugFrom(s);
      maxAH.unplugFrom(s);
    }
    boxnum = 5;
    k.plugTo(boxes[boxnum]).setValue(boxes[boxnum].k);
    b.plugTo(boxes[boxnum]).setValue(boxes[boxnum].mu);
    maxAL.plugTo(boxes[boxnum]).setValue(boxes[boxnum].maxAL);
    maxAH.plugTo(boxes[boxnum]).setValue(boxes[boxnum].maxAH);
    selText = "Bottom Middle Left";
  }
  else if (key == '7') {
    for (HapticBox s : boxes) {
      k.unplugFrom(s);
      b.unplugFrom(s);
      maxAL.unplugFrom(s);
      maxAH.unplugFrom(s);
    }
    boxnum = 6;
    k.plugTo(boxes[boxnum]).setValue(boxes[boxnum].k);
    b.plugTo(boxes[boxnum]).setValue(boxes[boxnum].mu);
    maxAL.plugTo(boxes[boxnum]).setValue(boxes[boxnum].maxAL);
    maxAH.plugTo(boxes[boxnum]).setValue(boxes[boxnum].maxAH);
    selText = "Upper Left";
  }
  else if (key == '8') {
    for (HapticBox s : boxes) {
      k.unplugFrom(s);
      b.unplugFrom(s);
      maxAL.unplugFrom(s);
      maxAH.unplugFrom(s);
    }
    boxnum = 7;
    k.plugTo(boxes[boxnum]).setValue(boxes[boxnum].k);
    b.plugTo(boxes[boxnum]).setValue(boxes[boxnum].mu);
    maxAL.plugTo(boxes[boxnum]).setValue(boxes[boxnum].maxAL);
    maxAH.plugTo(boxes[boxnum]).setValue(boxes[boxnum].maxAH);
    selText = "Bottom Left";
  }else if (key == '9') {
    for (HapticBox s : boxes) {
      k.unplugFrom(s);
      b.unplugFrom(s);
      maxAL.unplugFrom(s);
      maxAH.unplugFrom(s);
    }
    boxnum = 8;
    k.plugTo(boxes[boxnum]).setValue(boxes[boxnum].k);
    b.plugTo(boxes[boxnum]).setValue(boxes[boxnum].mu);
    maxAL.plugTo(boxes[boxnum]).setValue(boxes[boxnum].maxAL);
    maxAH.plugTo(boxes[boxnum]).setValue(boxes[boxnum].maxAH);
    selText = "Upper Right";
  }
  else if (key == '0') {
    for (HapticBox s : boxes) {
      k.unplugFrom(s);
      b.unplugFrom(s);
      maxAL.unplugFrom(s);
      maxAH.unplugFrom(s);
    }
    boxnum = 9;
    k.plugTo(boxes[boxnum]).setValue(boxes[boxnum].k);
    b.plugTo(boxes[boxnum]).setValue(boxes[boxnum].mu);
    maxAL.plugTo(boxes[boxnum]).setValue(boxes[boxnum].maxAL);
    maxAH.plugTo(boxes[boxnum]).setValue(boxes[boxnum].maxAH);
    selText = "Bottom Right";
  }
  else if (key == 't') {
    if (posEE.x >= boxes[boxnum].getTopLeft().x){
     print(" X > BOX = TRUE       "); 
    }else {
      print(" X > BOX = FALSE       "); 
    }
    
    if (posEE.x <= boxes[boxnum].getTopRight().x) {
      print(" X < BOX = TRUE       ") ;
    }else {
      print(" X < BOX = FALSE       ") ;
    }
    if (posEE.y >= boxes[boxnum].getTopLeft().y) {
      print(" Y > BOX = TRUE       ") ;
    }else {
      print(" Y > BOX = FALSE       ") ;
    }
    
    if(posEE.y <= boxes[boxnum].getBottomLeft().y){
      print(" Y > BOX = TRUE       "); 
    }else {
      print(" Y > BOX = FALSE       "); 
    }
  }
  else if (key == 'c') {
    print(" Position of Cursor is : " + posEE + "    ");
  }
  else if (key == 'w') {
    saveTable(log, "log.csv");
  }
}

/** Helper */
PVector device_to_graphics(PVector deviceFrame) {
  return deviceFrame.set(-deviceFrame.x, deviceFrame.y);
}

PVector graphics_to_device(PVector graphicsFrame) {
  return graphicsFrame.set(-graphicsFrame.x, graphicsFrame.y);
}
