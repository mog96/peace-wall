import com.pi4j.concurrent.*;
import com.pi4j.io.gpio.event.*;
import com.pi4j.io.gpio.exception.*;
import com.pi4j.io.gpio.*;
import com.pi4j.io.gpio.tasks.impl.*;
import com.pi4j.io.serial.*;
import com.pi4j.io.serial.impl.*;
import com.pi4j.io.spi.*;
import com.pi4j.io.w1.*;
import com.pi4j.jni.*;
import com.pi4j.system.*;
import com.pi4j.io.file.*;
import com.pi4j.io.gpio.trigger.*;
import com.pi4j.io.i2c.*;
import com.pi4j.io.i2c.impl.*;
import com.pi4j.io.serial.tasks.*;
import com.pi4j.io.spi.impl.*;
import com.pi4j.platform.*;
import com.pi4j.system.impl.*;
import com.pi4j.util.*;
import com.pi4j.wiringpi.*;
import com.pi4j.io.gpio.impl.*;
import com.pi4j.io.wdt.*;
import com.pi4j.temperature.*;
import com.pi4j.io.wdt.impl.*;

import com.pi4j.gpio.*;

OPC opc;
PImage im;

int numStrips = 16;
int numLedsPerStrip = 60;
int IR_INPUT_PIN = 4;

GpioController gpio;
GpioPinDigitalInput irSensor;

boolean shouldDrawLines = false;

// FOR TESTING.
// boolean HIGH;

int kCanvasWidth = 400;
int kCanvasHeight = 600;
int kBorderWidth = 40;
int kFrameWidth = kCanvasWidth + kBorderWidth * 2;
int kFrameHeight = kCanvasHeight + kBorderWidth * 2;

// Four directions of motion:
//       0
//       |
// 3 ---- ---- 1
//       |
//       2
int kMotionDirections = 4;

float kCPBoundingBoxWidth = 100;
float kCPBoundingBoxHeight = 100;
float kEndpointBoundingBoxDefaultWidth = 100;
float kEndpointBoundingBoxDefaultHeight = 100;
// Multiplies x and y distances between endpoints of last curve to determine center of bounding box of new curve random endpoint.
float kEndpointBoundingBoxCenterShiftMultiplier = 0.6;
float kTraveledByMouseThreshold = 20;
float kTraveledByMouseBaseStepSize = 25;
int kNumLinesToDraw = 5;

public class Point {
  public float x;
  public float y;
  
  public Point() {
  }
  
  public Point(float x, float y) {
    this.x = x;
    this.y = y;
  }
}

// Represents a curve by storing its start and end points,
// as well as its two control points.
public class Curve {
  public Point startPoint;
  public Point endPoint;
  public Point cp1;
  public Point cp2;
  public int motionDirection;
}

float endpointBoundingBoxWidth = kEndpointBoundingBoxDefaultWidth;
float endpointBoundingBoxHeight = kEndpointBoundingBoxDefaultHeight;
ArrayList<Curve> curves;

int linesDrawn = 0;

void setup()
{
  size(480, 680);                      // NOTE: MUST MANUALLY CONFIRM: size(kCanvasWidth + kBorderWidth * 2, kCanvasHeight + kBorderWidth * 2)
  
  gpio = GpioFactory.getInstance();
  irSensor = gpio.provisionDigitalInputPin(RaspiPin.GPIO_04, PinPullResistance.PULL_UP);
  
  frameRate(10);

  // Load a sample image
  im = loadImage("blue-flames.jpg");

  // Connect to the local instance of fcserver
  opc = new OPC(this, "127.0.0.1", 7890);

  // Map eight 60-LED strips.
  for (int i = 0; i < numStrips; i++) {
    // Vertical layout.
    opc.ledStrip(i * numLedsPerStrip, numLedsPerStrip, i * width / numStrips + (width / numStrips / 2), height / 2, 5, HALF_PI, false);
  }
  
  curves = new ArrayList<Curve>();
  
  linesDrawn = kNumLinesToDraw;
}

