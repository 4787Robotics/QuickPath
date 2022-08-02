import 'dart:io';

import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'pages/home_page.dart';

void main() {
  runApp(PathPlanner());

  if (Platform.isWindows || Platform.isLinux) {
    doWhenWindowReady(() {
      appWindow.minSize = Size(900, 600);
      appWindow.size = Size(1280, 720);
      appWindow.alignment = Alignment.center;
      appWindow.show();
    });
  }
}

class PathPlanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PathPlanner',
      theme: ThemeData(
        //brightness: Brightness.dark,
        //primarySwatch: Colors.indigo,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.cyan.shade300,
          secondary: Colors.white,
          brightness: Brightness.dark,
        ),
      ),
      home: HomePage(),
    );
  }
}
