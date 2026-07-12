import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:invoy/app_metadata.dart';

void main() {
  test('displayed version matches the Android release version', () async {
    final pubspec = await File('pubspec.yaml').readAsString();

    expect(pubspec, contains('version: $appVersionName+$appBuildNumber'));
  });
}
