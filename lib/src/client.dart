// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library client;

import 'package:buildtool/buildtool.dart';
import 'package:buildtool/src/common.dart';
import 'package:buildtool/src/utils.dart';
import 'dart:io';
import 'dart:json';

void clientMain(args) {
  var changedFiles = args['changed'];
  var filteredFiles = changedFiles.filter((f) => 
      !(f.startsWith('out') || f == '.buildlog' || f == '.buildlock'));
//  if (filteredFiles.isEmpty) {
//    print("no changed files");
//    exit(0);
//  }
  
  _getServerPort().then((port) {
    var quit = args['quit'];
    if (quit == true) {
      _sendCloseCommand(port).then((s) {
        exit(0);
      });
    } else {
      if (port != null) {
        _sendBuildCommand(port, filteredFiles, args['clean']);
      } else {
        _startServer();
      }
    }
  });
}

final int _CONNECTION_REFUSED = 61;

Future _sendCloseCommand(int port) {
  return _sendJsonRpc(port, '/build');
}

/** Sends a JSON-formatted build command to the build server via HTTP POST. */
Future _sendBuildCommand(int port, List<String> changedFiles, bool cleanBuild) {
  var data = {
    'changed': changedFiles,
    'removed': [],
    'clean': cleanBuild,
  };
  return _sendJsonRpc(port, '/build', data: data);
}

/** 
 * Sends a POST request to the server at path [path] with a JSON 
 * representation of [data] as the request body. The response is parsed as JSON
 * and returned via a Future
 */
Future _sendJsonRpc(int port, String path, {var data, bool isRetry: false}) {
  var completer = new Completer();
  var client = new HttpClient();
  var conn = client.post("localhost", port, path)
    ..onRequest = (req) {
      req.headers.contentType = JSON_TYPE;
      if (data != null) {
        var json = JSON.stringify(data);
        req.contentLength = json.length;
        req.outputStream.writeString(json);
      }
      req.outputStream.close();
    }
    ..onResponse = (res) {
      readStreamAsString(res.inputStream).then((str) {
        var response = JSON.parse(str);
        completer.complete(response);
      });
    }
    ..onError = (SocketIOException e) {
      print("error: $e");
      if (e.osError.errorCode == _CONNECTION_REFUSED && !isRetry) {
        //restart server
        print("restarting server");
        _startServer().then((port) {
          print("restarted server on port $port");
          _sendJsonRpc(port, path, data: data, isRetry: true)
              .then(completer.complete);
        });
      } else {
        completer.completeException(e);
      }
    };
  return completer.future;
}

Future<int> _getServerPort() {
  var completer = new Completer();
  var lockFile = new File('.buildlock');
  lockFile.exists().then((exists) {
    if (exists) {
      var sb = new StringBuffer();
      var sis = new StringInputStream(lockFile.openInputStream());
      sis
        ..onData = () {
          sb.add(sis.read());
        }
        ..onClosed = () {
          try {
            var port = int.parse(sb.toString());
            print("server already running onport: $port");
            completer.complete(port);
          } on Error catch (e) {
            completer.completeException(e);
          }
        };
    } else { 
      _startServer().then((port) {
        completer.complete(port);
      });
    }
  });
  return completer.future;
}

Future<int> _startServer() {
  var completer = new Completer(); 
  var vmExecutable = new Options().executable;
  Process.start(vmExecutable, ["build.dart", "--server"]).then((process) {
    var sis = new StringInputStream(process.stdout);
    sis.onData = () {
      var line = sis.readLine();
      print(line);
      if (line.startsWith("port: ")) {
        var port = int.parse(line.substring("port: ".length));
        completer.complete(port);
      }
    };
  });
  return completer.future;
}