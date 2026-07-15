import 'dart:io';
import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() => integrationDriver(
      onScreenshot: (name, bytes, [args]) async {
        final file = File('build/ui_shots/$name.png')
          ..createSync(recursive: true);
        file.writeAsBytesSync(bytes);
        return true;
      },
    );
