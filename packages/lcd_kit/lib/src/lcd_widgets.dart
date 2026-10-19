import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'lcd_buffer.dart';
import 'lcd_painter.dart';
import 'lcd_text.dart';
import 'palette.dart';

/// Landscape virtual screen: 160×80 LCD pixels of 5 px.
const lcdLandscape = Size(800, 400);

/// Portrait virtual screen: 80×160 LCD pixels of 5 px.
const lcdPortrait = Size(400, 800);

/// Size of one LCD pixel in virtual px.
const lcdPixel = 5.0;

/// The virtual screen size of the enclosing [LcdViewport].
class LcdScreen extends InheritedWidget {
  const LcdScreen({super.key, required this.size, required super.child});

  final Size size;

  /// Landscape when no viewport encloses [context].
  static Size sizeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<LcdScreen>()?.size ??
      lcdLandscape;

  @override
  bool updateShouldNotify(LcdScreen old) => old.size != size;
}

/// Lays out [child] in [size] virtual px, scaled and letterboxed exactly like
/// the games' fixed-resolution cameras, so widgets share their LCD grid.
class LcdViewport extends StatelessWidget {
  const LcdViewport({super.key, required this.child, this.size = lcdLandscape});

  final Widget child;
  final Size size;

  @override
  Widget build(BuildContext context) {
    // Tight constraints make FittedBox scale up as well as down, matching the
    // Flame camera; outside the scaled panel it does not hit-test.
    return SizedBox.expand(
      child: FittedBox(
        child: SizedBox.fromSize(
          size: size,
          child: LcdScreen(size: size, child: child),
        ),
      ),
    );
  }
}

/// Paints an [LcdBuffer] that [compose] redraws every frame; [compose] gets
/// the number of 60 Hz ticks since the widget appeared.
class LcdSceneView extends StatefulWidget {
  const LcdSceneView({super.key, required this.palette, required this.compose});

  final LcdPalette palette;
  final void Function(LcdBuffer buffer, int tick) compose;

  @override
  State<LcdSceneView> createState() => _LcdSceneViewState();
}

class _LcdSceneViewState extends State<LcdSceneView>
    with SingleTickerProviderStateMixin {
  LcdBuffer? _buffer;
  late LcdPainter _painter;
  late final Ticker _ticker;
  final _frame = ValueNotifier(0);
  Duration _last = Duration.zero;
  Size _size = lcdLandscape;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final size = LcdScreen.sizeOf(context);
    if (_buffer != null && size == _size) return;
    _size = size;
    final b = LcdBuffer(
      width: (size.width / lcdPixel).round(),
      height: (size.height / lcdPixel).round(),
    );
    _buffer = b;
    _painter = LcdPainter(
      palette: widget.palette,
      cellSize: lcdPixel,
      cells: b.width * b.height,
    );
    _compose(0, 0);
  }

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) {
      final dt = (elapsed - _last).inMicroseconds / 1e6;
      _last = elapsed;
      _compose(elapsed.inMicroseconds * 60 ~/ 1000000, dt);
      _frame.value++;
    })..start();
  }

  void _compose(int tick, double dt) {
    final b = _buffer;
    if (b == null) return;
    b.beginFrame(dt);
    widget.compose(b, tick);
    b.endFrame();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _frame.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: _size,
      painter: _BufferPainter(_painter, _buffer!, _frame),
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

/// Plain LCD background (lcd colour + grid), for menu screens.
class LcdBackground extends StatelessWidget {
  const LcdBackground({super.key, required this.palette});

  final LcdPalette palette;

  @override
  Widget build(BuildContext context) =>
      LcdSceneView(palette: palette, compose: (_, _) {});
}

/// Shows [child] for the first half of every second (1 s blink period).
class Blink extends StatefulWidget {
  const Blink({super.key, required this.child});

  final Widget child;

  @override
  State<Blink> createState() => _BlinkState();
}

class _BlinkState extends State<Blink> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) =>
          Opacity(opacity: _controller.value < 0.5 ? 1 : 0, child: child),
      child: widget.child,
    );
  }
}

/// The centred soft key at the bottom of the screen (y 345–400). [plate]
/// draws it on an lcd-coloured block so it stays legible over the cave.
class SoftKey extends StatelessWidget {
  const SoftKey({
    super.key,
    required this.label,
    required this.palette,
    required this.onTap,
    this.plate = false,
  });

  final String label;
  final LcdPalette palette;
  final VoidCallback onTap;
  final bool plate;

  @override
  Widget build(BuildContext context) {
    final width = plate ? 200.0 : 250.0;
    final height = plate ? 50.0 : 55.0;
    return Positioned(
      left: (LcdScreen.sizeOf(context).width - width) / 2,
      top: LcdScreen.sizeOf(context).height - height,
      width: width,
      height: height,
      child: Semantics(
        button: true,
        label: label,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: ColoredBox(
            color: plate ? palette.lcd : const Color(0x00000000),
            child: Center(child: Text(label, style: LcdText.body(palette.ink))),
          ),
        ),
      ),
    );
  }
}

/// Dialog box with a 1-LCD-px ink border; lines are 50 px apart. Taps pass
/// through it to the game.
class LcdDialog extends StatelessWidget {
  const LcdDialog({
    super.key,
    required this.palette,
    required this.rect,
    required this.lines,
  });

