// Monitor Dashboard for CloudToLocalLLM
// Usage: dart tools/monitor_dashboard.dart [command]
// Available commands: status, metrics, alerts, config

import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:args/args.dart';

const String appName = 'CloudToLocalLLM';

class Logger {
  final String name;

  Logger(this.name);

  static Logger get root => _root;
  static final Logger _root = Logger('root');

  Level level = Level.info;
  void Function(LogRecord)? onRecord;

  void info(String message) {
    if (onRecord != null) {
      onRecord!(LogRecord(Level.info, message, name));
    } else {
      stdout.writeln('INFO: $message');
    }
  }

  void warning(String message) {
    if (onRecord != null) {
      onRecord!(LogRecord(Level.warning, message, name));
    } else {
      stderr.writeln('WARNING: $message');
    }
  }

  void severe(String message, [Object? error]) {
    if (onRecord != null) {
      onRecord!(LogRecord(Level.severe, message, name, error));
    } else {
      stderr.writeln('SEVERE: $message');
      if (error != null) stderr.writeln(error);
    }
  }
}

class Level {
  final String name;
  final int value;

  const Level(this.name, this.value);

  static const Level info = Level('INFO', 800);
  static const Level warning = Level('WARNING', 900);
  static const Level severe = Level('SEVERE', 1000);
}

class LogRecord {
  final Level level;
  final String message;
  final String loggerName;
  final Object? error;

  LogRecord(this.level, this.message, this.loggerName, [this.error]);
}

Future<void> main(List<String> arguments) async {
  // Initialize logger
  Logger.root.level = Level.info;
  Logger.root.onRecord = (record) {
    if (record.level == Level.severe) {
      stderr.writeln('${record.level.name}: ${record.message}');
      if (record.error != null) stderr.writeln(record.error);
    } else {
      stdout.writeln('${record.level.name}: ${record.message}');
    }
  };

  final parser = ArgParser()
    ..addCommand('status')
    ..addCommand('metrics')
    ..addCommand('alerts')
    ..addCommand('config')
    ..addOption('host',
        abbr: 'h', defaultsTo: 'localhost', help: 'Netdata host')
    ..addOption('port', abbr: 'p', defaultsTo: '19999', help: 'Netdata port')
    ..addFlag('json',
        abbr: 'j', help: 'Output in JSON format', defaultsTo: false)
    ..addFlag('help', help: 'Show this help message', negatable: false);

  try {
    final args = parser.parse(arguments);

    if (args['help']) {
      printHelp(parser);
      return;
    }

    if (args.command == null) {
      stderr.writeln('No command specified.');
      printHelp(parser);
      return;
    }

    final command = args.command!;
    final host = args['host'] as String;
    final port = args['port'] as String;
    final outputJson = args['json'] as bool;

    final baseUrl = 'http://$host:$port/api/v1';

    switch (command.name) {
      case 'status':
        await getStatus(baseUrl, outputJson);
        break;
      case 'metrics':
        await getMetrics(baseUrl, outputJson);
        break;
      case 'alerts':
        await getAlerts(baseUrl, outputJson);
        break;
      case 'config':
        await getConfig(baseUrl, outputJson);
        break;
      default:
        stderr.writeln('Unknown command: ${command.name}');
        printHelp(parser);
    }
  } catch (e) {
    stderr.writeln('Error: $e');
    printHelp(parser);
    exit(1);
  }
}

void printHelp(ArgParser parser) {
  stdout.writeln('$appName Monitoring Dashboard');
  stdout
      .writeln('Usage: dart tools/monitor_dashboard.dart [command] [options]');
  stdout.writeln('');
  stdout.writeln('Commands:');
  stdout
      .writeln('  status     Show the current status of the monitored system');
  stdout.writeln('  metrics    Show key metrics (CPU, RAM, Disk, Network)');
  stdout.writeln('  alerts     Show active alerts');
  stdout.writeln('  config     Show monitoring configuration');
  stdout.writeln('');
  stdout.writeln('Options:');
  stdout.writeln(parser.usage);
}

