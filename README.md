# ZoneMinderFoscamHDTrigger


I've been benchmarking ZM's software motion detection with the built in Foscam Motion detection in the camera. In general, I've found Foscam's own detection to be much more reliable. This code makes ZM use Foscam HD inbuilt HW motion detection instead of Zoneminder's SW motion detection. Either that, or I haven't spent enough time configuring the many parameters in ZM and testing it against various weather and lighting conditions. Overall, Foscams built in algorithm seems to automatically handle things much better.

This results in lesser false positives, and also significantly reduces system load on the ZM installation. 

As of 0.1, it may have bugs. Please see the Wiki for more details.

 A trigger script that uses Foscam HD camera inbuilt motion detection
to start ZoneMinder recordings. When motion is detected, it records for 20 seconds
(configurable).

Author: ARC
License: GPL
Version: 0.1
Date: Mar 6 2015

*** Please read the Wiki for setup instructions. ***

The code consists of 3 files:
a) arc_zmtrigger.pl --> a modified version of the default zmtrigger.pl (and a .sh file to restart it when it fails)

b) arc_zm_foscamHDmotion.pl --> the code for detecting motion on foscam HD cameras



