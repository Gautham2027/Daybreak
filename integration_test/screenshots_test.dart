// Captures README screenshots on a simulator or device:
//   flutter drive --driver=test_driver/integration_test.dart \
//     --target=integration_test/screenshots_test.dart -d <device>
// Screenshots are written to docs/screenshots/.

import 'package:daybreak/main.dart';
import 'package:daybreak/services/demo_data.dart';
import 'package:daybreak/services/storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('screenshots with demo data', (tester) async {
    await Hive.initFlutter();
    final storage = StorageService();
    await storage.init();
    await loadDemoData(storage, DateTime.now());

    await tester.pumpWidget(buildApp(storage));
    await tester.pumpAndSettle();
    await binding.convertFlutterSurfaceToImage();
    await tester.pumpAndSettle();
    Finder tab(String label) => find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text(label),
    );

    await binding.takeScreenshot('today_before');
    await tester.tap(find.text('Plan my day'));
    await tester.pumpAndSettle(const Duration(seconds: 1));
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 2000));
    await tester.pumpAndSettle();
    await binding.takeScreenshot('today');

    await tester.drag(find.byType(Scrollable).first, const Offset(0, -500));
    await tester.pumpAndSettle();
    await binding.takeScreenshot('today_timeline');

    await tester.drag(find.byType(Scrollable).first, const Offset(0, 2000));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.textContaining('Study for chem quiz').first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Study for chem quiz').first);
    await tester.pumpAndSettle();
    await binding.takeScreenshot('log_sheet');
    Navigator.of(tester.element(find.text('Minutes spent'))).pop();
    await tester.pumpAndSettle();

    await tester.tap(tab('Tasks'));
    await tester.pumpAndSettle();
    await binding.takeScreenshot('tasks');

    await tester.ensureVisible(find.text('History essay draft'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('History essay draft'));
    await tester.pumpAndSettle();
    await binding.takeScreenshot('task_form');
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    await tester.tap(tab('Stats'));
    await tester.pumpAndSettle();
    await binding.takeScreenshot('stats');
    await tester.drag(find.byType(Scrollable).last, const Offset(0, -600));
    await tester.pumpAndSettle();
    await binding.takeScreenshot('stats_bottom');

    await tester.tap(tab('Settings'));
    await tester.pumpAndSettle();
    await binding.takeScreenshot('settings');
  });
}