Future<void> getStatus(String baseUrl, bool outputJson) async {
  stdout.writeln('Getting system status...');

  try {
    final infoResponse = await http.get(Uri.parse('$baseUrl/info'));
    final healthResponse = await http.get(Uri.parse('$baseUrl/health'));

    if (infoResponse.statusCode == 200 && healthResponse.statusCode == 200) {
      final info = json.decode(infoResponse.body);
      final health = json.decode(healthResponse.body);

      if (outputJson) {
        stdout.writeln(json.encode({
          'info': info,
          'health': health,
        }));
        return;
      }

      stdout.writeln('System: ${info['hostname']}');
      stdout.writeln('Version: ${info['version']}');
      stdout.writeln('OS: ${info['os']}');
      stdout.writeln('Uptime: ${formatDuration(info['uptime'] as int)}');
      stdout.writeln(
          'Health: ${health['status'] == 'ok' ? 'Healthy' : 'Issues Detected'}');

      if (health['status'] != 'ok') {
        stdout.writeln('\nWarnings:');
        for (final warning in health['issues']) {
          stdout.writeln('- $warning');
        }
      }
    } else {
      stderr.writeln(
          'Failed to get status. Status code: ${infoResponse.statusCode}');
    }
  } catch (e) {
    stderr.writeln('Error fetching status: $e');
  }
}

Future<void> getMetrics(String baseUrl, bool outputJson) async {
  stdout.writeln('Getting system metrics...');

  try {
    // Get CPU usage
    final cpuResponse = await http
        .get(Uri.parse('$baseUrl/data?chart=system.cpu&format=json&points=1'));
    // Get RAM usage
    final ramResponse = await http
        .get(Uri.parse('$baseUrl/data?chart=system.ram&format=json&points=1'));
    // Get Disk usage
    final diskResponse = await http.get(
        Uri.parse('$baseUrl/data?chart=disk_space._&format=json&points=1'));
    // Get Network usage
    final netResponse = await http
        .get(Uri.parse('$baseUrl/data?chart=system.net&format=json&points=1'));

    if (cpuResponse.statusCode == 200 && ramResponse.statusCode == 200) {
      final cpuData = json.decode(cpuResponse.body);
      final ramData = json.decode(ramResponse.body);
      final diskData = diskResponse.statusCode == 200
          ? json.decode(diskResponse.body)
          : null;
      final netData =
          netResponse.statusCode == 200 ? json.decode(netResponse.body) : null;

      if (outputJson) {
        stdout.writeln(json.encode({
          'cpu': cpuData,
          'ram': ramData,
          'disk': diskData,
          'network': netData,
        }));
        return;
      }

      // Calculate CPU usage
      final cpuUsage = calculateCpuUsage(cpuData);
      stdout.writeln('CPU Usage: ${cpuUsage.toStringAsFixed(2)}%');

      // Calculate RAM usage
      if (ramData['data'] != null && ramData['data'].isNotEmpty) {
        final ramTotal = ramData['dimensions']['total']['value'];
        final ramFree = ramData['dimensions']['free']['value'];
        final ramUsed = ramTotal - ramFree;
        final ramUsagePercent = (ramUsed / ramTotal) * 100;

        stdout.writeln(
            'RAM Usage: ${ramUsagePercent.toStringAsFixed(2)}% (${formatBytes(ramUsed)} / ${formatBytes(ramTotal)})');
      }

      // Display disk usage if available
      if (diskData != null &&
          diskData['data'] != null &&
          diskData['data'].isNotEmpty) {
        stdout.writeln('\nDisk Usage:');
        // Process disk data
        final diskAvail = diskData['dimensions']['avail']['value'];
        final diskUsed = diskData['dimensions']['used']['value'];
        final diskTotal = diskAvail + diskUsed;
        final diskUsagePercent = (diskUsed / diskTotal) * 100;

        stdout.writeln(
            '  Usage: ${diskUsagePercent.toStringAsFixed(2)}% (${formatBytes(diskUsed)} / ${formatBytes(diskTotal)})');
      }

      // Display network usage if available
      if (netData != null &&
          netData['data'] != null &&
          netData['data'].isNotEmpty) {
        stdout.writeln('\nNetwork:');
        // Process network data
        final netIn = netData['dimensions']['received']['value'];
        final netOut = netData['dimensions']['sent']['value'];

        stdout.writeln('  In: ${formatBytes(netIn)}/s');
        stdout.writeln('  Out: ${formatBytes(netOut)}/s');
      }
    } else {
      stderr.writeln(
          'Failed to get metrics. Status code: ${cpuResponse.statusCode}');
    }
  } catch (e) {
    stderr.writeln('Error fetching metrics: $e');
  }
}

