library pretty_logger;

import 'dart:async';

import 'package:socket_io_client/socket_io_client.dart' as IO;

import 'package:multicast_dns/multicast_dns.dart';

enum Level {
  verbose,
  debug,
  info,
  warn,
  error,
}

class Logger {
  static final shared = Logger();

  Logger({String url}) {
    _url = url;
    _start();
  }

  v(String domain, dynamic message, [dynamic error, StackTrace stackTrace]) {
    log(Level.verbose, domain, message, error, stackTrace);
  }

  d(String domain, dynamic message, [dynamic error, StackTrace stackTrace]) {
    log(Level.debug, domain, message, error, stackTrace);
  }

  i(String domain, dynamic message, [dynamic error, StackTrace stackTrace]) {
    log(Level.info, domain, message, error, stackTrace);
  }

  w(String domain, dynamic message, [dynamic error, StackTrace stackTrace]) {
    log(Level.warn, domain, message, error, stackTrace);
  }

  e(String domain, dynamic message, [dynamic error, StackTrace stackTrace]) {
    log(Level.error, domain, message, error, stackTrace);
  }

  log(Level level, String domain, dynamic message, [dynamic error, StackTrace stackTrace]) {
    final l = level.index;
    final d = domain;
    final n = DateTime.now().millisecondsSinceEpoch;
    final m = _toJsonObject(message);
    final e = _toJsonObject(error);
    final t = _parseStackTrace(stackTrace, 1024);
    Map<String, dynamic> p = {'l': l, 'd': d, 'n': n, 'm': m, 'e': e, 't': t};
    if (0 == _ios.length) {
      _caches.add(p);
      return;
    }
    _ios.forEach((key, value) {
      value.emit('report', p);
    });
  }

  String _url;

  Map<String, IO.Socket> _ios = Map();
  static final _stackTraceRegex = RegExp(r'#[0-9]+[\s]+(.+)\(([^\s]+dart)(:\d+:\d+)?\)');

  List<dynamic> _caches = List();
  _start() {
    _search().listen((url) {
      var io = _ios[url];
      if (null != io) {
        return;
      }
      io = IO.io(
        url,
        <String, dynamic>{
          'transports': ['websocket'],
          'autoConnect': false,
          'reconnection': false,
        },
      );
      io.on('connect', (data) {
        if (0 == _caches.length) {
          return;
        }
        _caches.forEach((element) {
          io.emit('report', element);
        });
        _caches.clear();
      });
      _ios[url] = io;
      io.connect();
    });
  }

  Stream<String> _search() async* {
    if (null != _url) {
      yield _url;
      return;
    }
    const name = '_pretty_logger._tcp.local';
    final client = MDnsClient();
    await client.start();
    await for (PtrResourceRecord ptr in client.lookup<PtrResourceRecord>(ResourceRecordQuery.serverPointer(name))) {
      await for (SrvResourceRecord srv in client.lookup<SrvResourceRecord>(ResourceRecordQuery.service(ptr.domainName))) {
        final url = 'http://${srv.target}:${srv.port}';
        yield url;
      }
    }
    client.stop();
    await Future.delayed(Duration(seconds: _ios.length > 0 ? 5 : 1));
    yield* _search();
  }

  dynamic _toJsonObject(dynamic message) {
    if (message == null || message is String || message is num) {
      return message;
    }
    if (message is Map) {
      Map map = {};
      message.forEach((key, value) {
        map[_toJsonObject(key)] = _toJsonObject(value);
      });
      return map;
    }
    if (message is Iterable) {
      List list = [];
      message.forEach((element) {
        list.add(_toJsonObject(element));
      });
      return list;
    }
    return message.toString();
  }

  List<String> _parseStackTrace(StackTrace stackTrace, int maxCount) {
    final lines = stackTrace.toString().split("\n");
    var list = <String>[];
    for (int i = 0, count = lines.length; i < count; i++) {
      if (maxCount <= list.length) {
        break;
      }
      final line = lines[i];
      final match = _stackTraceRegex.matchAsPrefix(line);
      if (match == null) {
        continue;
      }
      if (match.group(2).startsWith('package:pretty_logger')) {
        continue;
      }
      var newLine = ("#${list.length} ${match.group(1)} (${match.group(2)} ${match.group(3) ?? ""})");
      list.add(newLine.replaceAll('<anonymous closure>', '()'));
    }
    if (list.isEmpty) {
      return null;
    }
    return list;
  }
}
