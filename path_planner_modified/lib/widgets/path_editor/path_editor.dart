import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:quickpath/robot_path/robot_path.dart';
import 'package:quickpath/robot_path/waypoint.dart';
import 'package:quickpath/services/undo_redo.dart';
import 'package:quickpath/widgets/keyboard_shortcuts/keyboard_shortcuts.dart';
import 'package:quickpath/widgets/path_editor/generator_settings_card.dart';
import 'package:quickpath/widgets/path_editor/path_info_card.dart';
import 'package:quickpath/widgets/path_editor/stateful_drag_area.dart';
import 'package:quickpath/widgets/path_editor/waypoint_card.dart';
import 'package:undo/undo.dart';

import 'path_painter.dart';

enum EditorMode {
  Edit,
  Preview,
}

class PathEditor extends StatefulWidget {
  final RobotPath path;
  final double robotWidth;
  final double robotLength;
  final bool holonomicMode;
  final bool generateJSON;
  final bool generateCSV;
  final String pathsDir;
  bool pathChanged = true;

  Size defaultImageSize = Size(3240, 1620);
  double pixelsPerMeter = 196.85;

  PathEditor(this.path, this.robotWidth, this.robotLength, this.holonomicMode,
      this.generateJSON, this.generateCSV, this.pathsDir);

  @override
  _PathEditorState createState() => _PathEditorState();
}

