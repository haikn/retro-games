import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// LCD background colour (palette token `lcd`).
const lcdColor = Color(0xFFC7F0D8);

/// Bezel colour around the LCD (palette token `bezel`).
const bezelColor = Color(0xFF1E2219);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(const CaveCopterApp());
}

/// Walking-skeleton app: an empty LCD panel, replaced by the game in M2/M3.
class CaveCopterApp extends StatelessWidget {
  const CaveCopterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Cave Copter',
      debugShowCheckedModeBanner: false,
      home: ColoredBox(
        color: bezelColor,
        child: Center(
          child: AspectRatio(
            aspectRatio: 2,
            child: ColoredBox(color: lcdColor),
          ),
        ),
      ),
    );
  }
}
