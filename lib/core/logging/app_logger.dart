import 'package:logger/logger.dart';

/// Structured logger that never writes secrets.
class AppLogger {
  AppLogger({bool enabled = true})
    : _logger = Logger(
        level: enabled ? Level.debug : Level.off,
        printer: PrettyPrinter(
          methodCount: 0,
          errorMethodCount: 6,
          lineLength: 80,
          dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
        ),
      );

  final Logger _logger;

  static const _redactedKeys = {
    'authorization',
    'accesstoken',
    'refreshtoken',
    'otp',
    'password',
    'clientsecret',
    'apitoken',
  };

  void debug(String message, {String? feature, Map<String, Object?>? data}) {
    _logger.d(_format(message, feature: feature, data: data));
  }

  void info(String message, {String? feature, Map<String, Object?>? data}) {
    _logger.i(_format(message, feature: feature, data: data));
  }

  void warning(String message, {String? feature, Map<String, Object?>? data}) {
    _logger.w(_format(message, feature: feature, data: data));
  }

  void error(
    String message, {
    String? feature,
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? data,
  }) {
    _logger.e(
      _format(message, feature: feature, data: data),
      error: error,
      stackTrace: stackTrace,
    );
  }

  String _format(
    String message, {
    String? feature,
    Map<String, Object?>? data,
  }) {
    final buffer = StringBuffer(message);
    if (feature != null) {
      buffer.write(' feature=$feature');
    }
    if (data != null && data.isNotEmpty) {
      buffer.write(' ${sanitize(data)}');
    }
    return buffer.toString();
  }

  static Map<String, Object?> sanitize(Map<String, Object?> input) {
    return input.map((key, value) {
      if (_redactedKeys.contains(key.toLowerCase())) {
        return MapEntry(key, '[redacted]');
      }
      return MapEntry(key, value);
    });
  }
}
