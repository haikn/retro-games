import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app/app_flow.dart';
import 'app/game_screen.dart';
import 'game/helicopter_game.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(const CaveCopterApp());
}

class CaveCopterApp extends StatefulWidget {
  const CaveCopterApp({super.key, this.gameFactory});

  /// Overrides game construction (tests).
  final HelicopterGame Function()? gameFactory;

  @override
  State<CaveCopterApp> createState() => _CaveCopterAppState();
}

class _CaveCopterAppState extends State<CaveCopterApp> {
  late final AppFlow _flow = AppFlow(
    game: (widget.gameFactory ?? HelicopterGame.new)(),
    onExit: SystemNavigator.pop,
  );

  @override
  void dispose() {
    _flow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cave Copter',
      debugShowCheckedModeBanner: false,
      home: GameScreen(flow: _flow),
    );
  }
}
