// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;

void announcePrintFailure(String message) {
  final synth = html.window.speechSynthesis;
  if (synth == null || message.trim().isEmpty) return;

  final utterance = html.SpeechSynthesisUtterance(message)
    ..lang = 'ja-JP'
    ..rate = 0.95
    ..volume = 1.0;
  synth.speak(utterance);
}
