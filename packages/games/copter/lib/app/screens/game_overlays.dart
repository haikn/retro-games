import 'package:flutter/material.dart';

import '../app_flow.dart';

import 'package:lcd_kit/lcd_kit.dart';

/// Over the frozen world before the first press: `Hold to fly` + `Menu`.
class ReadyOverlay extends StatelessWidget {
  const ReadyOverlay({super.key, required this.flow});

  final AppFlow flow;

  @override
  Widget build(BuildContext context) {
    final p = flow.game.palette;
    return Stack(
      children: [
        LcdDialog(
          palette: p,
          rect: const Rect.fromLTWH(225, 165, 350, 75),
          lines: [
            Blink(child: Text('Hold to fly', style: LcdText.body(p.ink))),
          ],
        ),
        SoftKey(label: 'Menu', palette: p, plate: true, onTap: flow.openMenu),
      ],
    );
  }
}

/// After a crash: result dialog over the frozen frame, `Menu` soft key.
/// Taps elsewhere reach the game, which restarts on a valid new press.
class GameOverOverlay extends StatelessWidget {
  const GameOverOverlay({super.key, required this.flow});

  final AppFlow flow;

  @override
  Widget build(BuildContext context) {
    final p = flow.game.palette;
    final game = flow.game;
    final body = LcdText.body(p.ink);
    return Stack(
      children: [
        LcdDialog(
          palette: p,
          rect: const Rect.fromLTWH(175, 85, 450, 220),
          lines: [
            Text(
              'Game over!',
              style: body.copyWith(fontWeight: FontWeight.w700),
            ),
            Text('Dist ${pad5(game.distance)}', style: body),
            if (game.lastRunNewBest)
              Blink(child: Text('New best!', style: body))
            else
              Text('Best ${pad5(game.best)}', style: body),
            Text('Tap to play', style: body),
          ],
        ),
        SoftKey(label: 'Menu', palette: p, plate: true, onTap: flow.openMenu),
      ],
    );
  }
}
