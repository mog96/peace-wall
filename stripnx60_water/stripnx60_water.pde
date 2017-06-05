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

int numStrips = 24;
int numLedsPerStrip = 60;
int IR_INPUT_PIN = 4;

GpioController gpio;
GpioPinDigitalInput irSensor;

void setup()
{
  size(400, 800);
  
  gpio = GpioFactory.getInstance();
  irSensor = gpio.provisionDigitalInputPin(RaspiPin.GPIO_04, PinPullResistance.PULL_UP);
  
  frameRate(0.5);

  // Load a sample image
  im = loadImage("light-blue-flames.jpg");

  // Connect to the local instance of fcserver
  opc = new OPC(this, "127.0.0.1", 7890);

  // Map eight 60-LED strips.
  for (int i = 0; i < numStrips; i++) {
    // Vertical layout.
    opc.ledStrip(i * numLedsPerStrip, numLedsPerStrip, i * width / numStrips + (width / numStrips / 2), height / 2, height / 70, HALF_PI, false);
  }
}

void draw()
{
  /*
  // Scale the image so that it matches the width of the window
  int imHeight = im.height * width / im.width;

  // Scroll down slowly, and wrap around
  float speed = 0.03;
  float y = (millis() * -speed) % imHeight;
  
  // Use two copies of the image, so it seems to repeat infinitely  
  image(im, 0, y, width, imHeight);
  image(im, 0, y + imHeight, width, imHeight);
  */
  
  //println("HIGH:", irSensor.isHigh());
  
  if (irSensor.isHigh()) {
    background(255, 0, 0);
  } else {
    background(0, 0, 255);
  }
}