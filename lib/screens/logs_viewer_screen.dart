import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cross_file/cross_file.dart';
import 'dart:io';
import '../services/logger_service.dart';

class LogsViewerScreen extends StatefulWidget {
  const LogsViewerScreen({super.key});

  @override
  State<LogsViewerScreen> createState() => _LogsViewerScreenState();
}

class _LogsViewerScreenState extends State<LogsViewerScreen> {
  String _logs = '';
  bool _isLoading = true;
  final ScrollController _scrollController = ScrollController();
  LogType? _selectedLogType;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    setState(() => _isLoading = true);
    final logs = await LoggerService.getLogs();
    setState(() {
      _logs = logs;
      _isLoading = false;
    });
  }

  Future<void> _shareLogs() async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/shared_logs.txt');
    await file.writeAsString(_getFilteredLogs());
    await Share.shareXFiles([XFile(file.path)], text: 'App Logs');
  }

  Future<void> _clearLogs() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Clear Logs'),
            content: const Text('Are you sure you want to clear all logs?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Clear'),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      await LoggerService.clearLogs();
      await _loadLogs();
    }
  }

  String _getFilteredLogs() {
    if (_logs.isEmpty) return '';

    try {
      final List<String> logLines = _logs.split('\n');
      final List<Map<String, dynamic>> parsedLogs =
          logLines
              .where((line) => line.isNotEmpty)
              .map((line) => jsonDecode(line) as Map<String, dynamic>)
              .toList();

      final filteredLogs =
          parsedLogs.where((log) {
            final bool typeMatch =
                _selectedLogType == null ||
                log['type'].toString().toLowerCase() ==
                    _selectedLogType.toString().split('.').last.toLowerCase();

            final bool searchMatch =
                _searchQuery.isEmpty ||
                log['message'].toString().toLowerCase().contains(
                  _searchQuery.toLowerCase(),
                ) ||
                log['tag'].toString().toLowerCase().contains(
                  _searchQuery.toLowerCase(),
                );

            return typeMatch && searchMatch;
          }).toList();

      return filteredLogs.map((log) => _formatLogEntry(log)).join('\n\n');
    } catch (e) {
      return 'Error parsing logs: $e';
    }
  }

  String _formatLogEntry(Map<String, dynamic> log) {
    final buffer = StringBuffer();
    buffer.writeln('${log['timestamp']} [${log['type']}]');
    buffer.writeln('Tag: ${log['tag']}');
    buffer.writeln('Message: ${log['message']}');
    if (log.containsKey('data')) {
      buffer.writeln(
        'Data: ${const JsonEncoder.withIndent('  ').convert(log['data'])}',
      );
    }
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('App Logs'),
        actions: [
          IconButton(icon: const Icon(Icons.share), onPressed: _shareLogs),
          IconButton(icon: const Icon(Icons.delete), onPressed: _clearLogs),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadLogs),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: 'Search logs...',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (value) {
                      setState(() => _searchQuery = value);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                DropdownButton<LogType?>(
                  value: _selectedLogType,
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('All Types'),
                    ),
                    ...LogType.values.map(
                      (type) => DropdownMenuItem(
                        value: type,
                        child: Text(type.toString().split('.').last),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() => _selectedLogType = value);
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child:
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : SingleChildScrollView(
                      controller: _scrollController,
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          _getFilteredLogs(),
                          style: const TextStyle(fontFamily: 'monospace'),
                        ),
                      ),
                    ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        },
        child: const Icon(Icons.arrow_downward),
      ),
    );
  }
}
