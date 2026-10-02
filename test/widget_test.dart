import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:piece_finder/main.dart';
import 'package:piece_finder/models.dart';
import 'package:piece_finder/repository.dart';

class UnusedDatabase implements Database {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class EmptyRepository extends PuzzleRepository {
  EmptyRepository() : super(UnusedDatabase(), Directory.systemTemp.path);
  @override
  Future<List<Puzzle>> puzzles() async => [];
}

void main() {
  setUpAll(() async {
    final loader = FontLoader('Roboto')
      ..addFont(
        File('test/fonts/Roboto-Regular.ttf')
            .readAsBytes()
            .then((bytes) => ByteData.sublistView(bytes)),
      );
    await loader.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(
        File('test/fonts/MaterialIcons-Regular.otf')
            .readAsBytes()
            .then((bytes) => ByteData.sublistView(bytes)),
      );
    await icons.load();
  });
  testWidgets('iPhone-sized dashboard offers setup and explains privacy', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final boundary = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: PieceFinderApp(repository: EmptyRepository()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Every piece\nhas a place.'), findsOneWidget);
    expect(find.text('Unlimited scans'), findsOneWidget);
    expect(tester.takeException(), isNull);
    final render =
        boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final image = await render.toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await Directory('.artifacts').create(recursive: true);
      await File('.artifacts/dashboard.png')
          .writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
    await tester.tap(find.text('New puzzle'));
    await tester.pumpAndSettle();
    expect(find.text('Photograph the box'), findsOneWidget);
    expect(find.text('Choose a photo'), findsOneWidget);
    Navigator.of(tester.element(find.text('Choose a photo'))).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Photos and matching stay on your device.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets('small screen and large text do not overflow', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(PieceFinderApp(repository: EmptyRepository()));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