Future<void> getAlerts(String baseUrl, bool outputJson) async {
  stdout.writeln('Getting active alerts...');

  try {
    final response = await http.get(Uri.parse('$baseUrl/alarms?active=true'));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);

      if (outputJson) {
        stdout.writeln(json.encode(data));
        return;
      }

      if (data.isEmpty) {
        stdout.writeln('No active alerts.');
        return;
      }

      stdout.writeln('Active Alerts:');
      data.forEach((key, alert) {
        stdout.writeln(
            '- ${alert['name']} (${alert['chart']}): ${alert['status']}');
        stdout.writeln('  Value: ${alert['value']}');
        stdout.writeln(
            '  Since: ${formatTimestamp(alert['last_status_change'] as int)}');
        stdout.writeln('');
      });
    } else {
      stderr
          .writeln('Failed to get alerts. Status code: ${response.statusCode}');
    }
  } catch (e) {
    stderr.writeln('Error fetching alerts: $e');
  }
}

Future<void> getConfig(String baseUrl, bool outputJson) async {
  stdout.writeln('Getting monitoring configuration...');

  try {
    final response =
        await http.get(Uri.parse('$baseUrl/allmetrics?format=json'));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);

      if (outputJson) {
        stdout.writeln(json.encode(data));
        return;
      }

      stdout.writeln('Monitoring Configuration:');
      stdout.writeln('Hostname: ${data['hostname']}');
      stdout.writeln('Update Every: ${data['update_every']} seconds');
      stdout.writeln('History: ${data['history']} entries');
      stdout.writeln('Memory Mode: ${data['memory_mode']}');
      stdout
          .writeln('Custom Dashboards: ${data['charts']['custom'] ?? 'None'}');

      stdout.writeln('\nAvailable Charts:');
      int chartCount = 0;
      data['charts'].forEach((type, charts) {
        if (type != 'custom') {
          chartCount += (charts.length as int);
        }
      });
      stdout.writeln('Total Charts: $chartCount');

      // Print a few example charts
      stdout.writeln('\nExample Charts:');
      int count = 0;
      data['charts'].forEach((type, charts) {
        if (type != 'custom' && count < 5) {
          charts.forEach((chartName, chartInfo) {
            if (count < 5) {
              stdout.writeln('- $chartName (${chartInfo['title']})');
              count++;
            }
          });
        }
      });
      stdout.writeln('...');
    } else {
      stderr.writeln(
          'Failed to get configuration. Status code: ${response.statusCode}');
    }
  } catch (e) {
    stderr.writeln('Error fetching configuration: $e');
  }
}

double calculateCpuUsage(Map<String, dynamic> cpuData) {
  if (cpuData['data'] == null || cpuData['data'].isEmpty) {
    return 0.0;
  }

  // Calculate the total CPU usage by summing user, system, etc. and subtracting idle
  double total = 0;
  double idle = 0;

  cpuData['dimensions'].forEach((key, value) {
    if (key == 'idle') {
      idle = (value['value'] as num).toDouble();
    } else {
      total += (value['value'] as num).toDouble();
    }
  });

  final cpuUsage = (total / (total + idle)) * 100;
  return cpuUsage;
}

String formatBytes(dynamic bytes) {
  if (bytes == null) return '0 B';

  double value = (bytes as num).toDouble();
  final units = ['B', 'KB', 'MB', 'GB', 'TB'];
  int unitIndex = 0;

  while (value >= 1024 && unitIndex < units.length - 1) {
    value /= 1024;
    unitIndex++;
  }

  return '${value.toStringAsFixed(2)} ${units[unitIndex]}';
}

String formatDuration(int seconds) {
  final days = seconds ~/ 86400;
  final hours = (seconds % 86400) ~/ 3600;
  final minutes = (seconds % 3600) ~/ 60;
  final remainingSeconds = seconds % 60;

  if (days > 0) {
    return '$days days, $hours hours';
  } else if (hours > 0) {
    return '$hours hours, $minutes minutes';
  } else if (minutes > 0) {
    return '$minutes minutes, $remainingSeconds seconds';
  } else {
    return '$seconds seconds';
  }
}

String formatTimestamp(int timestamp) {
  final date = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}:${date.second.toString().padLeft(2, '0')}';
}
