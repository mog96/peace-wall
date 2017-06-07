/* UNCOMMENT FOR PRODUCTION */
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
PImage[] images;
int imageIndex = 0;

int numStrips = 16;
int numLedsPerStrip = 60;

/* UNCOMMENT FOR PRODUCTION */
GpioController gpio;
GpioPinDigitalInput irSensor;

boolean isHigh = true;
int lastTrigger = 0;
int imTwiceStart = 0;

void setup()
{
  size(400, 800);
  
  /* UNCOMMENT FOR PRODUCTION */
  gpio = GpioFactory.getInstance();
  irSensor = gpio.provisionDigitalInputPin(RaspiPin.GPIO_04, PinPullResistance.PULL_UP);

  // Load a sample image
  images = new PImage[numImages];
  images[0] = loadImage("blue-flames.jpg");
  images[1] = loadImage("light-blue-flames.jpg");
  images[2] = loadImage("flames.jpeg");

  // Connect to the local instance of fcserver
  opc = new OPC(this, "127.0.0.1", 7890);

  // Map eight 60-LED strips.
  for (int i = 0; i < numStrips; i++) {
    // Vertical layout.
    opc.ledStrip(i * 60, 60, i * width / numStrips + (width / numStrips / 2), height / 2, height / 70, HALF_PI, false);
    
    // Horizontal layout.
    // opc.ledStrip(i * 60, 60, width / 2, i * height / numStrips + (height / numStrips / 2), width / 70.0, 0, false);
  }
}

void draw()
{
  boolean wasHigh = isHigh;
  isHigh = irSensor.isHigh();
  
  if (isHigh != wasHigh) {
    if (!isHigh && wasHigh && millis() - lastTrigger < 2000) {
      imageIndex = 2;
    }
    lastTrigger = millis();
  }
  if (millis() - imTwiceStart > 4000)
    imageIndex = irSensor.isHigh() ? 0 : 1;
  }
  
  // Scale the image so that it matches the width of the window
  int imHeight = images[imageIndex].height * width / images[imageIndex].width;

  // Scroll down slowly, and wrap around
  float speed = 0.03;
  float y = (millis() * -speed) % imHeight;
  
  // Use two copies of the image, so it seems to repeat infinitely  
  image(images[imageIndex], 0, y, width, imHeight);
  image(images[imageIndex], 0, y + imHeight, width, imHeight);
}