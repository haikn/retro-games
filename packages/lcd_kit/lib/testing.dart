/// Test doubles for the kit's services (sound and leaderboards).
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';

import 'lcd_kit.dart';

class FakePlayer implements SoundPlayer {
  bool failLoad = false;
  bool failPlay = false;
  final played = <String>[];
  String? looping;
  int ambientCalls = 0;

  @override
  Future<void> configureAmbient() async => ambientCalls++;

  @override
  Future<void> preload(List<String> files) async {
    if (failLoad) throw Exception('no audio');
  }

  @override
  Future<void> play(String file, double volume) async {
    if (failPlay) throw Exception('play failed');
    played.add(file);
  }

  @override
  Future<void> startLoop(String file, double volume) async {
    if (failPlay) throw Exception('loop failed');
    looping = file;
  }

  @override
  Future<void> stopLoop() async => looping = null;

  bool disposed = false;

  @override
  Future<void> dispose() async {
    disposed = true;
    looping = null;
  }
}

class FakeBackend implements LeaderboardBackend {
  bool failSignIn = false;
  bool failSubmit = false;
  bool failShow = false;
  bool hangSignIn = false;
  int signIns = 0;
  int shows = 0;
  final submitted = <int>[];

  @override
  Future<void> signIn() async {
    signIns++;
    if (hangSignIn) return Completer<void>().future;
    if (failSignIn) throw Exception('declined');
  }

  @override
  Future<void> submit(int score) async {
    if (failSubmit) throw Exception('offline');
    submitted.add(score);
  }

  @override
  Future<void> show() async {
    if (failShow) throw Exception('ui failed');
    shows++;
  }
}

/// Loads the real Silkscreen font so widget tests lay text out at its true
/// width (the default test font draws every glyph as a square). Call inside
/// `tester.runAsync`. Finds `packages/lcd_kit/assets/fonts` from the
/// current directory upward.
Future<void> loadLcdFont() async {
  var dir = Directory.current;
  while (true) {
    for (final candidate in [
      '${dir.path}/assets/fonts/Silkscreen-Regular.ttf',
      '${dir.path}/packages/lcd_kit/assets/fonts/Silkscreen-Regular.ttf',
    ]) {
      final regular = File(candidate);
      if (regular.existsSync()) {
        final bold = File(candidate.replaceFirst('Regular', 'Bold'));
        ByteData bytes(File f) => f.readAsBytesSync().buffer.asByteData();
        await (FontLoader('packages/lcd_kit/Silkscreen')
              ..addFont(Future.value(bytes(regular)))
              ..addFont(Future.value(bytes(bold))))
            .load();
        return;
      }
    }
    final parent = dir.parent;
    if (parent.path == dir.path) throw StateError('Silkscreen font not found');
    dir = parent;
  }
}

/// Width in virtual px of [text] in the LCD body style (bold for headers).
/// Load the real font first ([loadLcdFont]) for meaningful numbers.
double lcdTextWidth(String text, {bool bold = false}) {
  final style = LcdText.body(const Color(0xFF000000));
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: bold ? style.copyWith(fontWeight: FontWeight.w700) : style,
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  return painter.width;
}
