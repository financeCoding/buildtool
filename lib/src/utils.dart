// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library utils;

import 'dart:isolate';
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
  Future _failedTask;
  final Completer<List> _completer = new Completer<List>();
  final List<Future> futures = <Future>[];

  /** Gets the task that failed, if any. */
  Future get failedTask => _failedTask;

  /**
   * Wait for [task] to complete.
   *
   * If this group has already been marked as completed, you'll get a
   * [FutureAlreadyCompleteException].
   *
   * If this group has a [failedTask], new tasks will be ignored, because the
   * error has already been signaled.
   */
  void add(Future task) {
    if (_failedTask != null) return;
    if (_pending == _FINISHED) throw new FutureAlreadyCompleteException();

    _pending++;
    futures.add(task);
    if (task.isComplete) {
      // TODO(jmesserly): maybe Future itself should do this itself?
      // But we'd need to fix dart:mirrors to have a sync version.
      setImmediate(() => _watchTask(task));
    } else {
      _watchTask(task);
    }
  }

  void _watchTask(Future task) {
    task.handleException((e) {
      if (_failedTask != null) return;
      _failedTask = task;
      _completer.completeException(e, task.stackTrace);
      return true;
    });
    task.then((_) {
      if (_failedTask != null) return;
      _pending--;
      if (_pending == 0) {
        _pending = _FINISHED;
        _completer.complete(futures);
      }
    });
  }

  Future<List> get future => _completer.future;
}

// TODO(jmesserly): this should exist in dart:isolates
/**
 * Adds an event to call [callback], so the event loop will call this after the
 * current stack has unwound.
 */
void setImmediate(void callback()) {
  var port = new ReceivePort();
  port.receive((msg, sendPort) {
    port.close();
    callback();
  });
  port.toSendPort().send(null);
}
