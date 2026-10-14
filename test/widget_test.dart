// SPDX-FileCopyrightText: Copyright Logically Magic Inc. <hello@logicallymagic.com>
// SPDX-FileCopyrightText: Copyright Hamid Jahanzad <Hamid@Jahanzad.com>
// SPDX-FileCopyrightText: Copyright Contributors to the Hotel8:ECorpBooking
// SPDX-License-Identifier: Apache-2.0

// eCorpBooking app smoke test.
//
// Pumps the real root widget (`HcorpApp`). The root renders the corporate
// login page until a company context is resolved — assert the login UI
// renders (branding + portal subtitle). No network calls happen while
// building this page.

import 'package:flutter_test/flutter_test.dart';

import 'package:ecorpbooking/app.dart';

void main() {
  testWidgets('HcorpApp renders corporate login page on first launch', (
    tester,
  ) async {
    await tester.pumpWidget(const HcorpApp());
    await tester.pump(const Duration(milliseconds: 100));

    // Login page branding.
    expect(find.text('Hcorp'), findsOneWidget);
    expect(find.text('Corporate Travel Portal'), findsOneWidget);
  });
}
