// Marketing capture: renders the real app into store screenshots and clip
// frames. Not part of the normal test run; start it with
// `node marketing/tools/capture.mjs` (or `flutter test test_marketing`).
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lcd_arcade/main.dart';
import 'package:lcd_kit/lcd_kit.dart';
import 'package:lcd_kit/testing.dart';

final _boundary = GlobalKey();
const _out = '../marketing/out';

/// Which parts to produce: `--dart-define=CAPTURE=shots|clips|all`.
const _what = String.fromEnvironment('CAPTURE', defaultValue: 'all');

enum _Game { copter, snake, hop }

extension on _Game {
  String get title => switch (this) {
    _Game.copter => 'Copter',
    _Game.snake => 'Snake',
    _Game.hop => 'Hop',
  };
  bool get landscape => this == _Game.copter;
}

void _view(WidgetTester t, double w, double h, double dpr) {
  t.view.devicePixelRatio = dpr;
  t.view.physicalSize = Size(w * dpr, h * dpr);
  addTearDown(t.view.reset);
}

Future<void> _pumpApp(WidgetTester t) async {
  final services = ArcadeServices.create(
    LocalStore.memory(),
    games,
    backend: (_) => FakeBackend(),
  );
  await t.pumpWidget(
    RepaintBoundary(
      key: _boundary,
      child: LcdArcadeApp(services: services),
    ),
  );
  await t.pump();
}

/// Opens [game] from the launcher and starts a run (ready dialog dismissed).
Future<void> _startRun(
  WidgetTester t,
  _Game game, {
  required void Function(bool landscape) setView,
}) async {
  await t.tap(find.text(game.title));
  await t.pump();
  await t.pump();
  if (game.landscape) {
    setView(true);
    await t.pump();
    await t.pump();
  }
  await t.tap(find.text('New game'));
  await t.pump();
  await t.tapAt(t.getCenter(find.byKey(_boundary)));
  await t.pump();
}

/// Plays a plausible run: [frame] counts 60 Hz ticks.
Future<void> _play(WidgetTester t, _Game game, int frame) async {
  final c = t.getCenter(find.byKey(_boundary));
  switch (game) {
    case _Game.snake:
      if (frame % 24 == 0) {
        const swipes = [Offset(60, 0), Offset(0, 60), Offset(-60, 0), Offset(0, -60)];
        final g = await t.startGesture(c);
        await g.moveBy(swipes[(frame ~/ 24) % swipes.length]);
        await g.up();
      }
    case _Game.copter:
      // Hold to climb, release to fall, in short alternating bursts.
      if (frame % 20 == 0) {
        final g = await t.startGesture(c);
        await t.pump(const Duration(milliseconds: 160));
        await g.up();
      }
    case _Game.hop:
      if (frame % 18 == 0) {
        final g = await t.startGesture(c);
        await g.moveBy(Offset(frame % 90 == 0 ? 50 : 0, -50));
        await g.up();
      }
  }
}

Future<ui.Image> _grab(WidgetTester t) async {
  final image = await t.runAsync(() async {
    final b = t.renderObject<RenderRepaintBoundary>(find.byKey(_boundary));
    return b.toImage(pixelRatio: t.view.devicePixelRatio);
  });
  return image!;
}

Future<void> _writePng(WidgetTester t, ui.Image image, String path) async {
  await t.runAsync(() async {
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(data!.buffer.asUint8List());
  });
}

/// Store screenshot: LCD-coloured canvas, caption, framed capture.
Future<ui.Image> _framed(
  WidgetTester t,
  ui.Image shot,
  String caption,
) async {
  const w = 1290.0, h = 2796.0, margin = 100.0;
  final palette = LcdPalette.active;
  return (await t.runAsync(() async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(const Rect.fromLTWH(0, 0, w, h), Paint()..color = palette.lcd);

    final text = TextPainter(
      text: TextSpan(
        text: caption.toUpperCase(),
        style: LcdText.body(palette.ink).copyWith(fontSize: 92, fontWeight: FontWeight.w700),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: w - 2 * margin);
    text.paint(canvas, Offset((w - text.width) / 2, 170));

    final aspect = shot.width / shot.height;
    final destW = aspect > 1 ? w - 2 * margin : 1000.0;
    final destH = destW / aspect;
    final top = aspect > 1 ? (h - destH) / 2 + 150 : 170 + text.height + 100;
    final dest = Rect.fromLTWH((w - destW) / 2, top, destW, destH);
    final rrect = RRect.fromRectAndRadius(dest, const Radius.circular(36));
    canvas.save();
    canvas.clipRRect(rrect);
    canvas.drawImageRect(
      shot,
      Rect.fromLTWH(0, 0, shot.width.toDouble(), shot.height.toDouble()),
      dest,
      Paint()..filterQuality = FilterQuality.none,
    );
    canvas.restore();
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14
        ..color = palette.ink,
    );
    return recorder.endRecording().toImage(w.toInt(), h.toInt());
  }))!;
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  testWidgets('store screenshots', (t) async {
    await t.runAsync(loadLcdFont);

    Future<void> shoot(
      String name,
      String caption, {
      _Game? game,
      int ticks = 0,
    }) async {
      _view(t, 430, 932, 3);
      await _pumpApp(t);
      if (game != null) {
        await _startRun(
          t,
          game,
          setView: (landscape) =>
              landscape ? _view(t, 932, 430, 3) : _view(t, 430, 932, 3),
        );
        for (var i = 0; i < ticks; i++) {
          await _play(t, game, i);
          await t.pump(const Duration(milliseconds: 16));
        }
      }
      final shot = await _grab(t);
      final framed = await _framed(t, shot, caption);
      await _writePng(t, framed, '$_out/screenshots/$name.png');
    }

    await shoot('1-launcher', 'Four classic games. One tiny app.');
    await shoot('2-snake', 'Easy to learn. Hard to put down.', game: _Game.snake, ticks: 120);
    await shoot('3-copter', 'Fly as far as you can.', game: _Game.copter, ticks: 150);
    await shoot('4-hop', 'Cross the road. Again.', game: _Game.hop, ticks: 90);
    await shoot('5-offline', 'No ads. No sign-up. Offline.');
  }, skip: _what == 'clips');

  for (final game in _Game.values) {
    testWidgets('clip frames: ${game.title}', (t) async {
      await t.runAsync(loadLcdFont);
      const seconds = 10, fps = 30;
      _view(t, 432, 768, 2.5);
      await _pumpApp(t);
      await _startRun(
        t,
        game,
        setView: (landscape) =>
            landscape ? _view(t, 768, 432, 2.5) : _view(t, 432, 768, 2.5),
      );
      for (var i = 0; i < seconds * fps; i++) {
        // Two game ticks per captured frame (60 Hz game, 30 fps clip).
        for (var k = 0; k < 2; k++) {
          await _play(t, game, i * 2 + k);
          await t.pump(const Duration(microseconds: 16667));
        }
        final shot = await _grab(t);
        final n = (i + 1).toString().padLeft(4, '0');
        await _writePng(t, shot, '$_out/clips/${game.name}/frame_$n.png');
      }
    }, skip: _what == 'shots');
  }
}
