import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../audio_service.dart';
import '../game_module.dart';
import '../lcd_buffer.dart';
import '../lcd_painter.dart';
import '../lcd_text.dart';
import '../lcd_widgets.dart';
import '../leaderboard_service.dart';
import '../palette.dart';
import '../strings.dart';
import 'arcade_game.dart';
import 'input.dart';

enum ArcadePhase { menu, ready, playing, paused, over, topScore, instructions }

/// The shared screen flow of the grid games (collection spec, Shared UX):
/// menu → ready → playing ⇄ paused → over → (new press) playing; top score
/// and instructions; Android back routing; pause when backgrounded; best
/// score, leaderboard submission and sounds.
class ArcadeGameView extends StatefulWidget {
  const ArcadeGameView({
    super.key,
    required this.host,
    required this.spec,
    this.palette = LcdPalette.active,
    this.player,
    this.seedSource,
  });

  final GameHost host;
  final ArcadeSpec spec;
  final LcdPalette palette;

  /// Overrides the sound backend (tests).
  final SoundPlayer? player;

  /// Overrides run seeds (tests).
  final int Function()? seedSource;

  @override
  State<ArcadeGameView> createState() => ArcadeGameViewState();
}

@visibleForTesting
class ArcadeGameViewState extends State<ArcadeGameView>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  static const _fixedDt = 1 / 60;
  static const restartTicks = 36; // 600 ms
  static const gameOverTicks = 40;

  late final ArcadeGame game = widget.spec.create();
  late final AudioService _audio;
  late final Ticker _ticker;
  late final LcdBuffer _buffer;
  late final LcdPainter _painter;
  final _frame = ValueNotifier(0);
  final _random = math.Random();

  ArcadePhase _phase = ArcadePhase.menu;
  ArcadePhase get phase => _phase;

  Duration _last = Duration.zero;
  double _accumulator = 0;
  int crashTicks = 0;
  bool newBest = false;
  bool _started = false;
  late int level;
  String? _notice;
  Timer? _noticeTimer;

  Size get _size => widget.spec.orientation == GameOrientation.portrait
      ? lcdPortrait
      : lcdLandscape;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final host = widget.host;
    level = host.store.intSetting('level', widget.spec.defaultLevel);
    _audio = AudioService(
      widget.player ?? FlameSoundPlayer.forPackage(widget.spec.package),
      files: widget.spec.sounds,
      muted: !host.sound.on,
    );
    unawaited(_audio.load());
    _buffer = LcdBuffer(
      width: (_size.width / lcdPixel).round(),
      height: (_size.height / lcdPixel).round(),
    );
    _painter = LcdPainter(
      palette: widget.palette,
      cellSize: lcdPixel,
      cells: _buffer.width * _buffer.height,
    );
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker.dispose();
    _noticeTimer?.cancel();
    unawaited(_audio.stopLoop());
    _frame.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && _phase == ArcadePhase.playing) {
      _go(ArcadePhase.paused, click: false);
    }
  }

  // ---- loop ---------------------------------------------------------------

  void _onTick(Duration elapsed) {
    final dt = ((elapsed - _last).inMicroseconds / 1e6).clamp(0.0, 0.1);
    _last = elapsed;
    advance(dt);
  }

  /// Advances the run by [dt] seconds in fixed 60 Hz ticks (tests call this
  /// directly).
  void advance(double dt) {
    if (_phase == ArcadePhase.playing || _phase == ArcadePhase.over) {
      _accumulator += dt;
      var steps = 0;
      while (_accumulator >= _fixedDt - 1e-9 && steps < 6) {
        _accumulator -= _fixedDt;
        steps++;
        if (_phase == ArcadePhase.playing) {
          game.tick();
          _playSounds();
          if (game.over) _onOver();
        } else {
          crashTicks++;
          if (crashTicks == gameOverTicks) {
            if (newBest) unawaited(_audio.newBest());
            setState(() {}); // show the game-over dialog
          }
        }
      }
      if (steps == 6) _accumulator = 0;
    }
    _compose(dt);
  }

  void _playSounds() {
    for (final s in game.takeSounds()) {
      unawaited(_audio.play(s));
    }
  }

  void _compose(double dt) {
    if (!_started) return;
    _buffer.beginFrame(dt);
    game.draw(_buffer);
    _buffer.inverted = inverted;
    _buffer.endFrame();
    _frame.value++;
  }

  /// Crash flash: 3 inversions over the first 25 ticks of [ArcadePhase.over].
  bool get inverted =>
      _phase == ArcadePhase.over &&
      (crashTicks < 5 ||
          (crashTicks >= 10 && crashTicks < 15) ||
          (crashTicks >= 20 && crashTicks < 25));

  void _onOver() {
    crashTicks = 0;
    _accumulator = 0;
    _phase = ArcadePhase.over;
    final score = game.score;
    final host = widget.host;
    newBest = score > host.store.best;
    if (newBest) {
      unawaited(host.store.recordBest(score));
      unawaited(host.leaderboard.submitBest(score));
    }
    setState(() {});
  }

  // ---- navigation ---------------------------------------------------------

  void _go(ArcadePhase next, {bool click = true}) {
    if (click) unawaited(_audio.click());
    setState(() => _phase = next);
  }

  void newGame() {
    game.start(
      level: widget.spec.levels == null ? 1 : level,
      seed: widget.seedSource?.call() ?? _random.nextInt(1 << 32),
    );
    _started = true;
    _accumulator = 0;
    game.takeSounds();
    _compose(0);
    _go(ArcadePhase.ready);
  }

  void _restart() {
    newGame();
    setState(() => _phase = ArcadePhase.playing);
  }

  void cycleLevel() {
    final levels = widget.spec.levels!;
    level = level % levels + 1;
    unawaited(widget.host.store.setIntSetting('level', level));
    _go(_phase);
  }

  void toggleSound() {
    final on = !widget.host.sound.on;
    unawaited(widget.host.sound.set(on));
    unawaited(_audio.setMuted(!on));
    if (on) unawaited(_audio.click());
    setState(() {});
  }

  Future<void> showOnlineScores() async {
    unawaited(_audio.click());
    final t = LcdStrings.of(context);
    final message = switch (await widget.host.leaderboard.show()) {
      LeaderboardResult.shown => null,
      LeaderboardResult.signInFailed => t.signInFailed,
      LeaderboardResult.showFailed => t.tryAgainLater,
      LeaderboardResult.unavailable => t.notAvailable,
    };
    if (message == null || !mounted) return;
    _noticeTimer?.cancel();
    setState(() => _notice = message);
    _noticeTimer = Timer(
      const Duration(seconds: 2),
      () => mounted ? setState(() => _notice = null) : null,
    );
  }

  void exitToLauncher() {
    unawaited(_audio.click());
    unawaited(_audio.stopLoop());
    widget.host.exitToLauncher();
  }

  /// Android back (spec: Shared UX).
  void back() {
    switch (_phase) {
      case ArcadePhase.menu:
        exitToLauncher();
      case ArcadePhase.playing:
        _go(ArcadePhase.paused, click: false);
      case ArcadePhase.paused:
        _go(ArcadePhase.ready);
      case ArcadePhase.ready:
      case ArcadePhase.over:
      case ArcadePhase.topScore:
      case ArcadePhase.instructions:
        _go(ArcadePhase.menu);
    }
  }

  /// Height of the HUD strip, which pauses when tapped.
  static const hudHeight = 45.0;

  /// True from a HUD press until its gesture ends, so the rest of that
  /// gesture is not sent to the game.
  bool _pauseFromHud = false;

  void onInput(GameInput input) {
    if (input is ReleaseInput && _pauseFromHud) {
      _pauseFromHud = false;
      return;
    }
    switch (_phase) {
      case ArcadePhase.ready:
        if (input is PressInput) setState(() => _phase = ArcadePhase.playing);
        game.input(input);
      case ArcadePhase.playing:
        // The HUD strip (top 45 px: text and rule) is the pause key.
        if (input is PressInput && input.position.dy < hudHeight) {
          _pauseFromHud = true;
          _go(ArcadePhase.paused);
          return;
        }
        if (_pauseFromHud) return; // rest of the pausing gesture
        game.input(input);
      case ArcadePhase.over:
        if (input is PressInput && crashTicks >= restartTicks) _restart();
      default:
        break;
    }
  }

  // ---- UI -----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final p = widget.palette;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) back();
      },
      child: Material(
        color: p.bezel,
        child: SafeArea(
          child: LcdViewport(
            size: _size,
            child: Stack(fit: StackFit.expand, children: _layers(p)),
          ),
        ),
      ),
    );
  }

  bool get _gameVisible => switch (_phase) {
    ArcadePhase.ready || ArcadePhase.playing || ArcadePhase.over => true,
    _ => false,
  };

  List<Widget> _layers(LcdPalette p) {
    final spec = widget.spec;
    final t = LcdStrings.of(context);
    return [
      if (_gameVisible) ...[
        ArcadeGestureLayer(
          onInput: onInput,
          child: CustomPaint(
            size: _size,
            painter: _BufferPainter(_painter, _buffer, _frame),
          ),
        ),
        IgnorePointer(
          child: ValueListenableBuilder<int>(
            valueListenable: _frame,
            builder: (context, _, _) => Stack(children: _hud(p)),
          ),
        ),
      ],
      if (spec.pauseKey != null &&
          (_phase == ArcadePhase.ready || _phase == ArcadePhase.playing))
        _pauseButton(p, spec.pauseKey!),
      if (_phase == ArcadePhase.ready) ...[
        _dialog(p, [
          for (final line in spec.startHint)
            Blink(child: Text(line, style: LcdText.body(p.ink))),
        ]),
        SoftKey(label: t.menu, palette: p, plate: true, onTap: _toMenu),
      ],
      if (_phase == ArcadePhase.over && crashTicks >= gameOverTicks) ...[
        _dialog(p, [
          Text(
            t.gameOver,
            style: LcdText.body(p.ink).copyWith(fontWeight: FontWeight.w700),
          ),
          Text(
            LcdStrings.fill(t.score, pad5(game.score)),
            style: LcdText.body(p.ink),
          ),
          if (newBest)
            Blink(child: Text(t.newBest, style: LcdText.body(p.ink)))
          else
            Text(
              LcdStrings.fill(t.best, pad5(widget.host.store.best)),
              style: LcdText.body(p.ink),
            ),
          Text(t.tapToPlay, style: LcdText.body(p.ink)),
        ]),
        SoftKey(label: t.menu, palette: p, plate: true, onTap: _toMenu),
      ],
      if (_phase == ArcadePhase.menu) _menu(p),
      if (_phase == ArcadePhase.paused) _paused(p),
      if (_phase == ArcadePhase.topScore) _topScore(p),
      if (_phase == ArcadePhase.instructions) _instructions(p),
    ];
  }

  void _toMenu() => _go(ArcadePhase.menu);

  /// `II` in a 1-LCD-px box.
  Widget _pauseButton(LcdPalette p, Rect rect) {
    final ink = inverted ? p.lcd : p.ink;
    return Positioned.fromRect(
      key: const ValueKey('pause-key'),
      rect: rect,
      child: Semantics(
        button: true,
        label: LcdStrings.of(context).pause,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            if (_phase == ArcadePhase.playing) {
              _go(ArcadePhase.paused);
            }
          },
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: ink, width: lcdPixel),
            ),
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 10,
                    height: 25,
                    child: ColoredBox(color: ink),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 10,
                    height: 25,
                    child: ColoredBox(color: ink),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _hud(LcdPalette p) {
    final t = LcdStrings.of(context);
    final ink = inverted ? p.lcd : p.ink;
    final style = LcdText.body(ink);
    final best = math.max(widget.host.store.best, game.score);
    // `00000` + `HI 00000` is 365 px in Silkscreen: portrait needs 10-px
    // margins to fit its 400-px width.
    final margin = _size.width < 500 ? 10.0 : 25.0;
    return [
      Positioned(
        left: margin,
        right: margin,
        top: 0,
        height: 40,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(pad5(game.score), style: style),
            Text(LcdStrings.fill(t.hi, pad5(best)), style: style),
          ],
        ),
      ),
      for (final t in game.texts)
        Positioned(
          left: t.alignRight ? null : t.position.dx,
          right: t.alignRight ? _size.width - t.position.dx : null,
          top: t.position.dy,
          child: Text(t.text, style: style),
        ),
    ];
  }

  Widget _dialog(LcdPalette p, List<Widget> lines) {
    final w = math.min(450.0, _size.width - 50);
    final h = 50.0 * lines.length + 25;
    return LcdDialog(
      palette: p,
      rect: Rect.fromLTWH(
        ((_size.width - w) / 2 / lcdPixel).round() * lcdPixel,
        ((_size.height - h) / 2 / lcdPixel).round() * lcdPixel,
        w,
        h,
      ),
      lines: lines,
    );
  }

  Widget _blocking(Widget child) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: () {},
    child: child,
  );

  String get _soundLabel => widget.host.sound.on ? 'Sound: On' : 'Sound: Off';

  Widget _menu(LcdPalette p) {
    final spec = widget.spec;
    final t = LcdStrings.of(context);
    return _blocking(
      LcdMenuScreen(
        key: const ValueKey('menu'),
        palette: p,
        title: spec.title,
        boldTitle: true,
        selectLabel: t.select,
        items: [
          LcdMenuItem(t.newGame, newGame),
          if (spec.levels != null)
            LcdMenuItem(LcdStrings.fill(t.level, level), cycleLevel),
          LcdMenuItem(t.topScore, () => _go(ArcadePhase.topScore)),
          LcdMenuItem(_soundLabel, toggleSound),
          // `Instructions` (330 px) does not fit a portrait menu row.
          LcdMenuItem(t.howToPlay, () => _go(ArcadePhase.instructions)),
          LcdMenuItem(t.allGames, exitToLauncher),
        ],
      ),
    );
  }

  Widget _paused(LcdPalette p) {
    final t = LcdStrings.of(context);
    return _blocking(
      LcdMenuScreen(
        key: const ValueKey('paused'),
        palette: p,
        title: t.paused,
        boldTitle: true,
        selectLabel: t.select,
        trailing: pad5(game.score),
        items: [
          LcdMenuItem(t.continueRun, () => _go(ArcadePhase.ready)),
          LcdMenuItem(t.newGame, newGame),
          LcdMenuItem(_soundLabel, toggleSound),
          LcdMenuItem(t.mainMenu, _toMenu),
        ],
      ),
    );
  }

  Widget _topScore(LcdPalette p) {
    final t = LcdStrings.of(context);
    final w = _size.width;
    final numberTop = (_size.height * 0.2 / lcdPixel).round() * lcdPixel;
    // `Online scores` is 360 px wide in Silkscreen.
    final buttonWidth = math.min(450.0, w - 30);
    return _blocking(
      Stack(
        children: [
          Positioned.fill(child: LcdBackground(palette: p)),
          LcdHeader(palette: p, title: t.topScoreTitle),
          Positioned(
            left: 0,
            right: 0,
            top: numberTop,
            height: 120,
            child: Center(
              child: Text(
                pad5(widget.host.store.best),
                style: LcdText.big(p.ink),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: numberTop + 120,
            height: 50,
            child: Center(
              child: Text(_notice ?? t.onThisPhone, style: LcdText.body(p.ink)),
            ),
          ),
          Positioned(
            left: (w - buttonWidth) / 2,
            top: numberTop + 185,
            width: buttonWidth,
            height: 60,
            child: Semantics(
              button: true,
              label: t.onlineScores,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: showOnlineScores,
                child: ColoredBox(
                  color: p.ink,
                  child: Center(
                    child: Text(t.onlineScores, style: LcdText.body(p.lcd)),
                  ),
                ),
              ),
            ),
          ),
          SoftKey(label: t.back, palette: p, onTap: _toMenu),
        ],
      ),
    );
  }

  Widget _instructions(LcdPalette p) => _blocking(
    _InstructionsScreen(
      palette: p,
      paragraphs: widget.spec.instructions,
      onBack: _toMenu,
    ),
  );
}

