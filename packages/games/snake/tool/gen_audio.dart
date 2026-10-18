// Regenerates assets/audio/*.wav. Run from the package root:
//   dart run tool/gen_audio.dart
import 'dart:io';

import 'package:lcd_kit/synth.dart';

import 'snake_sounds.dart';

void main() {
  Directory('assets/audio').createSync(recursive: true);
  final paths = writeSounds(
    'assets/audio',
    allSounds,
    (path, bytes) => File(path).writeAsBytesSync(bytes),
  );
  paths.forEach(stdout.writeln);
}
