// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

part of buildtool;

/** A runnable build configuration */
class Builder {
  final List<_TaskEntry> _tasks = <_TaskEntry>[];
  
  final Path outDir;
  final Path genDir;
  
  Builder(this.outDir, this.genDir);
  
  /**
   * Adds a new [Task] to this builder which is run when files
   * match against the regex patterns in [files].
   */
  void addTask(List<String> files, Task task) {
    _tasks.add(new _TaskEntry(files, task));
  }
  
  /** Start the builder.
   *  If [cleanBuild] is true, the output and gen directories are cleaned
   *  before any tasks are run.
   *  
   *  TODO(justinfagnani): Currently [removedFiles] are not passed to tasks.
   */
  Future build(
      List<String> changedFiles,
      List<String> removedFiles,
      bool cleanBuild) {
    _logger.info("Starting build...");
    
    // ignore inputs in the ouput dir that the Editor forwards
    var filteredFiles = changedFiles.filter((f) => !f.startsWith(outDir.toString()));
    
    return Futures.wait([
        _createLogFile(),
        (cleanBuild) ? _clean() : new Future.immediate(null)])
      .chain((_) => _createDirs())
      .chain((_) {
        var futures = [];
        for (var entry in _tasks) { // TODO: parallelize
          var matches = filteredFiles.filter(entry.matches);
          var paths = matches.map((f) => new Path(f));
          futures.add(entry.task.run(paths, outDir, genDir));
        }
        return Futures.wait(futures);
      })
      .transform((results) {
        _logger.info("Build finished");
        return true;
      });
  }
  
  Future _createLogFile() {
    return new File(".buildlog").create().transform((log) {
      var logStream = log.openOutputStream(FileMode.APPEND);
      _logger.on.record.add((LogRecord r) {
        logStream.writeString(r.toString());
      });
      return true;
    });
  }
  
  /** Cleans the output and gen directories */
  Future _clean() => 
      Futures.wait([_cleanDir(outDir), _cleanDir(genDir)]);

  /** Creates the output and gen directories */
  Future _createDirs() => 
      Futures.wait([_createBuildDir(outDir), _createGenDir(genDir)]);

  /** Creates the output directory and adds a packages/ symlink */
  Future _createBuildDir(Path buildDirPath) {
    var completer = new Completer();
    var dir = new Directory.fromPath(buildDirPath);
    dir.exists().then((exists) {
      var create = (exists) ? new Future.immediate(true) : dir.create();
      create.then((_) {
        // create pub symlink
        var buildDirPackagePath = buildDirPath.append('packages');
        var projectPackagePath = new Path('packages');
        symlink(buildDirPackagePath, projectPackagePath).then((s) {
          completer.complete(s);
        });
      });
    });
    return completer.future;
  }

  /** Creates the gen directory */
  Future<bool> _createGenDir(Path buildDirPath) {
    var completer = new Completer();
    var dir = new Directory.fromPath(buildDirPath);
    dir.exists().then((exists) {
      if (exists) {
        completer.complete(true);
      } else {
        dir.create().then((_) {
        completer.complete(true);
        });
      }
    });
    return completer.future;
  }
  
  /** Cleans the given directory */
  Future<bool> _cleanDir(Path dirPath) {
    var completer = new Completer();
    var dir = new Directory.fromPath(dirPath);
    dir.exists().then((exists) {
      if (!exists) {
        completer.complete(false);
      } else {
        var futures = [];
        dir.list(recursive: false)
          ..onFile = (path) {
            futures.add(new File.fromPath(new Path.fromNative(path)).delete());
          }
          ..onDir = (path) {
            futures.add(new Directory.fromPath(new Path.fromNative(path))
                .delete(recursive: true));          
          };
        Futures.wait(futures).then((_) {
          completer.complete(true);
        });
      }
    });
    return completer.future;
  }
  
  Future _makeGenDir() {
  }
}

class _TaskEntry {
  final List<String> files;
  final Task task;
  List<RegExp> patterns;
  
  _TaskEntry(this.files, this.task) {
    patterns = files.map((f) => new RegExp(f));
  }
  
  bool matches(String filename) => patterns.some((p) => p.hasMatch(filename));
}
