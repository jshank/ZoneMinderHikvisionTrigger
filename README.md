# ZoneMinderHikvisionTrigger

## Not currently working

Based on the excelent ZoneMinderFoscamHDTrigger program. I decided to create a similar script for using the built-in Hikvision VMD (video motion detection) to trigger ZoneMinder via the modified ZMTrigger.pl script.


 A trigger script that uses Hikvision camera inbuilt motion detection
to start ZoneMinder recordings. When motion is detected, it records for 20 seconds
(configurable).

Author: Jim Shank (Heavily borrowed from ARC)
License: GPL


*** Please read the Wiki for setup instructions. ***

The code consists of 3 files:
a) jshank_zmtrigger.pl --> a modified version of the default zmtrigger.pl (and a .sh file to restart it when it fails)

b) jshank_zm_Hikvisionmotion.pl --> the code for detecting motion on Hikvision cameras