class _PathEditorState extends State<PathEditor>
    with SingleTickerProviderStateMixin {
  Waypoint? _draggedPoint;
  Waypoint? _selectedPoint;
  int _selectedPointIndex = -1;
  Waypoint? _dragOldValue;
  EditorMode _mode = EditorMode.Edit;
  AnimationController? _previewController;
  bool _showWaypointCard = false;
  bool _showGeneratorSettings = false;

  @override
  void initState() {
    super.initState();
    _previewController = AnimationController(vsync: this);
  }

  @override
  void dispose() {
    _previewController!.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.pathChanged) {
      widget.path.generateTrajectory().whenComplete(() {
        _previewController!.duration = Duration(
            milliseconds:
                (widget.path.generatedTrajectory!.getRuntime() * 1000).toInt());
        setState(() {
          _previewController!.reset();
          _previewController!.repeat();
        });
      });
      widget.pathChanged = false;
    }

    return KeyBoardShortcuts(
      keysToPress: {
        (Platform.isMacOS)
            ? LogicalKeyboardKey.meta
            : LogicalKeyboardKey.control,
        LogicalKeyboardKey.keyZ
      },
      onKeysPressed: () {
        setState(() {
          _selectedPoint = null;
        });
        UndoRedo.undo();
      },
      child: KeyBoardShortcuts(
        keysToPress: {
          (Platform.isMacOS)
              ? LogicalKeyboardKey.meta
              : LogicalKeyboardKey.control,
          LogicalKeyboardKey.keyY
        },
        onKeysPressed: () {
          setState(() {
            _selectedPoint = null;
          });
          UndoRedo.redo();
        },
        child: Stack(
          children: [
            _buildEditorMode(),
            _buildWaypointCard(),
            _buildGeneratorSettingsCard(),
            _buildPathInfo(),
            _buildToolbar(),
          ],
        ),
      ),
    );
  }

  Widget _buildEditorMode() {
    switch (_mode) {
      case EditorMode.Edit:
        return _buildPathEditor();
      case EditorMode.Preview:
        return _buildPreviewEditor();
    }
  }

  Widget _buildToolbar() {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12.0),
          child: Container(
            height: 40,
            color: Colors.grey[900],
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Tooltip(
                  message: 'Edit',
                  waitDuration: Duration(milliseconds: 500),
                  child: MaterialButton(
                    height: 50,
                    minWidth: 50,
                    child: Icon(Icons.edit),
                    onPressed: _mode == EditorMode.Edit
                        ? null
                        : () {
                            setState(() {
                              _mode = EditorMode.Edit;
                              _previewController!.stop();
                              _previewController!.reset();
                            });
                          },
                  ),
                ),
                VerticalDivider(
                  width: 1,
                ),
                Tooltip(
                  message: 'Preview',
                  waitDuration: Duration(milliseconds: 500),
                  child: MaterialButton(
                    height: 50,
                    minWidth: 50,
                    child: Icon(Icons.play_arrow),
                    onPressed: _mode == EditorMode.Preview
                        ? null
                        : () async {
                            if (widget.path.generatedTrajectory == null) {
                              await widget.path.generateTrajectory();
                            }
                            _previewController!.duration = Duration(
                                milliseconds: (widget.path.generatedTrajectory!
                                            .getRuntime() *
                                        1000)
                                    .toInt());
                            setState(() {
                              _selectedPoint = null;
                              _mode = EditorMode.Preview;
                              _previewController!.repeat();
                            });
                          },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPreviewEditor() {
    return Center(
      child: InteractiveViewer(
        child: Container(
          child: _buildEditorStack(),
        ),
      ),
    );
  }

  Widget _buildEditorStack() {
    return Padding(
      padding: const EdgeInsets.all(48.0),
      child: Stack(
        children: [
          AspectRatio(
            aspectRatio: 2 / 1,
            child: SizedBox.expand(
              child: Image.asset(
                'images/field22.png',
                fit: BoxFit.contain,
              ),
            ),
          ),
          Positioned.fill(
            child: Container(
              child: CustomPaint(
                painter: PathPainter(
                  widget.path,
                  Size(widget.robotWidth, widget.robotLength),
                  widget.holonomicMode,
                  _selectedPoint,
                  _mode,
                  _previewController!.view,
                  widget.defaultImageSize,
                  widget.pixelsPerMeter,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPathEditor() {
    return Center(
      child: InteractiveViewer(
        child: GestureDetector(
          onDoubleTapDown: (details) {
            UndoRedo.addChange(Change(
              [
                RobotPath.cloneWaypointList(widget.path.waypoints),
                _selectedPointIndex == -1 ||
                        _selectedPointIndex >= widget.path.waypoints.length
                    ? widget.path.waypoints.length - 1
                    : _selectedPointIndex
              ],
              () {
                setState(() {
                  widget.path.addWaypoint(
                      Point(_xPixelsToMeters(details.localPosition.dx),
                          _yPixelsToMeters(details.localPosition.dy)),
                      _selectedPointIndex == -1 ||
                              _selectedPointIndex >=
                                  widget.path.waypoints.length
                          ? widget.path.waypoints.length - 1
                          : _selectedPointIndex);
                  widget.path.savePath(
                      widget.pathsDir, widget.generateJSON, widget.generateCSV);
                });
              },
              (oldValue) {
                setState(() {
                  if (oldValue[1] == oldValue[0].length - 1) {
                    widget.path.waypoints.removeLast();
                    widget.path.waypoints.last.nextControl = null;
                  } else {
                    final Waypoint removed =
                        widget.path.waypoints.removeAt(oldValue[1] + 1);
                    widget.path.waypoints[oldValue[1]].nextControl =
                        oldValue[0][oldValue[1]].nextControl;
                    widget.path.waypoints[oldValue[1] + 1].prevControl =
                        oldValue[0][oldValue[1] + 1].prevControl;
                  }
                  _selectedPointIndex = -1;
                  widget.path.savePath(
                      widget.pathsDir, widget.generateJSON, widget.generateCSV);
                });
              },
            ));
            setState(() {
              for (var i = 0; i < widget.path.waypoints.length; i++) {
                Waypoint w = widget.path.waypoints[i];
                if (w.isPointInAnchor(
                        _xPixelsToMeters(details.localPosition.dx),
                        _yPixelsToMeters(details.localPosition.dy),
                        0.125) ||
                    w.isPointInNextControl(
                        _xPixelsToMeters(details.localPosition.dx),
                        _yPixelsToMeters(details.localPosition.dy),
                        0.1) ||
                    w.isPointInPrevControl(
                        _xPixelsToMeters(details.localPosition.dx),
                        _yPixelsToMeters(details.localPosition.dy),
                        0.1) ||
                    w.isPointInHolonomicThing(
                        _xPixelsToMeters(details.localPosition.dx),
                        _yPixelsToMeters(details.localPosition.dy),
                        0.075,
                        widget.robotLength)) {
                  setState(() {
                    _selectedPoint = w;
                    _selectedPointIndex = i;
                  });
                }
              }
            });
          },
          onDoubleTap: () {},
          onTapDown: (details) {
            FocusScopeNode currentScope = FocusScope.of(context);
            if (!currentScope.hasPrimaryFocus && currentScope.hasFocus) {
              FocusManager.instance.primaryFocus!.unfocus();
            }
            for (var i = 0; i < widget.path.waypoints.length; i++) {
              Waypoint w = widget.path.waypoints[i];
              if (w.isPointInAnchor(_xPixelsToMeters(details.localPosition.dx),
                      _yPixelsToMeters(details.localPosition.dy), 0.125) ||
                  w.isPointInNextControl(
                      _xPixelsToMeters(details.localPosition.dx),
                      _yPixelsToMeters(details.localPosition.dy),
                      0.1) ||
                  w.isPointInPrevControl(
                      _xPixelsToMeters(details.localPosition.dx),
                      _yPixelsToMeters(details.localPosition.dy),
                      0.1) ||
                  w.isPointInHolonomicThing(
                      _xPixelsToMeters(details.localPosition.dx),
                      _yPixelsToMeters(details.localPosition.dy),
                      0.075,
                      widget.robotLength)) {
                setState(() {
                  _selectedPoint = w;
                  _selectedPointIndex = i;
                });
                return;
              }
            }
            setState(() {
              _selectedPoint = null;
              _selectedPointIndex = -1;
            });
          },
          onPanDown: (details) {
            for (Waypoint w in widget.path.waypoints.reversed) {
              if (w.startDragging(
                  _xPixelsToMeters(details.localPosition.dx),
                  _yPixelsToMeters(details.localPosition.dy),
                  0.525,
                  //touch area of waypoint
                  0.5,
                  0.275,
                  widget.robotLength,
                  widget.holonomicMode)) {
                _draggedPoint = w;
                _dragOldValue = w.clone();
                break;
              }
            }
          },
          onPanUpdate: (details) {
            if (_draggedPoint != null) {
              setState(() {
                _draggedPoint!.dragUpdate(
                    _xPixelsToMeters(details.localPosition.dx),
                    _yPixelsToMeters(details.localPosition.dy));
              });
            }
          },
          onPanEnd: (details) {
            if (_draggedPoint != null) {
              _draggedPoint!.stopDragging();
              int index = widget.path.waypoints.indexOf(_draggedPoint!);
              Waypoint dragEnd = _draggedPoint!.clone();
              UndoRedo.addChange(Change(
                _dragOldValue,
                () {
                  setState(() {
                    if (widget.path.waypoints[index] != _draggedPoint) {
                      widget.path.waypoints[index] = dragEnd.clone();
                    }
                    widget.path.savePath(widget.pathsDir, widget.generateJSON,
                        widget.generateCSV);
                  });
                },
                (oldValue) {
                  setState(() {
                    widget.path.waypoints[index] = oldValue.clone();
                    widget.path.savePath(widget.pathsDir, widget.generateJSON,
                        widget.generateCSV);
                  });
                },
              ));
              _draggedPoint = null;
            }
          },
          child: Container(
            child: _buildEditorStack(),
          ),
        ),
      ),
    );
  }

  Widget _buildWaypointCard() {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return Align(
        alignment: FractionalOffset.topRight,
        child: WaypointCard(
          _selectedPoint,
          label: widget.path.getWaypointLabel(_selectedPoint),
          holonomicEnabled: widget.holonomicMode,
          deleteEnabled: widget.path.waypoints.length > 2,
          onShouldSave: () {
            widget.path.savePath(
                widget.pathsDir, widget.generateJSON, widget.generateCSV);
          },
          onDelete: () {
            int delIndex = widget.path.waypoints.indexOf(_selectedPoint!);
            UndoRedo.addChange(Change(
              RobotPath.cloneWaypointList(widget.path.waypoints),
              () {
                setState(() {
                  Waypoint w = widget.path.waypoints.removeAt(delIndex);
                  if (w.isEndPoint()) {
                    widget.path.waypoints[widget.path.waypoints.length - 1]
                        .nextControl = null;
                    widget.path.waypoints[widget.path.waypoints.length - 1]
                        .isReversal = false;
                  } else if (w.isStartPoint()) {
                    widget.path.waypoints[0].prevControl = null;
                    widget.path.waypoints[0].isReversal = false;
                  }
                  widget.path.savePath(
                      widget.pathsDir, widget.generateJSON, widget.generateCSV);
                });
              },
              (oldValue) {
                setState(() {
                  widget.path.waypoints = RobotPath.cloneWaypointList(oldValue);
                  widget.path.savePath(
                      widget.pathsDir, widget.generateJSON, widget.generateCSV);
                });
              },
            ));
            setState(() {
              _selectedPoint = null;
            });
          },
        ),
      );
    } else if (!_showWaypointCard && _selectedPoint != null) {
      return Align(
        alignment: FractionalOffset.topRight,
        child: Column(
          children: [
            SizedBox(
              height: 20,
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _showWaypointCard = true;
                });
              },
              child: Icon(
                // <-- Icon
                Icons.menu,
                size: 24.0,
              ),
            ),
          ],
        ),
      );
    } else if (_showWaypointCard && _selectedPoint != null) {
      return Stack(
        children: [
          Align(
            alignment: FractionalOffset.topRight,
            child: Column(
              children: [
                SizedBox(
                  height: 20,
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _showWaypointCard = false;
                    });
                  },
                  child: Icon(
                    // <-- Icon
                    Icons.close,
                    size: 24.0,
                  ),
                ),
              ],
            ),
          ),
          StatefulDragArea(
            child: WaypointCard(
              _selectedPoint,
              label: widget.path.getWaypointLabel(_selectedPoint),
              holonomicEnabled: widget.holonomicMode,
              deleteEnabled: widget.path.waypoints.length > 2,
              onShouldSave: () {
                widget.path.savePath(
                    widget.pathsDir, widget.generateJSON, widget.generateCSV);
              },
              onDelete: () {
                int delIndex = widget.path.waypoints.indexOf(_selectedPoint!);
                UndoRedo.addChange(Change(
                  RobotPath.cloneWaypointList(widget.path.waypoints),
                  () {
                    setState(() {
                      Waypoint w = widget.path.waypoints.removeAt(delIndex);
                      if (w.isEndPoint()) {
                        widget.path.waypoints[widget.path.waypoints.length - 1]
                            .nextControl = null;
                        widget.path.waypoints[widget.path.waypoints.length - 1]
                            .isReversal = false;
                      } else if (w.isStartPoint()) {
                        widget.path.waypoints[0].prevControl = null;
                        widget.path.waypoints[0].isReversal = false;
                      }
                      widget.path.savePath(widget.pathsDir, widget.generateJSON,
                          widget.generateCSV);
                    });
                  },
                  (oldValue) {
                    setState(() {
                      widget.path.waypoints =
                          RobotPath.cloneWaypointList(oldValue);
                      widget.path.savePath(widget.pathsDir, widget.generateJSON,
                          widget.generateCSV);
                    });
                  },
                ));
                setState(() {
                  _selectedPoint = null;
                });
              },
            ),
          ),
        ],
      );
    } else {
      return SizedBox.shrink();
    }
  }

  Widget _buildPathInfo() {
    return Visibility(
      visible: _mode == EditorMode.Preview,
      child: Align(
        alignment: FractionalOffset.topRight,
        child: PathInfoCard(widget.path),
      ),
    );
  }

  Widget _buildGeneratorSettingsCard() {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return Visibility(
        visible: widget.generateJSON ||
            widget.generateCSV ||
            _mode == EditorMode.Preview,
        child: StatefulDragArea(
          child: GeneratorSettingsCard(
            widget.path,
            onShouldSave: () async {
              if (_mode == EditorMode.Preview) {
                await widget.path.generateTrajectory();
                setState(() {
                  _previewController!.stop();
                  _previewController!.reset();
                  _previewController!.duration = Duration(
                      milliseconds:
                          (widget.path.generatedTrajectory!.getRuntime() * 1000)
                              .toInt());
                  _previewController!.repeat();
                });
              }
              widget.path.savePath(
                  widget.pathsDir, widget.generateJSON, widget.generateCSV);
            },
          ),
        ),
      );
    } else if (_showGeneratorSettings) {
      return Stack(
        children: [
          Align(
            alignment: FractionalOffset.bottomLeft,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: ElevatedButton(
                onPressed: () {
                  setState(() {
                    _showGeneratorSettings = false;
                  });
                },
                child: Icon(
                  // <-- Icon
                  Icons.close,
                  size: 24.0,
                ),
              ),
            ),
          ),
          Visibility(
            visible: widget.generateJSON ||
                widget.generateCSV ||
                _mode == EditorMode.Preview,
            child: StatefulDragArea(
              child: GeneratorSettingsCard(
                widget.path,
                onShouldSave: () async {
                  if (_mode == EditorMode.Preview) {
                    await widget.path.generateTrajectory();
                    setState(() {
                      _previewController!.stop();
                      _previewController!.reset();
                      _previewController!.duration = Duration(
                          milliseconds:
                              (widget.path.generatedTrajectory!.getRuntime() *
                                      1000)
                                  .toInt());
                      _previewController!.repeat();
                    });
                  }
                  widget.path.savePath(
                      widget.pathsDir, widget.generateJSON, widget.generateCSV);
                },
              ),
            ),
          ),
        ],
      );
    } else {
      return Align(
        alignment: FractionalOffset.bottomLeft,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: ElevatedButton(
            onPressed: () {
              setState(() {
                _showGeneratorSettings = true;
              });
            },
            child: Icon(
              // <-- Icon
              Icons.speed,
              size: 24.0,
            ),
          ),
        ),
      );
    }
  }

  double _xPixelsToMeters(double pixels) {
    return ((pixels - 48) / PathPainter.scale) / widget.pixelsPerMeter;
  }

  double _yPixelsToMeters(double pixels) {
    return (widget.defaultImageSize.height -
            ((pixels - 48) / PathPainter.scale)) /
        widget.pixelsPerMeter;
  }
}
