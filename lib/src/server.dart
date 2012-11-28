// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library server;

import 'dart:io';
import 'dart:json';
import 'package:buildtool/buildtool.dart';
import 'package:buildtool/src/builder.dart';
import 'package:buildtool/src/utils.dart';
import 'package:logging/logging.dart';

final Logger _logger = new Logger('server');
Builder builder = new Builder(new Path('out'), new Path('packages/gen'));

serverMain() {
  _createLogFile().then((_) {
    _logger.info("startServer");
    var serverSocket = new ServerSocket("127.0.0.1", 0, 0);
    _logger.info("listening on localhost:${serverSocket.port}");
    var server = new HttpServer();
    server.addRequestHandler((req) => req.path == '/build', buildHandler);
    server.defaultRequestHandler = (req, res) {
      print("req.path: ${req.path}");
      res.contentLength = 0;
      res.outputStream.close();
    };
    server.listenOn(serverSocket);
    _writeLockFile(serverSocket.port).then((_) {
      stdout.writeString("buildtool server ready\n");
      stdout.writeString("port: ${serverSocket.port}\n");
    });
  });
}

void buildHandler(HttpRequest req, HttpResponse res) {
  print('build!');
  readStreamAsString(req.inputStream).then((str) {
    print(str);
    var data = JSON.parse(str);
    builder.build(data['changed'], data['removed'], data['clean']);
    res.contentLength = 0;
    res.outputStream.close();    
  });
}

Future _writeLockFile(int port) {
  var completer = new Completer();
  var lockFile = new File('.buildlock');
  var os = lockFile.openOutputStream(FileMode.WRITE);
  os.writeString("$port");
  os.flush();
  os.onNoPendingWrites = () => completer.complete(null);
  return completer.future;
}

Future _createLogFile() {
  return new File(".buildlog").create().transform((log) {
    var logStream = log.openOutputStream(FileMode.APPEND);
    Logger.root.on.record.add((LogRecord r) {
      var m = "${r.time} ${r.level} ${r.message}\n";
      logStream.writeString(m);
      print(m);
    });
    return true;
  });
}
