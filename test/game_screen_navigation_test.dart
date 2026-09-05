import 'dart:convert';
import 'dart:io';

import 'package:arrowescape/core/game_mode.dart';
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

  Future<void> launch(WidgetTester tester) async {
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
                    builder: (_) => const GameScreen(
                      level: 1,
                      isRandom: true,
                      gameMode: GameMode.timeAttack,
                    ),
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
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