void draw()
{
  // Image background moves half as fast as wavy line.
  if (frameCount % 2 == 0 ) {
    // Scale the image so that it matches the width of the window
    int imHeight = im.height * width / im.width;
  
    // Scroll down slowly, and wrap around
    float speed = 0.03;
    float y = (millis() * -speed) % imHeight;
    
    // Use two copies of the image, so it seems to repeat infinitely  
    image(im, 0, y, width, imHeight);
    image(im, 0, y + imHeight, width, imHeight);
    
    //println("HIGH:", irSensor.isHigh());
    //println("HIGH:", HIGH);
    
    if (irSensor.isHigh() && !shouldDrawLines) {
    // if (HIGH && !shouldDrawLines) {
      linesDrawn = 0;
      shouldDrawLines = true;
    }
   }
  
  // Wavy line code.
  if (linesDrawn < kNumLinesToDraw) {
    addCurve();
    
    for (int i = 0; i < curves.size(); i++) {    
      Curve curve = curves.get(i);
      
      switch (curve.motionDirection) {
        case 0:
          curve.cp1.y -= 1;
          curve.cp2.y -= 1;
        case 1:
          curve.cp1.x += 1;
          curve.cp2.x += 1;
        case 2:
          curve.cp1.y += 1;
          curve.cp2.y += 1;
        default: // 3
          curve.cp1.x -= 1;
          curve.cp2.x -= 1;
      }
      
      // FIXME: Operation -= above not working correctly, as indicated for print of curve with motion direction 0 or 3.
      if (i == 5) {
        println("MOTION DIRECTION:", curve.motionDirection);
        println("CURVE CP1:", curve.cp1.x, curve.cp1.y);
        println("CURVE CP2:", curve.cp2.x, curve.cp2.y);
      }
      
      drawCurve(curve);
    }
    
    // Bounding box of random endpoint is larger if cursor is moving faster.
    // This makes curves larger when cursor speed is faster.
    endpointBoundingBoxWidth = kEndpointBoundingBoxDefaultWidth;
    endpointBoundingBoxHeight = kEndpointBoundingBoxDefaultHeight;
    float traveled = dist(pmouseX, pmouseY, mouseX, mouseY);
    float boundMultiplier = .5 + (traveled / kTraveledByMouseBaseStepSize) / 2;
    endpointBoundingBoxWidth = kEndpointBoundingBoxDefaultWidth * boundMultiplier;
    endpointBoundingBoxHeight = kEndpointBoundingBoxDefaultHeight * boundMultiplier;
      
  
    linesDrawn++;
  } else {
    shouldDrawLines = false;
  }
}


// MARK: - Create Curve

void addCurve() {  
  Curve newCurve = new Curve();
  newCurve.motionDirection = int(random(0, kMotionDirections));
  
  if (curves.isEmpty()) {
    newCurve.startPoint = getRandomPoint(0, 0, kCanvasWidth, kCanvasHeight);
    newCurve.endPoint = getRandomPoint(max(0, newCurve.startPoint.x - endpointBoundingBoxWidth / 2),
                                     max(0, newCurve.startPoint.y - endpointBoundingBoxHeight / 2),
                                     endpointBoundingBoxWidth,
                                     endpointBoundingBoxHeight);
    newCurve.cp1 = getRandomPoint(newCurve.endPoint.x, newCurve.endPoint.y, kCPBoundingBoxWidth, kCPBoundingBoxHeight);
    newCurve.cp2 = getRandomPoint(newCurve.startPoint.x, newCurve.startPoint.y, kCPBoundingBoxWidth, kCPBoundingBoxHeight);
    curves.add(newCurve);    
    return;
  }
  
  Curve lastCurve = curves.get(curves.size() - 1);
  
  newCurve.startPoint = lastCurve.endPoint;
  
  // Center of bounding box for random endpoint is shifted in the direction of the preceding curve,
  // to help direct the line and reduce the abruptness of change in direction.
  newCurve.endPoint = getRandomPoint(min(max(0, newCurve.startPoint.x + kEndpointBoundingBoxCenterShiftMultiplier * (newCurve.startPoint.x - lastCurve.startPoint.x)), kCanvasWidth),
                                     min(max(0, newCurve.startPoint.y + kEndpointBoundingBoxCenterShiftMultiplier * (newCurve.startPoint.y - lastCurve.startPoint.y)), kCanvasHeight),
                                     endpointBoundingBoxWidth,
                                     endpointBoundingBoxHeight);
    
    
  // TODO: Make sure endpoint doesn't cause new curve to overlap existing curves. (As is, this code takes too long to execute.) 
  /*
  do {
    newCurve.endPoint = getRandomPoint(max(0, lastCurve.endPoint.x - endpointBoundingBoxWidth / 2),
                                     max(0, lastCurve.endPoint.y - endpointBoundingBoxHeight / 2), endpointBoundingBoxWidth, endpointBoundingBoxHeight);
  } while (intersectsExistingCurves(newCurve)); // NOTE: This check takes O(N) time, where N is number of curves.
  */
  
  
  // First control point the of new curve is the reflection of the second control point of the old curve,
  // across the line that passes through the endpoint of the old curve perpendicular to the line between the
  // control points in question.
  newCurve.cp1 = new Point(lastCurve.endPoint.x + (lastCurve.endPoint.x - lastCurve.cp2.x),
                           lastCurve.endPoint.y + (lastCurve.endPoint.y - lastCurve.cp2.y));
  
  newCurve.cp2 = getRandomPoint(newCurve.endPoint.x, newCurve.endPoint.y, kCPBoundingBoxWidth, kCPBoundingBoxHeight);
  curves.add(newCurve);  
}

