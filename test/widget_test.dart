
import 'package:flutter_test/flutter_test.dart';

import 'package:my_medical_history/app.dart';

// =====================================
// MY MEDICAL HISTORY - WIDGET TEST
// =====================================

void main() {
  // =====================================
  // TEST 1 - APP WIDGET
  // =====================================

  test(
    'My Medical History app can be created',
        () {
      const app = MyMedicalHistoryApp();

      expect(app, isA<MyMedicalHistoryApp>());
    },
  );

  // =====================================
  // TEST 2 - APP INSTANCE
  // =====================================

  test(
    'My Medical History creates an app instance',
        () {
      const app = MyMedicalHistoryApp();

      expect(app, isNotNull);
    },
  );
}
