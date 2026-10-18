import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('lib/core imports neither Flutter nor Flame', () {
    final offenders = <String>[];
    final files = Directory('lib/core')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'));
    for (final file in files) {
      for (final line in file.readAsLinesSync()) {
        final t = line.trim();
        if ((t.startsWith('import ') || t.startsWith('export ')) &&
            (t.contains('package:flutter') ||
                t.contains('package:flame') ||
                t.contains('dart:ui'))) {
          offenders.add('${file.path}: $t');
        }
      }
    }
    expect(files, isNotEmpty);
    expect(offenders, isEmpty);
  });
}
