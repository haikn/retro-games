import 'package:flutter_test/flutter_test.dart';
import 'package:lcd_kit/lcd_kit.dart';
import 'package:lcd_kit/testing.dart';

/// Every shared string must fit the narrowest slot it appears in (portrait,
/// 400 px wide), measured with the real font. A translation (decision C6)
/// must pass this test too.
void main() {
  const t = LcdStrings.en;

  /// Slot widths in virtual px.
  const menuRow = 400 - 55 - 30.0; // list width minus row padding
  const dialogLine = 350 - 2 * 5.0; // dialog minus its border
  const launcherDialog = 350 - 2 * 5.0;
  const softKey = 250.0;
  const softKeyPlate = 200.0;
  const fullWidth = 400 - 2 * 10.0; // HUD, header, notice

  void fits(String text, double slot, {bool bold = false}) {
    final w = lcdTextWidth(text, bold: bold);
    expect(w, lessThanOrEqualTo(slot), reason: '"$text" is $w px > $slot');
  }

  testWidgets('shared strings fit their portrait slots', (tester) async {
    await tester.runAsync(loadLcdFont);
    for (final s in [
      t.newGame,
      LcdStrings.fill(t.level, 9),
      t.topScore,
      t.soundOn,
      t.soundOff,
      t.howToPlay,
      t.allGames,
      t.continueRun,
      t.mainMenu,
      t.update,
      t.later,
    ]) {
      fits(s, menuRow);
    }
    for (final s in [
      t.gameOver,
      LcdStrings.fill(t.score, '00000'),
      LcdStrings.fill(t.best, '00000'),
      t.newBest,
      t.tapToPlay,
    ]) {
      fits(s, dialogLine, bold: s == t.gameOver);
    }
    fits(t.comingSoon, launcherDialog);
    fits(t.select, softKey);
    fits(t.back, softKey);
    fits(t.menu, softKeyPlate);
    for (final s in [
      t.onThisPhone,
      t.signInFailed,
      t.tryAgainLater,
      t.notAvailable,
    ]) {
      fits(s, fullWidth);
    }
    fits(t.onlineScores, 400 - 30.0);
    // HUD: score at the left edge, best at the right edge.
    final hud =
        lcdTextWidth('00000') + lcdTextWidth(LcdStrings.fill(t.hi, '00000'));
    expect(hud + 10, lessThanOrEqualTo(fullWidth), reason: 'HUD');
    // Headers: title (bold) next to the counter or the paused score (regular).
    final paused = lcdTextWidth(t.paused, bold: true) + lcdTextWidth('00000');
    expect(paused + 15, lessThanOrEqualTo(fullWidth), reason: 'paused header');
    final games = lcdTextWidth(t.games) + lcdTextWidth('4/4');
    expect(games + 15, lessThanOrEqualTo(fullWidth), reason: 'launcher header');
    fits(t.topScoreTitle, fullWidth, bold: true);
    fits(t.howToPlay, fullWidth, bold: true);
    // Launcher update prompt: bold title alone (no counter).
    fits(t.newVersion, fullWidth, bold: true);
    fits(t.updateNeeded, fullWidth, bold: true);
    // Launcher with the ad privacy key: `Ads` left, `Select` right.
    fits(t.ads, 140);
    fits(t.select, 240);
  });
}
