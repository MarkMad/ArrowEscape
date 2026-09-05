import 'dart:io';

import 'package:arrowescape/core/app_themes.dart';
import 'package:arrowescape/core/constants.dart';
import 'package:arrowescape/core/game_mode.dart';
import 'package:arrowescape/data/models/arrow.dart';
import 'package:arrowescape/data/models/level.dart';
import 'package:arrowescape/data/repositories/progress_repository.dart';
import 'package:arrowescape/game/game_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  test('infinite lives defaults off and persists across restarts', () async {
    final directory = await Directory.systemTemp.createTemp(
      'arrowescape-test-',
    );
    Hive.init(directory.path);
    try {
      final first = await ProgressRepository.create();
      expect(first.heartRemover, isFalse);
      await first.toggleHeartRemover();
      first.dispose();
      await Hive.close();
      final second = await ProgressRepository.create();
      expect(second.heartRemover, isTrue);
      await second.toggleHeartRemover();
      second.dispose();
      await Hive.close();
      final third = await ProgressRepository.create();
      expect(third.heartRemover, isFalse);
      third.dispose();
    } finally {
      await Hive.close();
      await directory.delete(recursive: true);
    }
  });

  for (final mode in GameMode.values) {
    for (final infinite in [false, true]) {
      testWidgets('$mode, infinite=$infinite: mistakes and restart', (
        tester,
      ) async {
        var lost = 0;
        var gameOvers = 0;
        final state = GameState(
          level: LevelModel(
            levelNumber: 1,
            gridSize: 3,
            maskShape: MaskShape.square,
            arrows: [
              ArrowModel(
                id: 'a',
                row: 0,
                col: 1,
                direction: ArrowDirection.down,
                path: [
                  [0, 1],
                ],
              ),
              ArrowModel(
                id: 'b',
                row: 1,
                col: 1,
                direction: ArrowDirection.up,
                path: [
                  [1, 1],
                ],
              ),
            ],
          ),
          theme: GameTheme.classic,
          gameMode: mode,
          heartRemover: infinite,
          onLevelComplete: () {},
          onGameOver: () => gameOvers++,
          onLifeLost: () => lost++,
        );
        final lifeFree = infinite || mode == GameMode.zen;
        for (var i = 0; i < AppConstants.maxLives; i++) {
          expect(state.tapArrow('a'), TapResult.blocked);
          await tester.pump(AppConstants.arrowShakeDuration);
        }
        expect(state.isGameOver, !lifeFree);
        expect(lost, lifeFree ? 0 : AppConstants.maxLives);
        expect(state.livesLost, lost);
        expect(gameOvers, lifeFree ? 0 : 1);
        state.resetLevel();
        expect(state.lives, lifeFree ? 999 : AppConstants.maxLives);
        expect(state.isGameOver, isFalse);
        expect(state.livesLost, 0);
        // Time limits remain effective even with infinite lives.
        state.forceGameOver();
        expect(state.isGameOver, isTrue);
        expect(gameOvers, lifeFree ? 1 : 2);
        state.dispose();
      });
    }
  }
}
