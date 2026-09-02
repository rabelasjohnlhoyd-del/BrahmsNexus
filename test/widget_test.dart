// Basic widget tests for the Brahms Nexus app.
//
// These verify that the app boots into the login screen and that the
// core login form elements are present.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:brahmsnexus/main.dart';

void main() {
  testWidgets('App launches into the login screen', (tester) async {
    await tester.pumpWidget(const BrahmsNexusApp());
    await tester.pumpAndSettle();

    expect(find.text('BRAHMS NEXUS'), findsOneWidget);
    expect(find.text('LOGIN'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(2));
  });

  testWidgets('Login shows validation errors on empty submit', (tester) async {
    await tester.pumpWidget(const BrahmsNexusApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('LOGIN'));
    await tester.pumpAndSettle();

    expect(find.text('Username is required'), findsOneWidget);
    expect(find.text('Password is required'), findsOneWidget);
  });

  testWidgets('Password visibility toggle switches obscureText', (tester) async {
    await tester.pumpWidget(const BrahmsNexusApp());
    await tester.pumpAndSettle();

    final passwordField = find.byType(TextFormField).at(1);
    TextField textField() => tester.widget<TextField>(
          find.descendant(
            of: passwordField,
            matching: find.byType(TextField),
          ),
        );

    expect(textField().obscureText, isTrue);

    await tester.tap(find.byIcon(Icons.visibility_off_outlined));
    await tester.pumpAndSettle();

    expect(textField().obscureText, isFalse);
  });
}
