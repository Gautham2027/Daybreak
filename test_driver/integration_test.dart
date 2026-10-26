import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

/// Saves screenshots from integration_test/screenshots_test.dart into
/// docs/screenshots/.
Future<void> main() => integrationDriver(
  onScreenshot: (name, bytes, [args]) async {
    final file = File('docs/screenshots/$name.png');
    await file.create(recursive: true);
    await file.writeAsBytes(bytes);
    return true;
  },
);
