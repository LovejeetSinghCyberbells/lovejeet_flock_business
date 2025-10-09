import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

class LoggerService {
  static const String _logFileName = 'app_logs.txt';
  static bool _initialized = false;
  static File? _logFile;
  static final DateFormat _dateFormatter = DateFormat(
    'yyyy-MM-dd HH:mm:ss.SSS',
  );

  static Future<void> initialize() async {
    if (_initialized) return;

    try {
      final directory = await getApplicationDocumentsDirectory();
      _logFile = File('${directory.path}/$_logFileName');
      _initialized = true;

      // Add initialization log
      await log('Logger Service', 'Initialized', LogType.info);
      await log(
        'App Info',
        'Running on ${Platform.isIOS ? "iOS" : "Android"}',
        LogType.info,
      );
      await log(
        'Build Type',
        kReleaseMode ? 'Release/TestFlight' : 'Debug',
        LogType.info,
      );
    } catch (e) {
      debugPrint('Failed to initialize logger: $e');
    }
  }

  static Future<void> log(
    String tag,
    String message,
    LogType type, {
    Map<String, dynamic>? data,
  }) async {
    if (!_initialized) await initialize();
    if (_logFile == null) return;

    final timestamp = _dateFormatter.format(DateTime.now());
    final logEntry = {
      'timestamp': timestamp,
      'tag': tag,
      'type': type.toString().split('.').last,
      'message': message,
      if (data != null) 'data': data,
    };

    try {
      final logString = '${jsonEncode(logEntry)}\n';
      await _logFile!.writeAsString(logString, mode: FileMode.append);

      // Also print to console in debug mode
      if (!kReleaseMode) {
        debugPrint('[$timestamp] $tag: $message');
        if (data != null) debugPrint('Data: ${jsonEncode(data)}');
      }
    } catch (e) {
      debugPrint('Failed to write log: $e');
    }
  }

  static Future<String> getLogs() async {
    if (!_initialized) await initialize();
    if (_logFile == null || !await _logFile!.exists()) return '';

    try {
      return await _logFile!.readAsString();
    } catch (e) {
      return 'Failed to read logs: $e';
    }
  }

  static Future<void> clearLogs() async {
    if (!_initialized) await initialize();
    if (_logFile == null) return;

    try {
      await _logFile!.writeAsString('');
      await log('Logger Service', 'Logs cleared', LogType.info);
    } catch (e) {
      debugPrint('Failed to clear logs: $e');
    }
  }

  static Future<void> exportLogs() async {
    if (!_initialized) await initialize();
    if (_logFile == null) return;

    try {
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final exportFile = File('${directory.path}/logs_export_$timestamp.txt');
      await _logFile!.copy(exportFile.path);
      await log(
        'Logger Service',
        'Logs exported to ${exportFile.path}',
        LogType.info,
      );
    } catch (e) {
      debugPrint('Failed to export logs: $e');
    }
  }
}

enum LogType { info, warning, error, api, token, notification }
