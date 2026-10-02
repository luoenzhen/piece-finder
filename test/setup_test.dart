import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piece_finder/main.dart';
import 'package:piece_finder/setup.dart';

import 'fixtures.dart';
import 'widget_test.dart' show EmptyRepository;

void main() {
  testWidgets(
    'corner touch target works outside the image and during a continuous drag',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: pieceFinderTheme(),
          home: SetupScreen(
            bytes: png(referenceFixture()),
            repository: EmptyRepository(),
          ),
        ),
      );
      for (var i = 0; i < 100 && find.byType(Image).evaluate().isEmpty; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump();
      }
      final painterFinder = find.byWidgetPredicate(
        (widget) => widget is CustomPaint && widget.painter is CropPainter,
      );
      expect(painterFinder, findsOneWidget);
      CropPainter painter() =>
          tester.widget<CustomPaint>(painterFinder).painter! as CropPainter;
      final before = painter().corners.first;
      final handle = find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.label == 'Artwork corner 1',
      );
      await tester.ensureVisible(handle);
      final imageSize = tester.getSize(painterFinder);
      final start = tester.getCenter(handle) - const Offset(18, 18);
      final gesture = await tester.startGesture(start);
      await gesture.moveBy(const Offset(35, 35));
      await tester.pump();
      await gesture.moveBy(const Offset(20, 15));
      await tester.pump();
      await gesture.up();
      expect(
        painter().corners.first.x,
        closeTo(before.x + 55 / imageSize.width, .001),
      );
      expect(
        painter().corners.first.y,
        closeTo(before.y + 50 / imageSize.height, .001),
      );
      for (var i = 1; i < 4; i++) {
        final corner = find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.label == 'Artwork corner ${i + 1}',
        );
        await tester.ensureVisible(corner);
        final initial = painter().corners[i];
        final dx = i == 3 ? 40.0 : -40.0;
        final dy = i == 1 ? 40.0 : -40.0;
        final pointer = await tester.startGesture(
          tester.getCenter(corner) + Offset(-dx.sign * 18, -dy.sign * 18),
        );
        await pointer.moveBy(Offset(dx, dy));
        await tester.pump();
        await pointer.moveBy(Offset(-dx / 4, -dy / 4));
        await tester.pump();
        await pointer.up();
        expect(
          painter().corners[i].x,
          closeTo(initial.x + dx * .75 / imageSize.width, .001),
        );
        expect(
          painter().corners[i].y,
          closeTo(initial.y + dy * .75 / imageSize.height, .001),
        );
      }
      expect(tester.takeException(), isNull);
    },
  );
}
