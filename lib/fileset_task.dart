// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library fileset_task;

import 'dart:io';
import 'package:buildtool/task.dart';
import 'package:buildtool/buildtool.dart';

void fileset({String name, List<String> files}) {
  addTask(files, new FilesetTask(files));
}

class FilesetTask extends Task {
  final List<String> files;
  
  FilesetTask(List<String> this.files);
  
  Future<TaskResult> run(List<Path> files, Path outDir, Path genDir) {
    var cwd = new Directory.current();
    print("getAllFiles: ${cwd.path}");
    var lister = cwd.list(recursive: false);
    lister.onDir = (d) {
      print("dir: $d");
    };
    
  }
}
