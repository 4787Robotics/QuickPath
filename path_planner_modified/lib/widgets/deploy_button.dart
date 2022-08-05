import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/material.dart';
import 'package:multicast_dns/multicast_dns.dart';

class DeployFAB extends StatelessWidget {
  //final Directory? projectDir;
  double teamNumber;
  String path_name;
  bool generateJSON;
  bool generateCSV;

  //removed super.key, was that needed?
  //DeployFAB({required this.projectDir, required this.roborio_hostname});
  DeployFAB({
    required this.teamNumber,
    required this.path_name,
    required this.generateJSON,
    required this.generateCSV,
  });

  @override
  Widget build(BuildContext context) {
    ColorScheme colorScheme = Theme.of(context).colorScheme;

    String slash;
    if (Platform.isWindows) {
      slash = '\\';
    } else {
      slash = '/';
    }

    return Tooltip(
      message: 'Deploy Robot Code',
      waitDuration: Duration(milliseconds: 500),
      child: FloatingActionButton.extended(
        icon: Icon(Icons.send_rounded),
        label: Text('Deploy'),
        onPressed: () async {
          if (teamNumber == 0) {
            _showSnackbar(
              context,
              'Please set team number in the app drawer under settings',
            );
          } else {
            String roborio_hostname =
                "roboRIO-" + teamNumber.toStringAsFixed(0) + "-FRC.local";

            _showSnackbar(
              context,
              'Starting multicast dns discovery...',
            );
            final MDnsClient mdns_client = MDnsClient(rawDatagramSocketFactory:
                (dynamic host, int port,
                    {bool? reuseAddress, bool? reusePort, int? ttl}) {
              return RawDatagramSocket.bind(host, port,
                  reuseAddress: true, reusePort: false, ttl: ttl!);
            });

            try {
              await mdns_client.start();

              _showSnackbar(
                context,
                'Searching for roboRIO on ${roborio_hostname} ',
              );
              var roboRIO_ipAddress;
              try {
                roboRIO_ipAddress = await mdns_client
                    .lookup<IPAddressResourceRecord>(
                        ResourceRecordQuery.addressIPv4(roborio_hostname))
                    .first;
                _showSnackbar(
                  context,
                  'Stopping multicast dns client...',
                );
                mdns_client.stop();
                _showSnackbar(
                  context,
                  'Starting ssh client...',
                );
                try {
                  final ssh_client = SSHClient(
                    await SSHSocket.connect(
                        roboRIO_ipAddress.address.address, 22),
                    username: 'lvuser',
                    onPasswordRequest: () => '',
                  );

                  _showSnackbar(
                    context,
                    'Uploading files...',
                  );
                  try {
                    final sftp = await ssh_client.sftp();

                    //Makes directory if it doesn't exist
                    //if it does, it'll throw an error, so just catch it and move on
                    try {
                      await sftp.mkdir('/home/lvuser/deploy/paths/QuickPath');
                    } catch (e) {}

                    var paths = await Directory(path_name).listSync();

                    for (FileSystemEntity path in paths) {
                      if (path is File) {
                        var data =
                            await File(path.absolute.path).readAsString();

                        final file = await sftp.open(
                            '/home/lvuser/deploy/paths/QuickPath/' +
                                path.path.split(slash).last,
                            mode: SftpFileOpenMode.create |
                                SftpFileOpenMode.truncate |
                                SftpFileOpenMode.write);

                        await file.writeBytes(utf8.encode(data) as Uint8List);
                      }
                    }
                    if (generateJSON) {
                      try {
                        await sftp.mkdir(
                            '/home/lvuser/deploy/paths/QuickPath/generatedJSON');
                      } catch (e) {}
                      var paths =
                          await Directory(path_name + 'generatedJSON' + slash)
                              .listSync();
                      for (FileSystemEntity path in paths) {
                        if (path is File) {
                          var data =
                              await File(path.absolute.path).readAsString();

                          final file = await sftp.open(
                              '/home/lvuser/deploy/paths/QuickPath/generatedJSON/' +
                                  path.path.split(slash).last,
                              mode: SftpFileOpenMode.create |
                                  SftpFileOpenMode.truncate |
                                  SftpFileOpenMode.write);

                          await file.writeBytes(utf8.encode(data) as Uint8List);
                        }
                      }
                    }
                    if (generateCSV) {
                      try {
                        await sftp.mkdir(
                            '/home/lvuser/deploy/paths/QuickPath/generatedCSV');
                      } catch (e) {}

                      var paths =
                          await Directory(path_name + 'generatedCSV' + slash)
                              .listSync();
                      for (FileSystemEntity path in paths) {
                        if (path is File) {
                          var data =
                              await File(path.absolute.path).readAsString();
                          final file = await sftp.open(
                              '/home/lvuser/deploy/paths/QuickPath/generatedCSV/' +
                                  path.path.split(slash).last,
                              mode: SftpFileOpenMode.create |
                                  SftpFileOpenMode.truncate |
                                  SftpFileOpenMode.write);
                          await file.writeBytes(utf8.encode(data) as Uint8List);
                        }
                      }
                    }

                    _showSnackbar(
                      context,
                      'Successfully loaded all paths!',
                    );
                  } catch (e) {
                    _showSnackbar(
                      context,
                      'Failed to upload files: ${e}',
                    );
                  }
                } catch (e) {
                  _showSnackbar(
                    context,
                    'Failed to start ssh client: ${e}',
                  );
                }
              } catch (e) {
                _showSnackbar(
                  context,
                  'Could not find roboRIO, are you connected to its wifi?',
                );
              }
            } catch (e) {
              _showSnackbar(
                context,
                'Failed to start multicast dns client: ${e}',
              );
            }
          }
        },
      ),
    );
  }

  void _showSnackbar(BuildContext context, String message,
      {Duration? duration, Color textColor = Colors.white}) {
    ColorScheme colorScheme = Theme.of(context).colorScheme;

    ScaffoldMessenger.of(context).removeCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
        message,
        style: TextStyle(color: textColor, fontSize: 16),
      ),
      duration: duration ?? Duration(milliseconds: 4000),
      backgroundColor: colorScheme.surfaceVariant,
    ));
  }
}
