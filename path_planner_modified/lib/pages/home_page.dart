import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui';

import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:macos_secure_bookmarks/macos_secure_bookmarks.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:quickpath/robot_path/robot_path.dart';
import 'package:quickpath/robot_path/waypoint.dart';
import 'package:quickpath/services/github.dart';
import 'package:quickpath/services/undo_redo.dart';
import 'package:quickpath/widgets/deploy_button.dart';
import 'package:quickpath/widgets/drawer_tiles/path_tile.dart';
import 'package:quickpath/widgets/drawer_tiles/settings_tile.dart';
import 'package:quickpath/widgets/keyboard_shortcuts/keyboard_shortcuts.dart';
import 'package:quickpath/widgets/path_editor/path_editor.dart';
import 'package:quickpath/widgets/window_button/window_button.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class HomePage extends StatefulWidget {
  HomePage() : super();

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  double _toolbarHeight = 56;
  String _version = '2022.8.1';
  Directory? _currentProject;
  String? _currentProjectName;
  String? _appDocPath;
  bool _welcomeWindow = true;
  bool _createNewProject = false;
  Directory? _pathsDir;
  late SharedPreferences _prefs;
  List<RobotPath> _paths = [];
  RobotPath? _currentPath;
  double _teamNumber = 0;
  double _robotWidth = 0.75;
  double _robotLength = 1.0;
  bool _holonomicMode = false;
  bool _generateJSON = false;
  bool _generateCSV = false;
  bool _appDrawerSettings = false;
  bool _updateAvailable = false;
  late AnimationController _updateController;
  late AnimationController _welcomeController;
  late Animation<Offset> _offsetAnimation;
  late Animation<double> _scaleAnimation;
  String _releaseURL =
      'https://github.com/mjansen4857/pathplanner/releases/latest';
  SecureBookmarks? _bookmarks = Platform.isMacOS ? SecureBookmarks() : null;
  bool _appStoreBuild = false;

  @override
  void initState() {
    super.initState();
    _updateController =
        AnimationController(vsync: this, duration: Duration(milliseconds: 400));
    _welcomeController =
        AnimationController(vsync: this, duration: Duration(milliseconds: 400));
    _offsetAnimation = Tween<Offset>(begin: Offset(0, -0.05), end: Offset.zero)
        .animate(CurvedAnimation(
      parent: _updateController,
      curve: Curves.ease,
    ));
    _scaleAnimation =
        CurvedAnimation(parent: _welcomeController, curve: Curves.ease);
    SharedPreferences.getInstance().then((prefs) async {
      String? projectDir = prefs.getString('currentProjectDir');
      String? pathsDir = prefs.getString('currentPathsDir');
      if (projectDir != null && Platform.isMacOS) {
        if (prefs.getString('macOSBookmark') != null) {
          await _bookmarks!.resolveBookmark(prefs.getString('macOSBookmark')!);

          await _bookmarks!
              .startAccessingSecurityScopedResource(File(projectDir));
        } else {
          projectDir = null;
        }
      }

      getCurrentWorkingDirectory().then((String result) {
        setState(() {
          _appDocPath = result;
        });
      });

      setState(() {
        _prefs = prefs;
        _welcomeController.forward();
        _welcomeWindow = true;
        _currentProject = null;
        _currentProjectName = null;
        //_loadPaths(projectDir, pathsDir);
        _teamNumber = _prefs.getDouble("teamNumber") ?? 0;
        _robotWidth = _prefs.getDouble('robotWidth') ?? 0.75;
        _robotLength = _prefs.getDouble('robotLength') ?? 1.0;
        _holonomicMode = _prefs.getBool('holonomicMode') ?? false;
        _generateJSON = _prefs.getBool('generateJSON') ?? false;
        _generateCSV = _prefs.getBool('generateCSV') ?? false;
      });
    });

    if (!_appStoreBuild) {
      GitHubAPI.isUpdateAvailable(_version).then((value) {
        setState(() {
          _updateAvailable = value;
          _updateController.forward();
        });
      });
    }

    // PackageInfo plugin is broken on windows. Have to wait for an update

    // PackageInfo.fromPlatform().then((packageInfo) {
    //   setState(() {
    //     _version = packageInfo.version;
    //     if (!_appStoreBuild) {
    //       GitHubAPI.isUpdateAvailable(_version).then((value) {
    //         setState(() {
    //           _updateAvailable = value;
    //           _updateController.forward();
    //         });
    //       });
    //     }
    //   });
    // });
  }

  @override
  void dispose() {
    super.dispose();
    _updateController.dispose();
    _welcomeController.dispose();
    if (Platform.isMacOS && _currentProject != null) {
      _bookmarks!
          .stopAccessingSecurityScopedResource(File(_currentProject!.path));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: _buildAppBar() as PreferredSizeWidget?,
        drawer: _currentProject == null
            ? null
            : _appDrawerSettings
                ? _buildSettingsDrawer()
                : _buildDrawer(context),
        body: Stack(
          children: [
            _buildBody(context),
            _buildUpdateNotification(),
          ],
        ),
        floatingActionButton: Visibility(
          visible:
              _currentProject != null && (!_appStoreBuild && !Platform.isMacOS),
          child: DeployFAB(
            teamNumber: _teamNumber,
            path_name: _pathsDir?.path ?? "",
            generateCSV: _generateCSV,
            generateJSON: _generateJSON,
          ),
        ));
  }

  Widget _buildAppBar() {
    if (Platform.isAndroid || Platform.isIOS) {
      //show nothing
      return PreferredSize(
          child: SizedBox.shrink(), preferredSize: Size.fromHeight(0));
    }
    return AppBar(
      backgroundColor: Colors.grey[900],
      toolbarHeight: _toolbarHeight,
      actions: [
        MinimizeWindowBtn(),
        MaximizeWindowBtn(),
        CloseWindowBtn(),
      ],
      title: SizedBox(
        height: _toolbarHeight,
        child: Row(
          children: [
            Expanded(
              child: MoveWindow(
                child: Container(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _currentPath == null
                        ? 'QuickPath'
                        : '${_currentPath!.name}',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsDrawer() {
    return Drawer(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox.fromSize(
              size: Size(0, 20),
            ),
            Align(
              alignment: Alignment.topRight,
              child: ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _appDrawerSettings = false;
                    });
                  },
                  child: Icon(Icons.exit_to_app)),
            ),
            SettingsTile(
              onSettingsChanged: () {
                setState(() {
                  _teamNumber = _prefs.getDouble('teamNumber') ?? 0;
                  _robotWidth = _prefs.getDouble('robotWidth') ?? 0.75;
                  _robotLength = _prefs.getDouble('robotLength') ?? 1.0;
                  _holonomicMode = _prefs.getBool('holonomicMode') ?? false;
                  _generateJSON = _prefs.getBool('generateJSON') ?? false;
                  _generateCSV = _prefs.getBool('generateCSV') ?? false;
                });
              },
              onGenerationEnabled: () {
                for (RobotPath path in _paths) {
                  path.savePath(_pathsDir!.path, _generateJSON, _generateCSV);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            padding: EdgeInsets.fromLTRB(0, 0, 0, 8.0),
            child: Stack(
              children: [
                Align(
                  alignment: FractionalOffset.topRight,
                  child: RawMaterialButton(
                    onPressed: () {
                      setState(() {
                        _appDrawerSettings = true;
                      });
                    },
                    child: Icon(Icons.settings),
                    shape: CircleBorder(),
                  ),
                ),
                SizedBox.fromSize(
                  size: Size(100, 40),
                ),
                Container(
                  child: Align(
                    alignment: FractionalOffset.bottomRight,
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(0, 0, 16, 0),
                      child: Text('v' + _version),
                    ),
                  ),
                ),
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Container(),
                        flex: 2,
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          (_currentProject != null)
                              ? basename(_currentProject!.path)
                              : 'No Project',
                          style: TextStyle(
                              fontSize: 20,
                              color: (_currentProject != null)
                                  ? Colors.white
                                  : Colors.red),
                        ),
                      ),
                      ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _currentProjectName = null;
                              _currentProject = null;
                              _welcomeWindow = false;
                            });
                          },
                          child: Text('Switch Project')),
                      Expanded(
                        child: Container(),
                        flex: 4,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ReorderableListView(
              padding: EdgeInsets.zero,
              onReorder: (int oldIndex, int newIndex) {
                setState(() {
                  if (oldIndex < newIndex) {
                    newIndex -= 1;
                  }
                  final RobotPath path = _paths.removeAt(oldIndex);
                  _paths.insert(newIndex, path);

                  List<String> pathOrder = [];
                  for (RobotPath path in _paths) {
                    pathOrder.add(path.name);
                  }
                  _prefs.setStringList('pathOrder', pathOrder);
                });
              },
              children: [
                for (int i = 0; i < _paths.length; i++)
                  PathTile(
                    _paths[i],
                    key: Key('$i'),
                    isSelected: _paths[i] == _currentPath,
                    onRename: (name) {
                      File pathFile =
                          File(_pathsDir!.path + _paths[i].name + '.path');
                      File newPathFile = File(_pathsDir!.path + name + '.path');
                      if (newPathFile.existsSync() &&
                          newPathFile.path != pathFile.path) {
                        Navigator.of(context).pop();
                        showDialog(
                            context: context,
                            builder: (BuildContext context) {
                              return KeyBoardShortcuts(
                                keysToPress: {LogicalKeyboardKey.enter},
                                onKeysPressed: Navigator.of(context).pop,
                                child: AlertDialog(
                                  title: Text('Unable to Rename'),
                                  content: Text(
                                      'The file "${basename(newPathFile.path)}" already exists'),
                                  actions: [
                                    TextButton(
                                      onPressed: Navigator.of(context).pop,
                                      child: Text(
                                        'OK',
                                        style: TextStyle(
                                            color: Colors.indigoAccent),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            });
                        return false;
                      } else {
                        pathFile.rename(_pathsDir!.path + name + '.path');
                        setState(() {
                          //flutter weird
                          _currentPath!.name = _currentPath!.name;
                        });
                        return true;
                      }
                    },
                    onTap: () {
                      setState(() {
                        _currentPath = _paths[i];
                        UndoRedo.clearHistory();
                      });
                    },
                    onDelete: () {
                      UndoRedo.clearHistory();

                      File pathFile =
                          File(_pathsDir!.path + _paths[i].name + '.path');

                      if (pathFile.existsSync()) {
                        // The fitted text field container does not rebuild
                        // itself correctly so this is a way to hide it and
                        // avoid confusion
                        Navigator.of(context).pop();

                        showDialog(
                            context: context,
                            builder: (BuildContext context) {
                              void confirm() {
                                Navigator.of(context).pop();
                                pathFile.delete();
                                setState(() {
                                  if (_currentPath == _paths.removeAt(i)) {
                                    _currentPath = _paths.first;
                                  }
                                });
                              }

                              return KeyBoardShortcuts(
                                keysToPress: {LogicalKeyboardKey.enter},
                                onKeysPressed: confirm,
                                child: AlertDialog(
                                  title: Text('Delete Path'),
                                  content: Text(
                                      'Are you sure you want to delete "${_paths[i].name}"? This cannot be undone.'),
                                  actions: [
                                    TextButton(
                                      onPressed: () {
                                        Navigator.of(context).pop();
                                      },
                                      child: Text(
                                        'Cancel',
                                        style: TextStyle(
                                            color: Colors.indigoAccent),
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: confirm,
                                      child: Text(
                                        'Confirm',
                                        style: TextStyle(
                                            color: Colors.indigoAccent),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            });
                      } else {
                        setState(() {
                          if (_currentPath == _paths.removeAt(i)) {
                            _currentPath = _paths.first;
                          }
                        });
                      }
                    },
                    onDuplicate: () {
                      UndoRedo.clearHistory();
                      setState(() {
                        List<String> pathNames = [];
                        for (RobotPath path in _paths) {
                          pathNames.add(path.name);
                        }
                        String pathName = _paths[i].name + ' Copy';
                        while (pathNames.contains(pathName)) {
                          pathName = pathName + ' Copy';
                        }
                        _paths.add(RobotPath(
                          RobotPath.cloneWaypointList(_paths[i].waypoints),
                          name: pathName,
                        ));
                        _currentPath = _paths.last;
                        _currentPath!.savePath(
                            _pathsDir!.path, _generateJSON, _generateCSV);
                      });
                    },
                  ),
              ],
            ),
          ),
          Container(
            child: Align(
              alignment: FractionalOffset.bottomCenter,
              child: Container(
                child: Column(
                  children: [
                    Divider(),
                    ListTile(
                      leading: Icon(Icons.add),
                      title: Text('Add Path'),
                      onTap: () {
                        List<String> pathNames = [];
                        for (RobotPath path in _paths) {
                          pathNames.add(path.name);
                        }
                        String pathName = 'New Path';
                        while (pathNames.contains(pathName)) {
                          pathName = 'New ' + pathName;
                        }
                        setState(() {
                          _paths.add(RobotPath([
                            Waypoint(
                              anchorPoint: Point(1.0, 3.0),
                              nextControl: Point(2.0, 3.0),
                            ),
                            Waypoint(
                              prevControl: Point(3.0, 4.0),
                              anchorPoint: Point(3.0, 5.0),
                              isReversal: true,
                            ),
                            Waypoint(
                              prevControl: Point(4.0, 3.0),
                              anchorPoint: Point(5.0, 3.0),
                            ),
                          ], name: pathName));
                          _currentPath = _paths.last;
                          _currentPath!.savePath(
                              _pathsDir!.path, _generateJSON, _generateCSV);
                          UndoRedo.clearHistory();
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpdateNotification() {
    return Visibility(
      visible: _updateAvailable,
      child: SlideTransition(
        position: _offsetAnimation,
        child: Align(
          alignment: FractionalOffset.topLeft,
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              color: Colors.white.withOpacity(0.13),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Update Available!',
                          style: TextStyle(fontSize: 20),
                        ),
                        SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () async {
                            if (await canLaunch(_releaseURL)) {
                              launch(_releaseURL);
                            }
                          },
                          child: Text(
                            'Update',
                            style: TextStyle(fontSize: 16),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_createNewProject == true) {
      var projectNameController = TextEditingController();

      return Stack(
        children: [
          Center(
              child: Padding(
            padding: const EdgeInsets.all(48.0),
            child: Image.asset('images/field22.png'),
          )),
          Center(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                color: Colors.black.withOpacity(0.15),
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: Row(
                    mainAxisSize: MainAxisSize.max,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Column(
                        mainAxisSize: MainAxisSize.max,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Project Name',
                            style: TextStyle(fontSize: 48),
                          ),
                          SizedBox(height: 96),
                          ElevatedButton(
                            child: Padding(
                              padding: const EdgeInsets.all(6.0),
                              child: Text(
                                'Create Project',
                                style: TextStyle(fontSize: 24),
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                                primary: Colors.grey[700]),
                            onPressed: () {
                              _createNewProjectDirectory(
                                  projectNameController.text);
                              setState(() {
                                _createNewProject = false;
                              });
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Center(
            child: TextField(
              controller: projectNameController,
              maxLines: 1,
            ),
          ),
        ],
      );
    } else if (_currentProject == null && _welcomeWindow == false) {
      List projects = _projectSelection();

      return Scaffold(
          floatingActionButton: FloatingActionButton.extended(
            label: Text('Create New Project'), // <-- Text

            icon: Icon(
              // <-- Icon
              Icons.add,
              size: 24.0,
            ),
            onPressed: () {
              setState(() {
                _createNewProject = true;
              });
            },
          ),
          floatingActionButtonLocation:
              FloatingActionButtonLocation.centerFloat,
          appBar: AppBar(
            title: Text('Select project to edit'),
          ),
          body: ListView.builder(
            itemCount: projects.length,
            itemBuilder: (BuildContext context, int index) {
              return ListTile(
                title: Text(projects[index].path),
                onTap: () {
                  // Update the state of the app
                  setState(() {
                    _currentProjectName = projects[index].path;
                  });
                  _openProjectDialog(context, projects[index].path);
                },
              );
            },
          ));
    } else if (_currentProject != null && _welcomeWindow == false) {
      return Center(
        child: Container(
          child: PathEditor(_currentPath!, _robotWidth, _robotLength,
              _holonomicMode, _generateJSON, _generateCSV, _pathsDir!.path),
        ),
      );
    } else {
      return Stack(
        children: [
          Center(
              child: Padding(
            padding: const EdgeInsets.all(48.0),
            child: Image.asset('images/field22.png'),
          )),
          Center(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                color: Colors.black.withOpacity(0.15),
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: Row(
                    mainAxisSize: MainAxisSize.max,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Column(
                        mainAxisSize: MainAxisSize.max,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                              width: 200,
                              height: 200,
                              child: Image(
                                image: AssetImage('images/icon2.png'),
                              )),
                          Text(
                            'QuickPath',
                            style: TextStyle(fontSize: 40),
                          ),
                          SizedBox(height: 10),
                          ElevatedButton(
                            child: Padding(
                              padding: const EdgeInsets.all(6.0),
                              child: Text(
                                'Open Robot Project',
                                style: TextStyle(fontSize: 20),
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                                primary: Colors.grey[700]),
                            onPressed: () {
                              setState(() {
                                _currentProjectName = null;
                                _welcomeWindow = false;
                              });
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }
  }

  void _loadPaths(String? projectDir, String? pathsDir) {
    if (projectDir != null && pathsDir != null) {
      List<RobotPath> paths = [];
      _currentProject = Directory(projectDir);
      _pathsDir = Directory(pathsDir);
      if (!_pathsDir!.existsSync()) {
        _pathsDir!.createSync(recursive: true);
      }
      List<FileSystemEntity> pathFiles = _pathsDir!.listSync();
      for (FileSystemEntity e in pathFiles) {
        if (e.path.endsWith('.path')) {
          String json = File(e.path).readAsStringSync();
          RobotPath p = RobotPath.fromJson(jsonDecode(json));
          p.name = basenameWithoutExtension(e.path);
          paths.add(p);
        }
      }
      List<String>? pathOrder = _prefs.getStringList('pathOrder');
      List<String> loadedOrder = [];
      for (RobotPath path in paths) {
        loadedOrder.add(path.name);
      }
      List<RobotPath> orderedPaths = [];
      if (pathOrder != null) {
        for (String name in pathOrder) {
          int loadedIndex = loadedOrder.indexOf(name);
          if (loadedIndex != -1) {
            loadedOrder.removeAt(loadedIndex);
            orderedPaths.add(paths.removeAt(loadedIndex));
          }
        }
        for (RobotPath path in paths) {
          orderedPaths.add(path);
        }
      } else {
        orderedPaths = paths;
      }
      if (orderedPaths.length == 0) {
        orderedPaths.add(RobotPath(
          [
            Waypoint(
              anchorPoint: Point(1.0, 3.0),
              nextControl: Point(2.0, 3.0),
            ),
            Waypoint(
              prevControl: Point(3.0, 4.0),
              anchorPoint: Point(3.0, 5.0),
              isReversal: true,
            ),
            Waypoint(
              prevControl: Point(4.0, 3.0),
              anchorPoint: Point(5.0, 3.0),
            ),
          ],
          name: 'New Path',
        ));
      }
      _paths = orderedPaths;
      _currentPath = _paths[0];
    }
  }

  void _openProjectDialog(BuildContext context, String projectPath) async {
    //menu needed to select project before opening it here

    Directory pathsDir;

    if (Platform.isWindows) {
      pathsDir = Directory(projectPath + "\\paths\\");
    } else {
      pathsDir = Directory(projectPath + "/paths/");
    }
    pathsDir.createSync(recursive: true);

    _prefs.setString('currentProjectDir', projectPath);
    _prefs.setString('currentPathsDir', pathsDir.path);
    _prefs.remove('pathOrder');

    setState(() {
      _currentProject = Directory(projectPath);
      _loadPaths(_currentProject!.path, pathsDir.path);
      _welcomeWindow = false;
    });
  }

  Future<String> getCurrentWorkingDirectory() async {
    Directory appDocDir = await getApplicationDocumentsDirectory();
    String appDocPath = appDocDir.path;
    return appDocPath;
  }

  List _projectSelection() {
    String quickpath_folder;
    if (Platform.isWindows) {
      quickpath_folder = '\\QuickPath\\';
    } else {
      quickpath_folder = '/QuickPath/';
    }

    Directory projectsDir = Directory(_appDocPath! + quickpath_folder);

    projectsDir.createSync(recursive: true);
    List projects = projectsDir.listSync();

    return projects;
  }

  void _createNewProjectDirectory(String projectName) {
    String quickpath_folder;
    if (Platform.isWindows) {
      quickpath_folder = '\\QuickPath\\';
    } else {
      quickpath_folder = '/QuickPath/';
    }
    Directory projectsDir =
        Directory(_appDocPath! + quickpath_folder + projectName);

    projectsDir.createSync(recursive: true);
  }
}
