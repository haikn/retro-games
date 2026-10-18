import 'package:flutter/material.dart';

import '../app_flow.dart';

import 'package:lcd_kit/lcd_kit.dart';

String _soundLabel(AppFlow flow) => flow.soundOn ? 'Sound: On' : 'Sound: Off';

/// Main menu: New game, Top score, Sound, Instructions.
class MainMenuScreen extends StatelessWidget {
  const MainMenuScreen({super.key, required this.flow});

  final AppFlow flow;

  @override
  Widget build(BuildContext context) {
    return LcdMenuScreen(
      palette: flow.game.palette,
      title: 'Copter',
      items: [
        LcdMenuItem('New game', flow.newGame),
        LcdMenuItem('Top score', flow.openTopScore),
        LcdMenuItem(_soundLabel(flow), flow.toggleSound),
        LcdMenuItem('Instructions', flow.openInstructions),
        if (flow.onExit != null) LcdMenuItem('All games', flow.exitToGames),
      ],
    );
  }
}

/// Pause menu: Continue, New game, Sound, Main menu; header shows the
/// paused run's distance.
class PausedScreen extends StatelessWidget {
  const PausedScreen({super.key, required this.flow});

  final AppFlow flow;

  @override
  Widget build(BuildContext context) {
    return LcdMenuScreen(
      palette: flow.game.palette,
      title: 'Paused',
      boldTitle: true,
      trailing: pad5(flow.game.distance),
      items: [
        LcdMenuItem('Continue', flow.continueRun),
        LcdMenuItem('New game', flow.newGame),
        LcdMenuItem(_soundLabel(flow), flow.toggleSound),
        LcdMenuItem('Main menu', flow.openMenu),
      ],
    );
  }
}
