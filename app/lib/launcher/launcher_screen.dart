import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lcd_kit/lcd_kit.dart';

import '../update/update_check.dart';

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
    this.banner,
    this.update = UpdateNeed.none,
    this.onUpdate,
    this.onLater,
    this.onAdPrivacy,
  });

  final List<LauncherEntry> entries;
  final LcdPalette palette;
  final void Function(GameModule module) onOpen;

  /// Ad banner under the LCD (sizes itself; empty while no ad shows).
  final Widget? banner;

  /// An update prompt replaces the tiles: `Update` (+ `Later` when
  /// optional). A required update keeps the games locked.
  final UpdateNeed update;
  final VoidCallback? onUpdate;
  final VoidCallback? onLater;

  /// Shows the `Ads` soft key (ad privacy options), where the law needs it.
  final VoidCallback? onAdPrivacy;

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
    final banner = widget.banner;
    return Material(
      color: p.bezel,
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: LcdViewport(
                size: lcdPortrait,
                child: widget.update == UpdateNeed.none
                    ? _tiles(p)
                    : _updatePrompt(p),
              ),
            ),
            ?banner,
          ],
        ),
      ),
    );
  }

  Widget _updatePrompt(LcdPalette p) {
    final t = LcdStrings.of(context);
    final required = widget.update == UpdateNeed.required;
    return LcdMenuScreen(
      key: ValueKey(widget.update),
      palette: p,
      title: required ? t.updateNeeded : t.newVersion,
      boldTitle: true,
      trailing: '',
      selectLabel: t.select,
      items: [
        LcdMenuItem(t.update, () => widget.onUpdate?.call()),
        if (!required) LcdMenuItem(t.later, () => widget.onLater?.call()),
      ],
    );
  }

  Widget _tiles(LcdPalette p) {
    final entries = widget.entries;
    final t = LcdStrings.of(context);
    final onAdPrivacy = widget.onAdPrivacy;
    return Stack(
      children: [
        Positioned.fill(child: LcdBackground(palette: p)),
        LcdHeader(
          palette: p,
          title: t.games,
          trailing: '${_selected + 1}/${entries.length}',
        ),
        for (var i = 0; i < entries.length && i < 4; i++)
          Positioned(
            // 10-px gaps between tiles both ways (tiles at y 60–395 and
            // 405–740, above the soft key at 745).
            left: i.isEven ? 5 : 205,
            top: i < 2 ? 60 : 405,
            width: 190,
            height: 335,
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
        if (onAdPrivacy == null)
          SoftKey(
            label: t.select,
            palette: p,
            onTap: () => _activate(_selected),
          )
        else ...[
          // Two soft keys, as on the phones: `Ads` left, `Select`
          // right.
          _key(const Rect.fromLTWH(0, 745, 150, 55), t.ads, p, onAdPrivacy),
          _key(
            const Rect.fromLTWH(150, 745, 250, 55),
            t.select,
            p,
            () => _activate(_selected),
          ),
        ],
      ],
    );
  }

  static Widget _key(Rect r, String label, LcdPalette p, VoidCallback onTap) =>
      Positioned.fromRect(
        rect: r,
        child: Semantics(
          button: true,
          label: label,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: Center(child: Text(label, style: LcdText.body(p.ink))),
          ),
        ),
      );
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
