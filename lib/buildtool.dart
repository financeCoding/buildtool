// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library buildtool;

import 'dart:io';
import 'package:args/args.dart';
import 'package:logging/logging.dart';

part 'builder.dart';
part 'symlink.dart';

Logger _logger = new Logger("buildtool");

Builder builder = new Builder(new Path('build-out'), new Path('packages/_gen'));

/** A runnable build task */
abstract class Task {
  
  /** 
   * Called to run the task.
   * 
   * [files] contains a list of changed paths, not necessarily all files
   * covered by this task in the project [outDir] is where final build
   * artifacts must be written to, [genDir] is where generated files that can
   * be referenced by code should be written to.
   */
  Future<TaskResult> run(List<Path> files, Path outDir, Path genDir);
}

class TaskResult {
  final bool succeeded;
  final List<Path> outputs;
  final List<String> messages;
  TaskResult(this.succeeded, this.outputs, this.messages);
  String toString() => "succeeded: $succeeded outs: $outputs";
}

/**
 * Adds a new [Task] to this build which is run when files
 * match against the regex patterns in [files].
 */
void addTask(List<String> files, Task task) => builder.addTask(files, task);

/**
 * Runs the build.
 * 
 * [arguments] is a list of Strings compatible with the command line arguments
 * passed to the build.dart file by the Dart Editor, including:
 *  - --changed: the file has changed since the last build
 *  - --removed: the file was removed since the last build
 *  - clean: remove any build artifacts
 */
Future buildWithArgs(List<String> arguments) {
  var args = _processArgs(arguments);

  var trackDirs = <Directory>[];
  var changedFiles = args["changed"];
  var removedFiles = args["removed"];
  var cleanBuild = args["clean"];
    
  return builder.build(changedFiles, removedFiles, cleanBuild);
}

/** Handle --changed, --removed, --clean and --help command-line args. */
ArgResults _processArgs(List<String> arguments) {
  var parser = new ArgParser()
    ..addOption("changed", help: "the file has changed since the last build",
        allowMultiple: true)
    ..addOption("removed", help: "the file was removed since the last build",
        allowMultiple: true)
    ..addFlag("clean", negatable: false, help: "remove any build artifacts")
    ..addFlag("help", negatable: false, help: "displays this help and exit");
  var args = parser.parse(arguments);
  if (args["help"]) {
    print(parser.getUsage());
    exit(0);
  }
  return args;
}
