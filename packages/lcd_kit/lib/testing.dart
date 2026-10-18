/// Test doubles for the kit's services (sound and leaderboards).
library;

import 'dart:async';

import 'lcd_kit.dart';

class FakePlayer implements SoundPlayer {
  bool failLoad = false;
  bool failPlay = false;
  final played = <String>[];
  String? looping;
  int ambientCalls = 0;

  @override
  Future<void> configureAmbient() async => ambientCalls++;

  @override
  Future<void> preload(List<String> files) async {
    if (failLoad) throw Exception('no audio');
  }

  @override
  Future<void> play(String file, double volume) async {
    if (failPlay) throw Exception('play failed');
    played.add(file);
  }

  @override
  Future<void> startLoop(String file, double volume) async {
    if (failPlay) throw Exception('loop failed');
    looping = file;
  }

  @override
  Future<void> stopLoop() async => looping = null;
}

class FakeBackend implements LeaderboardBackend {
  bool failSignIn = false;
  bool failSubmit = false;
  bool failShow = false;
  bool hangSignIn = false;
  int signIns = 0;
  int shows = 0;
  final submitted = <int>[];

  @override
  Future<void> signIn() async {
    signIns++;
    if (hangSignIn) return Completer<void>().future;
    if (failSignIn) throw Exception('declined');
  }

  @override
  Future<void> submit(int score) async {
    if (failSubmit) throw Exception('offline');
    submitted.add(score);
  }

  @override
  Future<void> show() async {
    if (failShow) throw Exception('ui failed');
    shows++;
  }
}