// Ensures that each x is drawn within [kBorderWidth, kCanvasWidth + kBorderWidth * 2)
// and that each y is drawn within [kBorderWidth, kCanvasHeight + kBorderWidth * 2).
void drawCurve(Curve curve) {
  stroke(0);
  curve(curve.cp1.x + kBorderWidth, curve.cp1.y + kBorderWidth,
        curve.startPoint.x + kBorderWidth, curve.startPoint.y + kBorderWidth,
        curve.endPoint.x + kBorderWidth, curve.endPoint.y + kBorderWidth,
        curve.cp2.x + kBorderWidth, curve.cp2.y + kBorderWidth);
  // fill(255, 105, 180); // Pink
  fill(0, 255, 255); 
  ellipse(curve.cp1.x + kBorderWidth, curve.cp1.y + kBorderWidth, 2, 2);
  ellipse(curve.cp2.x + kBorderWidth, curve.cp2.y + kBorderWidth, 2, 2);
}

Point getRandomPoint(float centerX, float centerY, float boundingBoxWidth, float boundingBoxHeight) {
  float xMin = max(0, centerX - boundingBoxWidth / 2);
  float xMax = min(xMin + boundingBoxWidth, kCanvasWidth);
  float x = random(xMin, xMax);
  float yMin = max(0, centerY - boundingBoxHeight / 2);
  float yMax = min(yMin + boundingBoxHeight, kCanvasHeight);
  float y = random(yMin, yMax);
  
  Point point = new Point();
  point.x = x;
  point.y = y;
  return point;
}


// MARK: - Preventing Intersecting Lines

// Checks whether the direct line beteween the start and end points of CURVE will intersect
// the direct line beteween the start and end points of any existing curves.
boolean intersectsExistingCurves(Curve curve) {
  for (int i = 0; i < curves.size(); i++) {
    if (endpointLinesIntersect(curve, curves.get(i))) {
      return false;
    }
  }
  return true;
}

// As demonstrated below, two lines intersect if:
//
//        q1
//   p2  /
//     \/
//     /\
//    /  \
// p1     \
//         q2
//
// - (p1, q1, p2) and (p1, q1, q2) have different orientations AND
// - (p2, q2, p1) and (p2, q2, q1) have different orientations.
//
// Source: http://www.geeksforgeeks.org/orientation-3-ordered-points/
boolean endpointLinesIntersect(Curve curve1, Curve curve2) {
  return (hasClockwiseOrientation(curve1.startPoint, curve1.endPoint, curve2.startPoint)
          != hasClockwiseOrientation(curve1.startPoint, curve1.endPoint, curve2.endPoint))
         && (hasClockwiseOrientation(curve2.startPoint, curve2.endPoint, curve1.startPoint)
             != hasClockwiseOrientation(curve2.startPoint, curve2.endPoint, curve1.endPoint));
}

// Algorithm found at the below link, on slide 10:
// http://www.dcs.gla.ac.uk/~pat/52233/slides/Geometry1x1.pdf
boolean hasClockwiseOrientation(Point p1, Point p2, Point p3) {
  return (p2.y - p1.y) * (p3.x - p2.x) - (p2.x - p1.x) * (p3.y - p2.y) > 0;
}



/* FOR TESTING */

//void keyPressed() {
//  if (key == CODED) {
//    if (keyCode == SHIFT) {
//      HIGH = true;
//    }
//  }
//}

//void keyReleased() {
//  if (key == CODED) {
//    if (keyCode == SHIFT) {
//      HIGH = false;
//    }
//  }
//}