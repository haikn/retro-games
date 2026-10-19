import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lcd_kit/lcd_kit.dart';

/// A tile on the launcher: a playable [module], or a game still to come.
class LauncherEntry {
  const LauncherEntry({required this.title, required this.icon, this.module});

  LauncherEntry.of(GameModule this.module)
    : title = module.title,
      icon = module.icon;

  final String title;
  final List<String> icon;
  final GameModule? module;
}

/// Portrait launcher (design canvas board 1): header `Games` + counter, 2×2
/// tiles with icon and name, inverted selection, `Select` soft key. Tapping a
/// tile selects and opens it.
class LauncherScreen extends StatefulWidget {
  const LauncherScreen({
    super.key,
    required this.entries,
    required this.palette,
    required this.onOpen,
  });

  final List<LauncherEntry> entries;
  final LcdPalette palette;
  final void Function(GameModule module) onOpen;

  @override
  State<LauncherScreen> createState() => _LauncherScreenState();
}

class _LauncherScreenState extends State<LauncherScreen> {
  int _selected = 0;
  String? _notice;
  Timer? _noticeTimer;

  @override
  void dispose() {
    _noticeTimer?.cancel();
    super.dispose();
  }

  void _activate(int i) {
    setState(() => _selected = i);
    final module = widget.entries[i].module;
    if (module != null) {
      widget.onOpen(module);
      return;
    }
    _noticeTimer?.cancel();
    setState(() => _notice = LcdStrings.of(context).comingSoon);
    _noticeTimer = Timer(
      const Duration(seconds: 2),
      () => mounted ? setState(() => _notice = null) : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.palette;
    final entries = widget.entries;
    return Material(
      color: p.bezel,
      child: SafeArea(
        child: LcdViewport(
          size: lcdPortrait,
          child: Stack(
            children: [
              Positioned.fill(child: LcdBackground(palette: p)),
              LcdHeader(
                palette: p,
                title: LcdStrings.of(context).games,
                trailing: '${_selected + 1}/${entries.length}',
              ),
              for (var i = 0; i < entries.length && i < 4; i++)
                Positioned(
                  left: i.isEven ? 5 : 205,
                  top: i < 2 ? 60 : 405,
                  width: 190,
                  height: 325,
                  child: _Tile(
                    entry: entries[i],
                    palette: p,
                    selected: i == _selected,
                    onTapDown: () => setState(() => _selected = i),
                    onTap: () => _activate(i),
                  ),
                ),
              if (_notice != null)
                LcdDialog(
                  palette: p,
                  // 'Coming soon' is 320 px: the box needs 340 inside.
                  rect: const Rect.fromLTWH(25, 335, 350, 75),
                  lines: [Text(_notice!, style: LcdText.body(p.ink))],
                ),
              SoftKey(
                label: LcdStrings.of(context).select,
                palette: p,
                onTap: () => _activate(_selected),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.entry,
    required this.palette,
    required this.selected,
    required this.onTapDown,
    required this.onTap,
  });

  final LauncherEntry entry;
  final LcdPalette palette;
  final bool selected;
  final VoidCallback onTapDown;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? palette.lcd : palette.ink;
    final bg = selected ? palette.ink : palette.lcd;
    return Semantics(
      button: true,
      selected: selected,
      label: entry.title,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => onTapDown(),
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: bg,
            border: Border.all(color: palette.ink, width: lcdPixel),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CustomPaint(
                size: const Size(120, 120),
                painter: _IconPainter(Sprite1.parse(entry.icon), fg),
              ),
              const SizedBox(height: 25),
              // Inner width 180 = six Silkscreen letters exactly.
              Text(
                entry.title,
                style: LcdText.body(fg),
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.visible,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A 12×12 icon drawn at 2 LCD px (10 virtual px) per icon pixel.
class _IconPainter extends CustomPainter {
  _IconPainter(this.icon, this.color);

  final Sprite1 icon;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / icon.width;
    final paint = Paint()
      ..color = color
      ..isAntiAlias = false;
    for (var y = 0; y < icon.height; y++) {
      for (var x = 0; x < icon.width; x++) {
        if (icon.at(x, y)) {
          canvas.drawRect(Rect.fromLTWH(x * cell, y * cell, cell, cell), paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(_IconPainter old) =>
      old.color != color || old.icon != icon;
}
