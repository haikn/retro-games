import 'dart:math';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../game/helicopter_game.dart';
import 'app_flow.dart';
import 'screens/game_overlays.dart';
import 'screens/info_screens.dart';
import 'screens/menu_screens.dart';
import 'screens/title_screen.dart';

import 'package:lcd_kit/lcd_kit.dart';

/// Full-screen host. The bezel fills the display; inside the safe area the
/// game (with its own letterboxing) sits under the current screen, laid out in
/// the same 800×400 virtual space. A [Listener] counts pointers for flight.
///
/// Full-screen menus block all touches (including on the bezel) from reaching
/// the game; in-game overlays only block their soft key.
class GameScreen extends StatefulWidget {
  const GameScreen({super.key, required this.flow});

  final AppFlow flow;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with WidgetsBindingObserver {
  AppFlow get _flow => widget.flow;
  HelicopterGame get _game => widget.flow.game;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _flow.appBackgrounded();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _flow.back();
      },
      child: Material(
        color: _game.palette.bezel,
        child: SafeArea(
          child: Stack(
            fit: StackFit.expand,
            children: [
              LayoutBuilder(
                builder: (context, box) => Listener(
                  behavior: HitTestBehavior.opaque,
                  onPointerDown: (e) =>
                      _game.pointerDown(_virtualY(e.localPosition.dy, box)),
                  onPointerUp: (_) => _game.pointerUp(),
                  onPointerCancel: (_) => _game.pointerUp(),
                  child: GameWidget(game: _game),
                ),
              ),
              ListenableBuilder(
                listenable: Listenable.merge([
                  _flow,
                  _game.phase,
                  _game.gameOverVisible,
                ]),
                builder: (context, _) => _overlay(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Widget y → virtual y of the 800×400 screen, letterboxed and centred
  /// in [box] like the game's viewport.
  static double _virtualY(double y, BoxConstraints box) {
    final scale = min(box.maxWidth / 800, box.maxHeight / 400);
    return (y - (box.maxHeight - 400 * scale) / 2) / scale;
  }

  Widget _overlay() {
    final flow = _flow;
    final fullScreen = switch (flow.screen) {
      AppScreen.title => TitleScreen(palette: _game.palette),
      AppScreen.menu => MainMenuScreen(flow: flow),
      AppScreen.topScore => TopScoreScreen(flow: flow),
      AppScreen.instructions => InstructionsScreen(flow: flow),
      AppScreen.game when _game.phase.value == GamePhase.paused => PausedScreen(
        flow: flow,
      ),
      AppScreen.game => null,
    };
    if (fullScreen != null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: flow.screen == AppScreen.title ? flow.start : null,
            child: ColoredBox(color: _game.palette.bezel),
          ),
          LcdViewport(
            child: flow.screen == AppScreen.title
                ? GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: flow.start,
                    // Open-source licences (spec: Store & Compliance).
                    onLongPress: () => showLicensePage(
                      context: context,
                      applicationName: 'Cave Copter',
                    ),
                    child: fullScreen,
                  )
                : fullScreen,
          ),
        ],
      );
    }
    final inGame = switch (_game.phase.value) {
      GamePhase.ready => ReadyOverlay(flow: flow),
      GamePhase.crashed when _game.gameOverVisible.value => GameOverOverlay(
        flow: flow,
      ),
      _ => null,
    };
    if (inGame == null) return const SizedBox.shrink();
    // Pass-through except for widgets that hit-test themselves (soft keys).
    return LcdViewport(child: inGame);
  }
}
