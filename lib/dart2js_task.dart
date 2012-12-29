// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library dart2js;

import 'dart:io';
import 'dart:uri';
import 'package:buildtool/buildtool.dart';
import 'package:buildtool/task.dart';
import 'package:buildtool/src/utils.dart';
import 'package:logging/logging.dart';

Logger get _logger => new Logger('dart2js');

/** Adds a dart2js task to the build configuration. */
Dart2JSTask dart2js({String name: "dart2js", List<String> files}) =>
    addTask(files, new Dart2JSTask(name));

Path get _dart2jsPath => new Path.fromNative(new Options().executable)
    .directoryPath.append('dart2js');

/** Runs dart2js on the input files. */
class Dart2JSTask extends Task {

  Path outDirectory;

  Dart2JSTask(String name) : super(name);
  Dart2JSTask.withOutDir(String name, this.outDirectory) : super(name);

  Future<TaskResult> run(List<InputFile> files, Path outDir, Path genDir) {
    if (outDirectory != null) {
      outDir = outDirectory;
    }

    _logger.info("dart2js task starting. files: $files");
    var futureGroup = new FutureGroup();
    for (var file in files) {
      var outPath = outDir.append('${file.path}.js');
      var outFileDir = outPath.directoryPath;

      new Directory.fromPath(outFileDir).createSync(recursive: true);

      var options = new ProcessOptions()
        ..workingDirectory = new Directory.current().path;
      var args = ['--out=$outPath', '--verbose', file.inputPath.toNativePath()];

      _logger.fine("running $_dart2jsPath args: $args");
      futureGroup.add(Process.run(_dart2jsPath.toNativePath(), args, options)
        ..transform((ProcessResult result) {
          _logger.fine("dart2js exitCode: ${result.exitCode}");
          return result;
        })
        ..transformException((e) {
          _logger.severe("error: $e");
          throw e;
        }));
    }
    return futureGroup.future.transform((_) {
      _logger.info("dartjs tasks complete");
      var messages = [];
      var success = futureGroup.futures.every((f) => f.value.exitCode == 0);
      for (var f in futureGroup.futures) {
        ProcessResult r = f.value;
        messages.add(r.stdout);
        messages.add(r.stderr);
      }
      return new TaskResult(success, [], {}, messages);
    });
  }
}
