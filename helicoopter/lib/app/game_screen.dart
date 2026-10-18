import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../game/helicopter_game.dart';

/// Full-screen game: the bezel fills the whole display, and the game (with
/// its own letterboxing) sits inside the safe area so nothing is clipped by a
/// notch or rounded corner. A [Listener] counts pointers for flight input.
class GameScreen extends StatelessWidget {
  const GameScreen({super.key, required this.game});

  final HelicopterGame game;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: game.palette.bezel,
      child: SafeArea(
        child: Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (_) => game.pointerDown(),
          onPointerUp: (_) => game.pointerUp(),
          onPointerCancel: (_) => game.pointerUp(),
          child: GameWidget(game: game),
        ),
      ),
    );
  }
}
