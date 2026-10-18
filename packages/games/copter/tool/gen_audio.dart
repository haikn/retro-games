// Regenerates assets/audio/*.wav. Run from the package root:
//   dart run tool/gen_audio.dart
import 'dart:io';

import 'package:lcd_kit/synth.dart';

import 'copter_sounds.dart';

void main() {
  final dir = Directory('assets/audio')..createSync(recursive: true);
  for (final MapEntry(key: name, value: make) in allSounds.entries) {
    final file = File('${dir.path}/$name.wav')
      ..writeAsBytesSync(encodeWav(make()));
    stdout.writeln('Wrote ${file.path} (${file.lengthSync()} bytes)');
  }
}
