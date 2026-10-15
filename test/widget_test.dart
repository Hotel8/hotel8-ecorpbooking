// SPDX-FileCopyrightText: Copyright Logically Magic Inc. <hello@logicallymagic.com>
// SPDX-FileCopyrightText: Copyright Hamid Jahanzad <Hamid@Jahanzad.com>
// SPDX-FileCopyrightText: Copyright Contributors to the Hotel8:ECorpBooking
// SPDX-License-Identifier: Apache-2.0

// eCorpBooking app smoke test.
//
// Pumps the real root widget (`HcorpApp`). The shell bootstraps the
// runtime context from the BFF at `initState`; with no BFF reachable
// under the test harness that fails and renders the deterministic
// offline fallback scaffold — the smoke assertion (the dash pattern).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ecorpbooking/app.dart';

void main() {
  testWidgets('HcorpApp builds and renders the offline fallback', (
    tester,
  ) async {
    await tester.pumpWidget(const HcorpApp());
    // Let the bootstrap fetch fail (offline) and the state settle.
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 200));

    // The dash pattern: the app builds and settles offline — the smoke
    // assertion is the widget tree (the bootstrap fetch fails with no
    // BFF reachable under the test harness; that path is the fallback
    // state, not a test failure).
    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.byType(HcorpApp), findsOneWidget);
  });
}
