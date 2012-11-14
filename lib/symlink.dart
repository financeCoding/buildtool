// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

part of buildtool;

/**
 * Creates a symlink to the pub packages directory in the output location. The
 * returned future completes when the symlink was created (or immediately if it
 * already exists).
 */
// copied and modified from dwc.dart
Future symlink(Path toPath, Path fromPath) {

  // A resolved symlink works like a directory
  // TODO(sigmund): replace this with something smarter once we have good
  // symlink support in dart:io
  if (new Directory.fromPath(toPath).existsSync()) {
    // Packages directory already exists.
    return new Future.immediate(null);
  }

  // A broken symlink works like a file
  var toFile = new File.fromPath(toPath);
  if (toFile.existsSync()) {
    toFile.deleteSync();
  }

  // [fullPathSync] will canonicalize the path, resolving any symlinks.
  // TODO(sigmund): once it's possible in dart:io, we just want to use a full
  // path, but not necessarily resolve symlinks.
  var from = new File.fromPath(fromPath).fullPathSync().toString();
  var to = toPath.toString();

  var command = 'ln';
  var args = ['-s', from, to];

  if (Platform.operatingSystem == 'windows') {
    // This uses the same technique as 'pub' to create symlinks in windows,
    // which only works on Vista or later. 
    command = 'mklink';
    args = ['/c', 'mklink', '/j', to, from];
  }

  return Process.run(command, args).transform((result) {
    if (result.exitCode != 0) {
      var details = 'subprocess stdout:\n${result.stdout}\n'
                    'subprocess stderr:\n${result.stderr}';
      _logger.severe(
        'unable to create symlink\n from: $from\n to:$to\n$details');
    }
    return null;
  });
}
