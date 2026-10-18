/// Tuning constants for one run.
///
/// Units are virtual pixels (px) of the 800×400 screen and seconds; y grows
/// downward. One LCD pixel is [lcdPixel] px, and all generated geometry is a
/// multiple of it.
class Config {
  const Config({
    this.worldWidth = 800,
    this.worldHeight = 400,
    this.lcdPixel = 5,
    this.playTop = 45,
    this.fixedDt = 1 / 60,
    this.maxFrameDt = 0.1,
    this.maxStepsPerFrame = 6,
    this.gravity = 900,
    this.thrust = 1800,
    this.maxVerticalSpeed = 360,
    this.scrollSpeed = 300,
    this.distanceUnit = 10,
    this.heliX = 160,
    this.heliWidth = 50,
    this.heliHeight = 30,
    this.hitboxInset = 5,
    this.columnWidth = 10,
    this.edgeMargin = 10,
    this.walkStep = 5,
    this.initialGap = 300,
    this.minGap = 170,
    this.rampDistancePx = 20000,
    this.obstacleWidth = 20,
    this.obstacleMinHeight = 50,
    this.obstacleMaxHeight = 90,
    this.obstacleHeightStep = 10,
    this.firstObstacleX = 800,
    this.initialObstacleSpacing = 600,
    this.minObstacleSpacing = 300,
    this.minPassableHeight = 80,
    this.climbMarginFactor = 0.5,
    this.placementRetries = 8,
  });

  final double worldWidth;
  final double worldHeight;
  final double lcdPixel;

  /// First y of the play area; above it are the HUD strip and its rule.
  final double playTop;

  final double fixedDt;
  final double maxFrameDt;
  final int maxStepsPerFrame;

  final double gravity;
  final double thrust;
  final double maxVerticalSpeed;
  final double scrollSpeed;

  /// Scrolled px per point of distance.
  final int distanceUnit;

  final double heliX;
  final double heliWidth;
  final double heliHeight;
  final double hitboxInset;

  final double columnWidth;

  /// Minimum thickness of the ceiling and floor.
  final double edgeMargin;
  final double walkStep;
  final double initialGap;
  final double minGap;

  /// Scrolled px over which the gap and obstacle spacing ramp to their minimum.
  final double rampDistancePx;

  final double obstacleWidth;
  final double obstacleMinHeight;
  final double obstacleMaxHeight;
  final double obstacleHeightStep;

  /// No obstacle starts before this world x (keeps the first screen clear).
  final double firstObstacleX;
  final double initialObstacleSpacing;
  final double minObstacleSpacing;
  final double minPassableHeight;

  /// Fraction of the theoretical climb per column the generator relies on.
  final double climbMarginFactor;
  final int placementRetries;

  double get playHeight => worldHeight - playTop;
  double get hitboxWidth => heliWidth - 2 * hitboxInset;
  double get hitboxHeight => heliHeight - 2 * hitboxInset;
  int get scrollPxPerTick => (scrollSpeed * fixedDt).round();
  double get maxVerticalPerTick => maxVerticalSpeed * fixedDt;
  double get columnTime => columnWidth / scrollSpeed;
  double get climbMargin => climbMarginFactor * maxVerticalSpeed * columnTime;
  int get obstacleColumns => (obstacleWidth / columnWidth).round();

  /// Columns kept alive: one screen plus a partial column on each side.
  int get ringCapacity => (worldWidth / columnWidth).ceil() + 2;

  /// Human-readable descriptions of every broken invariant (empty when valid).
  List<String> invariantViolations() {
    final v = <String>[];
    bool onGrid(double x) =>
        (x / lcdPixel - (x / lcdPixel).round()).abs() < 1e-9;
    final exactScroll = scrollSpeed * fixedDt;

    if ((exactScroll - exactScroll.round()).abs() > 1e-9) {
      v.add('scroll per tick ($exactScroll px) must be a whole number of px');
    }
    if (!onGrid(scrollPxPerTick.toDouble())) {
      v.add('scroll per tick must be a whole number of LCD pixels');
    }
    if (columnWidth % scrollPxPerTick != 0) {
      v.add('columnWidth must be a multiple of the scroll per tick');
    }
    if (scrollPxPerTick >= columnWidth) {
      v.add('anti-tunnelling: scroll per tick must be < columnWidth');
    }
    final thinnest = [
      columnWidth,
      obstacleWidth,
      obstacleMinHeight,
    ].reduce((a, b) => a < b ? a : b);
    if (maxVerticalPerTick >= thinnest) {
      v.add(
        'anti-tunnelling: max vertical move per tick must be < $thinnest px',
      );
    }
    if (walkStep >= climbMargin) {
      v.add('walkStep ($walkStep) must be < climbMargin ($climbMargin)');
    }
    if (minGap - obstacleMaxHeight < minPassableHeight) {
      v.add('minGap - obstacleMaxHeight must be >= minPassableHeight');
    }
    if (minPassableHeight <= hitboxHeight) {
      v.add('minPassableHeight must exceed the hitbox height');
    }
    if (initialGap + 2 * edgeMargin > playHeight) {
      v.add('initialGap plus edge margins must fit the play area');
    }
    if (minGap > initialGap) v.add('minGap must be <= initialGap');
    if (obstacleWidth % columnWidth != 0) {
      v.add('obstacleWidth must be a whole number of columns');
    }
    for (final (name, value) in [
      ('playTop', playTop),
      ('columnWidth', columnWidth),
      ('edgeMargin', edgeMargin),
      ('walkStep', walkStep),
      ('initialGap', initialGap),
      ('minGap', minGap),
      ('obstacleMinHeight', obstacleMinHeight),
      ('obstacleHeightStep', obstacleHeightStep),
      ('heliX', heliX),
      ('hitboxInset', hitboxInset),
    ]) {
      if (!onGrid(value)) {
        v.add('$name ($value) must be a multiple of $lcdPixel');
      }
    }
    return v;
  }

  void assertInvariants() {
    final v = invariantViolations();
    if (v.isNotEmpty) throw StateError('Invalid Config: ${v.join('; ')}');
  }
}
