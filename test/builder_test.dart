library builder_test;

import 'dart:io';
import 'package:unittest/unittest.dart';
import 'package:buildtool/buildtool.dart';
import 'test_task.dart';

main() {
  var outPath = new Path('test/data/output');
  var genPath =  new Path('test/data/gen');
  // the test task doesn't touch files, so it's ok these don't really exist
  var testPath = new Path('test/data/input/test.html');
  var badPath = new Path('test/data/input/test.txt');
  
  tearDown(() {
    new Directory.fromPath(outPath).deleteSync(recursive: true);
    new Directory.fromPath(genPath).deleteSync(recursive: true);
  });
  
  test('basic', () {
    var task = new TestTask();
    
    var builder = new Builder(outPath, genPath);
    builder.addTask([".*\.html"], task);
    
    builder.build([testPath.toString()], [], true).then(expectAsync1((s) {
      // check output and gen directories
      expect(new Directory.fromPath(outPath).existsSync(), true);
      expect(new Directory.fromPath(genPath).existsSync(), true);
      
      // must convert Paths to Strings for equality
      expect(task.files.map(_toString), [testPath].map(_toString));
      expect(task.outDir, outPath);
      expect(task.genDir, genPath);
    }));
  });
}

String _toString(o) => o.toString();

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