class _InstructionsScreen extends StatefulWidget {
  const _InstructionsScreen({
    required this.palette,
    required this.paragraphs,
    required this.onBack,
  });

  final LcdPalette palette;
  final List<String> paragraphs;
  final VoidCallback onBack;

  @override
  State<_InstructionsScreen> createState() => _InstructionsScreenState();
}

class _InstructionsScreenState extends State<_InstructionsScreen> {
  final _scroll = ScrollController();
  double _fraction = 0;
  bool _overflows = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      final max = _scroll.position.maxScrollExtent;
      setState(() => _fraction = max > 0 ? _scroll.offset / max : 0);
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.palette;
    final size = LcdScreen.sizeOf(context);
    final style = LcdText.body(p.ink).copyWith(height: 45 / 40);
    final height = size.height - 130;
    return Stack(
      children: [
        Positioned.fill(child: LcdBackground(palette: p)),
        LcdHeader(
          palette: p,
          title: LcdStrings.of(context).howToPlay,
          bold: true,
        ),
        Positioned(
          left: 25,
          top: 60,
          width: size.width - 75,
          height: height,
          child: NotificationListener<ScrollMetricsNotification>(
            onNotification: (n) {
              final overflows = n.metrics.maxScrollExtent > 0;
              if (overflows != _overflows) {
                setState(() => _overflows = overflows);
              }
              return false;
            },
            child: ScrollConfiguration(
              behavior: const ScrollBehavior().copyWith(scrollbars: false),
              child: ListView(
                controller: _scroll,
                padding: EdgeInsets.zero,
                children: [
                  for (final text in widget.paragraphs)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 45),
                      child: Text(text, style: style),
                    ),
                ],
              ),
            ),
          ),
        ),
        if (_overflows)
          LcdScrollbar(
            palette: p,
            top: 60,
            height: height,
            fraction: _fraction,
          ),
        SoftKey(
          label: LcdStrings.of(context).back,
          palette: p,
          onTap: widget.onBack,
        ),
      ],
    );
  }
}

class _BufferPainter extends CustomPainter {
  _BufferPainter(this.painter, this.buffer, Listenable repaint)
    : super(repaint: repaint);

  final LcdPainter painter;
  final LcdBuffer buffer;

  @override
  void paint(Canvas canvas, Size size) => painter.paint(canvas, buffer);

  @override
  bool shouldRepaint(_BufferPainter old) => old.buffer != buffer;
}
