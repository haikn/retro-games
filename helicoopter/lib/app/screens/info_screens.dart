import 'package:flutter/material.dart';

import '../../game/lcd/lcd_text.dart';
import '../app_flow.dart';
import '../lcd/lcd_widgets.dart';

/// Local best in large type, `Online scores` button, `Back`.
class TopScoreScreen extends StatelessWidget {
  const TopScoreScreen({super.key, required this.flow});

  final AppFlow flow;

  @override
  Widget build(BuildContext context) {
    final p = flow.game.palette;
    return Stack(
      children: [
        Positioned.fill(child: LcdBackground(palette: p)),
        LcdHeader(palette: p, title: 'Top score:'),
        Positioned(
          left: 0,
          right: 0,
          top: 80,
          height: 120,
          child: Center(
            child: Text(pad5(flow.game.best), style: LcdText.big(p.ink)),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          top: 200,
          height: 50,
          child: Center(
            child: Text('On this phone', style: LcdText.body(p.ink)),
          ),
        ),
        Positioned(
          left: 175,
          top: 265,
          width: 450,
          height: 60,
          child: Semantics(
            button: true,
            label: 'Online scores',
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: flow.showOnlineScores,
              child: ColoredBox(
                color: p.ink,
                child: Center(
                  child: Text('Online scores', style: LcdText.body(p.lcd)),
                ),
              ),
            ),
          ),
        ),
        SoftKey(label: 'Back', palette: p, onTap: flow.openMenu),
      ],
    );
  }
}

/// Scrolling instructions text with a scrollbar that follows it.
class InstructionsScreen extends StatefulWidget {
  const InstructionsScreen({super.key, required this.flow});

  static const paragraphs = [
    'Hold anywhere on the screen to fly up. Let go to drop.',
    'Steer through the cave. Do not touch the walls or the blocks.',
    'The further you fly, the narrower the cave gets.',
    'Beat your top score and post it to the online scores.',
  ];

  final AppFlow flow;

  @override
  State<InstructionsScreen> createState() => _InstructionsScreenState();
}

class _InstructionsScreenState extends State<InstructionsScreen> {
  final _scroll = ScrollController();
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

  @override
  Widget build(BuildContext context) {
    final p = widget.flow.game.palette;
    final style = LcdText.body(p.ink).copyWith(height: 45 / 40);
    return Stack(
      children: [
        Positioned.fill(child: LcdBackground(palette: p)),
        LcdHeader(palette: p, title: 'Instructions', bold: true),
        Positioned(
          left: 25,
          top: 60,
          width: 725,
          height: 270,
          child: ScrollConfiguration(
            behavior: const ScrollBehavior().copyWith(scrollbars: false),
            child: ListView(
              controller: _scroll,
              padding: EdgeInsets.zero,
              children: [
                for (final text in InstructionsScreen.paragraphs)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 45),
                    child: Text(text, style: style),
                  ),
              ],
            ),
          ),
        ),
        LcdScrollbar(palette: p, top: 60, height: 270, fraction: _fraction),
        SoftKey(label: 'Back', palette: p, onTap: widget.flow.openMenu),
      ],
    );
  }
}
