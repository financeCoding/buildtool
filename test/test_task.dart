library test_task;

import 'dart:io';
import 'package:buildtool/buildtool.dart';

class TestTask implements Task {
  List<Path> files;
  Path outDir;
  Path genDir;
  
  Future<TaskResult> run(List<Path> files, Path outDir, Path genDir) {
    print("files: $files");
    this.files = files;
    this.outDir = outDir;
    this.genDir = genDir;
    return new Future.immediate(new TaskResult(true, [], []));
  }
}