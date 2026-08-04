// Client rule: verification is requested at EXACTLY two moments — the sender's
// "confirm agreement & continue" and the traveler's "accept deal". Browsing,
// chatting and posting must never ask. This guards the source so the gates
// can't creep back into other flows.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String read(String path) => File(path).readAsStringSync();

void main() {
  test('only the two deal actions call the gates', () {
    final callers = <String>[];
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      // the gate definitions themselves obviously mention the names
      if (f.path.endsWith('phone_gate.dart') || f.path.endsWith('verify_gate.dart')) {
        continue;
      }
      final src = f.readAsStringSync();
      if (src.contains('requirePhoneVerified(') || src.contains('requireVerified(')) {
        callers.add(f.path.replaceFirst('lib/', ''));
      }
    }
    callers.sort();
    expect(
      callers,
      [
        // traveler: "Accept deal"
        'features/deals/presentation/deal_details_page.dart',
        // sender: "Confirm agreement & continue"
        'features/chat/presentation/chat_conversation_page.dart',
      ]..sort(),
      reason: 'verification may only be requested at the two deal moments',
    );
  });

  test('messaging never asks for verification', () {
    final src =
        read('lib/features/chat/presentation/controllers/chat_conversation_controller.dart');
    expect(src.contains('requirePhoneVerified'), isFalse);
    expect(src.contains('requireVerified'), isFalse);
  });

  test('posting a trip or request never asks for verification', () {
    final src = read('lib/features/shell/presentation/main_shell.dart');
    expect(src.contains('requirePhoneVerified'), isFalse);
    expect(src.contains('requireIdentityVerified'), isFalse);
  });

  test('both gates run at each of the two moments', () {
    final chat = read('lib/features/chat/presentation/chat_conversation_page.dart');
    final deal = read('lib/features/deals/presentation/deal_details_page.dart');
    for (final src in [chat, deal]) {
      expect(src.contains('requirePhoneVerified('), isTrue);
      expect(src.contains('requireVerified()'), isTrue);
    }
  });
}
