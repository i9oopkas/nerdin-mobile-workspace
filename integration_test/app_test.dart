import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:nerdin_mobile_workspace/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('App starts without crash', (tester) async {
    // Start the app
    app.main();
    
    // Wait for the first frame
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    
    // If we get here without any error, the app started successfully.
    // Verify the widget tree rendered something.
    expect(find.byType(MaterialApp), findsWidgets);
  });
}