  final LcdPalette palette;
  final Rect rect;
  final List<Widget> lines;

  @override
  Widget build(BuildContext context) {
    return Positioned.fromRect(
      rect: rect,
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: palette.lcd,
            border: Border.all(color: palette.ink, width: 5),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final line in lines)
                SizedBox(height: 50, child: Center(child: line)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Screen header: title at top-left, optional value at top-right.
class LcdHeader extends StatelessWidget {
  const LcdHeader({
    super.key,
    required this.palette,
    required this.title,
    this.trailing,
    this.bold = false,
  });

  final LcdPalette palette;
  final String title;
  final String? trailing;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final style = LcdText.body(palette.ink);
    return Positioned(
      left: LcdScreen.sizeOf(context).width < 500 ? 10 : 25,
      right: LcdScreen.sizeOf(context).width < 500 ? 10 : 25,
      top: 0,
      height: 55,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: bold ? style.copyWith(fontWeight: FontWeight.w700) : style,
          ),
          if (trailing != null) Text(trailing!, style: style),
        ],
      ),
    );
  }
}

/// Right-edge scrollbar: 1-LCD-px track, 3×12 LCD-px thumb at [fraction].
class LcdScrollbar extends StatelessWidget {
  const LcdScrollbar({
    super.key,
    required this.palette,
    required this.top,
    required this.height,
    required this.fraction,
  });

  static const thumbHeight = 60.0;

  final LcdPalette palette;
  final double top;
  final double height;
  final double fraction;

  @override
  Widget build(BuildContext context) {
    final travel = height - thumbHeight;
    final thumbTop = top + (fraction.clamp(0.0, 1.0) * travel / 5).round() * 5;
    return Positioned(
      left: LcdScreen.sizeOf(context).width - 30,
      top: top,
      width: 15,
      height: height,
      child: ExcludeSemantics(
        child: Stack(
          children: [
            Positioned(
              left: 5,
              top: 0,
              width: 5,
              height: height,
              child: ColoredBox(color: palette.ink),
            ),
            Positioned(
              left: 0,
              top: thumbTop - top,
              width: 15,
              height: thumbHeight,
              child: ColoredBox(color: palette.ink),
            ),
          ],
        ),
      ),
    );
  }
}

class LcdMenuItem {
  const LcdMenuItem(this.label, this.onActivate);

  final String label;
  final VoidCallback onActivate;
}

/// Nokia-style menu screen: header, list with inverted selection bar,
/// scrollbar and a `Select` soft key. Tapping a row selects and activates it.
class LcdMenuScreen extends StatefulWidget {
  const LcdMenuScreen({
    super.key,
    required this.palette,
    required this.title,
    required this.items,
    this.trailing,
    this.boldTitle = false,
    this.selectLabel = 'Select',
  });

  final LcdPalette palette;
  final String title;
  final List<LcdMenuItem> items;

  /// Header value; defaults to the item counter (`1/4`).
  final String? trailing;
  final bool boldTitle;

  /// Soft-key label.
  final String selectLabel;

  @override
  State<LcdMenuScreen> createState() => _LcdMenuScreenState();
}

class _LcdMenuScreenState extends State<LcdMenuScreen> {
  static const listTop = 55.0;
  final _scroll = ScrollController();
  int _selected = 0;
  double _fraction = 0;

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

  void _activate(int i) {
    setState(() => _selected = i);
    widget.items[i].onActivate();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.palette;
    final items = widget.items;
    final size = LcdScreen.sizeOf(context);
    // 11-LCD-px rows in landscape (5 fit above the soft key), 12 in portrait.
    final rowHeight = size.height < 500 ? 55.0 : 60.0;
    final available = size.height - listTop - 55; // above the soft key
    final fits = items.length * rowHeight <= available;
    final listHeight = fits
        ? items.length * rowHeight
        : (available / rowHeight).floor() * rowHeight;
    return Stack(
      children: [
        Positioned.fill(child: LcdBackground(palette: p)),
        LcdHeader(
          palette: p,
          title: widget.title,
          bold: widget.boldTitle,
          trailing: widget.trailing ?? '${_selected + 1}/${items.length}',
        ),
        Positioned(
          left: 10,
          top: listTop,
          width: size.width - 55,
          height: listHeight,
          child: ScrollConfiguration(
            behavior: const ScrollBehavior().copyWith(scrollbars: false),
            child: ListView.builder(
              controller: _scroll,
              padding: EdgeInsets.zero,
              itemExtent: rowHeight,
              physics: fits
                  ? const NeverScrollableScrollPhysics()
                  : const ClampingScrollPhysics(),
              itemCount: items.length,
              itemBuilder: (context, i) => Semantics(
                button: true,
                selected: i == _selected,
                label: items[i].label,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (_) => setState(() => _selected = i),
                  onTap: () => _activate(i),
                  child: ColoredBox(
                    color: i == _selected ? p.ink : const Color(0x00000000),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 15),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          items[i].label,
                          style: LcdText.body(i == _selected ? p.lcd : p.ink),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        // Scrollbar only when the list is longer than the screen.
        if (!fits)
          LcdScrollbar(
            palette: p,
            top: listTop,
            height: listHeight,
            fraction: _fraction,
          ),
        SoftKey(
          label: widget.selectLabel,
          palette: p,
          onTap: () => _activate(_selected),
        ),
      ],
    );
  }
}
