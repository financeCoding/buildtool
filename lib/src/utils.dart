// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library utils;

import 'dart:io';

Future<String> readStreamAsString(InputStream stream) {
  var completer = new Completer();
  var sb = new StringBuffer();
  var sis = new StringInputStream(stream);
  sis
  ..onData = () {
    sb.add(sis.read());
  }
  ..onClosed = () {
    completer.complete(sb.toString());
  }
  ..onError = completer.completeException;
  return completer.future;
}

/** A completer that waits until all added [Future]s complete. */
// TODO(sigmund): this should be part of the futures/core libraries.
class FutureGroup {
  const _FINISHED = -1;
  int _pending = 0;
  Completer<List> _completer = new Completer<List>();
  final List<Future> futures = <Future>[];

  /**
   * Wait for [task] to complete (assuming this barrier has not already been
   * marked as completed, otherwise you'll get an exception indicating that a
   * future has already been completed).
   */
  void add(Future task) {
    if (_pending == _FINISHED) {
      throw new FutureAlreadyCompleteException();
    }
    _pending++;
    futures.add(task);
    task.handleException(
        (e) => _completer.completeException(e, task.stackTrace));
    task.then((_) {
      _pending--;
      if (_pending == 0) {
        _pending = _FINISHED;
        _completer.complete(futures);
      }
    });
  }

  Future<List> get future => _completer.future;
}
