# QuickPath

QuickPath is an attempt to convert the program, [PathPlanner](https://github.com/mjansen4857/pathplanner/releases/latest, "PathPlanner"), to mobile devices (specifically android). Specifically, this is a modification of PathPlanner version 2022.1.1.

If you find bugs, feel free to report them. This app can theoretically work on macos, linux, and ios, however I do not have the devices needed to compile to these platforms.
Windows and android should work out of the box.

YouTube demo here: https://youtu.be/1BEDiob-kok

## How are paths transferred to the roboRIO?

Instead of launching a gradle build and redeploying your robot code, this program transfers files to the roboRIO using SSH and SFTP, after discovering the roboRIO on the wifi network, saving tons of time and preventing the need to have to constantly redeploy code every time you want to change a path.
This should work out of the box with your roboRIO, no extra modifications needed.

## What needs to change in my robot code?

Assuming you already have autonomous set up on your robot and are loading paths from your deploy directory on your roboRIO, not much, if anything. 
The app will deploy the paths to /home/lvuser/deploy/paths/QuickPath, and within the QuickPath folder there are pathplanner path files, and the generatedJSON and generatedCSV folders.
For example, if you wanted to use the wpilib json format, you could just do (on java):

[Constants](https://drive.google.com/file/d/1uMoaZjhCH_T2WdlLcOD5mBGUSrxmARfR/view?usp=sharing)

[Robot.java](https://drive.google.com/file/d/1TK1lxKE7O-HJZaAQnnbf73aAUDRuKReL/view?usp=sharing)

**Make sure you name your paths in the mobile application the same name as the file that you load in the deploy directory, i.e. if you name your path "Path1" in the application, it must be loaded in the roboRIO program as "paths/QuickPath/generatedJSON/Path1.wpilib.json"**


