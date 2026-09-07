import 'dart:convert';
import 'dart:io';

import 'package:arrowescape/core/game_mode.dart';
import 'package:arrowescape/core/constants.dart';
import 'package:arrowescape/game/arrow_puzzle_game.dart';
import 'package:arrowescape/widgets/lives_bar.dart';
import 'package:flame/game.dart';
import 'package:arrowescape/data/models/arrow.dart';
import 'package:arrowescape/data/models/level.dart';
import 'package:arrowescape/data/repositories/level_repository.dart';
import 'package:arrowescape/data/repositories/progress_repository.dart';
import 'package:arrowescape/main.dart';
import 'package:arrowescape/screens/game/game_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  late Directory directory;
  late ProgressRepository progress;
  late LevelRepository levels;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp(
      'arrowescape-navigation-',
    );
    Hive.init(directory.path);
    progress = await ProgressRepository.create();
    await progress.toggleHeartRemover();
    levels = await LevelRepository.create();
    final level = LevelModel(
      levelNumber: 1,
      gridSize: 3,
      arrows: [
        ArrowModel(
          id: 'a',
          row: 1,
          col: 1,
          direction: ArrowDirection.up,
          path: [
            [1, 1],
            [2, 1],
          ],
        ),
      ],
    );
    await Hive.box(
      'levelCache',
    ).put('cached_level_1', jsonEncode(level.toJson()));
  });

  tearDown(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  Future<void> launch(
    WidgetTester tester, {
    GameMode mode = GameMode.timeAttack,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          progressRepositoryProvider.overrideWith((ref) => progress),
          levelRepositoryProvider.overrideWithValue(levels),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        GameScreen(level: 1, isRandom: true, gameMode: mode),
                  ),
                ),
                child: const Text('Start test game'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Start test game'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('system back pauses timer; resume and confirmed leave work', (
    tester,
  ) async {
    await launch(tester);
    expect(find.text('01:00'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Leave Level?'), findsOneWidget);
    await tester.pump(const Duration(seconds: 65));
    expect(find.text('01:00'), findsOneWidget);
    expect(find.text('Start New Run'), findsNothing);
    await tester.tap(find.text('Resume'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('00:59'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Leave Level?'), findsOneWidget);
    await tester.tap(find.text('Leave'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Start test game'), findsOneWidget);
    expect(find.byType(GameScreen), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('infinite lives still ends a timed run at zero', (tester) async {
    await launch(tester);
    await tester.pump(const Duration(seconds: 61));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Start New Run'), findsOneWidget);
    expect(find.text("Time's Up!"), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Start New Run'), findsOneWidget);
    await tester.tap(find.text('Start New Run'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Start New Run'), findsNothing);
    expect(find.text('01:00'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  ArrowPuzzleGame gameFor(WidgetTester tester) =>
      tester
              .widget<GameWidget>(
                find.byWidgetPredicate((w) => w is GameWidget),
              )
              .game
          as ArrowPuzzleGame;

  testWidgets('tap assist routes an empty-cell tap to an adjacent arrow', (
    tester,
  ) async {
    await tester.runAsync(() => progress.toggleAssistMode());
    await launch(tester);
    await tester.pump(const Duration(seconds: 1));
    final game = gameFor(tester);
    final grid = game.gridComponent!;
    final origin = tester.getTopLeft(
      find.byWidgetPredicate((w) => w is GameWidget),
    );
    await tester.tapAt(
      origin +
          Offset(
            grid.position.x - grid.size.x / 2 + grid.cellSize * 0.5,
            grid.position.y - grid.size.y / 2 + grid.cellSize * 1.5,
          ),
    );
    expect(game.gameState.arrowById('a')!.state, ArrowState.sliding);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('completion dialog survives system back', (tester) async {
    await launch(tester, mode: GameMode.classic);
    final state = gameFor(tester).gameState;
    state.tapArrow('a');
    state.handleArrowExitCompleted('a');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Level Complete!'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Level Complete!'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('late exit cannot advance a timed-out run', (tester) async {
    await launch(tester);
    final state = gameFor(tester).gameState;
    state.tapArrow('a');
    state.forceGameOver();
    state.handleArrowExitCompleted('a');
    expect(state.isComplete, isFalse);
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Start New Run'), findsOneWidget);
    expect(find.text('Score: 0'), findsOneWidget);
    expect(gameFor(tester).level.levelNumber, 1);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('time attack shows lives and identifies life exhaustion', (
    tester,
  ) async {
    await tester.runAsync(() => progress.toggleHeartRemover());
    final blockedLevel = LevelModel(
      levelNumber: 1,
      gridSize: 3,
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
    );
    await tester.runAsync(
      () => Hive.box(
        'levelCache',
      ).put('cached_level_1', jsonEncode(blockedLevel.toJson())),
    );
    await launch(tester);
    expect(tester.widget<LivesBar>(find.byType(LivesBar)).lives, 3);
    final state = gameFor(tester).gameState;
    for (var i = 0; i < 3; i++) {
      state.tapArrow('a');
      await tester.pump(AppConstants.arrowShakeDuration);
    }
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Out of Lives!'), findsOneWidget);
    expect(find.text("Time's Up!"), findsNothing);
    expect(find.text('Start New Run'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
