import 'package:flutter/foundation.dart';

class DiagnosticLogEntry {
  final DateTime at;
  final String source;
  final String message;

  DiagnosticLogEntry({
    required this.at,
    required this.source,
    required this.message,
  });
}

class DiagnosticLogState extends ChangeNotifier {
  static final DiagnosticLogState instance = DiagnosticLogState._();

  DiagnosticLogState._();

  final List<DiagnosticLogEntry> _entries = [];

  List<DiagnosticLogEntry> get entries => List.unmodifiable(_entries.reversed);

  void add(String message, {String source = 'app'}) {
    _entries.add(
      DiagnosticLogEntry(at: DateTime.now(), source: source, message: message),
    );
    if (_entries.length > 200) {
      _entries.removeRange(0, _entries.length - 200);
    }
    notifyListeners();
  }

  void clear() {
    _entries.clear();
    notifyListeners();
  }
}
