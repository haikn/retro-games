import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:lcd_kit/lcd_kit.dart';

/// Device orientations allowed while a game of [o] is open.
List<DeviceOrientation> orientationsFor(GameOrientation o) => switch (o) {
  GameOrientation.portrait => const [DeviceOrientation.portraitUp],
  GameOrientation.landscape => const [
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ],
};

Future<void> lockOrientation(GameOrientation o) =>
    SystemChrome.setPreferredOrientations(orientationsFor(o));

/// Shows only the bezel colour until the screen has the [orientation] the
/// child needs, so a game never draws a frame at the wrong size while the
/// device rotates.
class OrientationGate extends StatelessWidget {
  const OrientationGate({
    super.key,
    required this.orientation,
    required this.color,
    required this.child,
  });

  final GameOrientation orientation;
  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final landscape = size.width > size.height;
    final ready = landscape == (orientation == GameOrientation.landscape);
    return ready ? child : ColoredBox(color: color);
  }
}
