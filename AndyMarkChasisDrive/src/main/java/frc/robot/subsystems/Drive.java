// Copyright (c) FIRST and other WPILib contributors.
// Open Source Software; you can modify and/or share it under the terms of
// the WPILib BSD license file in the root directory of this project.

package frc.robot.subsystems;

import java.io.*;
import java.lang.reflect.Method;
import java.lang.Thread;

import edu.wpi.first.wpilibj2.command.SubsystemBase;
import edu.wpi.first.wpilibj.GenericHID;
import edu.wpi.first.wpilibj2.command.button.JoystickButton;
import edu.wpi.first.wpilibj2.command.button.Trigger;
import frc.robot.Constants;

public class Drive extends SubsystemBase {

  edu.wpi.first.wpilibj.XboxController controller;

  Constants constants = new Constants();

  private void ButtonDetection() {

    try {

      java.lang.Thread.sleep(30);

    } catch (InterruptedException e) {

      e.printStackTrace();

    }

    MoveForward(controller.getRightTriggerAxis());
    MoveBackward(controller.getLeftTriggerAxis());
    TurnLeft(controller.getLeftX());
    TurnRight(controller.getLeftX());
      
    ButtonDetection();

  }

  public void Run() {

    controller = new edu.wpi.first.wpilibj.XboxController(0);

    ButtonDetection();

  }

  private void MoveForward(double axis) {
    if (axis > 0) {
      System.out.println("Right trigger's axis = " + axis);
    }

  }

  private void MoveBackward(double axis) {
    if (axis > 0){
      System.out.println("Left trigger's axis = " + axis);
    }
    
  }

  private void TurnLeft(double axis) {
    if (axis < -0.1){
      System.out.println("Left Joystick X axis = " + axis);
    }
    
  }

  private void TurnRight(double axis) {
    if (axis > 0.1){
      System.out.println("Left Joystick X axis = " + axis);
    }
    
  }

}
