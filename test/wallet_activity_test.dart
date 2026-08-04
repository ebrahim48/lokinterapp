// Wallet must show every amount still owed with the reason it is held, and
// keep those out of the withdrawable balance. Payload from the API doc.
import 'package:flutter_task/features/profile/data/wallet_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final data = WalletData.fromJson({
    'available': 150.00,
    'totalPending': 75.00,
    'currency': 'USD',
    'hasStripeConnect': true,
    'potentialEarningsList': [
      {
        'dealId': 101,
        'dealRef': 'DEAL-889922',
        'dealStatus': 'ACCEPTED',
        'amount': 25.00,
        'profit': 25.00,
        'itemCost': 0.00,
        'statusLabel': 'Waiting for delivery completion',
      },
      {
        'dealId': 98,
        'dealRef': 'DEAL-776611',
        'dealStatus': 'COMPLETED',
        'amount': 50.00,
        'statusLabel': 'Waiting for the dispute window to close',
        'releaseAt': '2026-08-03T18:00:00Z',
        'countdownSeconds': 28800,
      },
    ],
    'disputeHistory': [
      {
        'dealId': 85,
        'dealRef': 'DEAL-554433',
        'amountCharged': 50.00,
        'statusLabel': 'Guarantee Charged due to Dispute',
        'reason': 'Damaged item on arrival',
        'status': 'resolved',
      },
    ],
  });

  test('potential earnings keep their status labels', () {
    expect(data.potential.length, 2);
    expect(data.potential[0].statusLabel, 'Waiting for delivery completion');
    expect(data.potential[1].statusLabel,
        'Waiting for the dispute window to close');
  });

  test('a countdown is rendered as time remaining', () {
    expect(data.potential[1].countdownText, '8h 0m left');
    expect(data.potential[0].countdownText, isNull);
  });

  test('the deal reference travels with each amount', () {
    expect(data.potential[0].dealRef, 'DEAL-889922');
    expect(data.potential[0].dealId, 101);
  });

  test('dispute history carries amount, reason and status', () {
    final d = data.disputes.single;
    expect(d.amountCharged, 50.00);
    expect(d.reason, 'Damaged item on arrival');
    expect(d.statusLabel, 'Guarantee Charged due to Dispute');
    expect(d.status, 'resolved');
  });

  test('pending money is not counted as available', () {
    expect(data.available, 150.00);
    expect(data.totalPending, 75.00);
    // the two potential rows are what makes up the pending total
    final owed = data.potential.fold<double>(0, (s, e) => s + e.amount);
    expect(owed, 75.00);
  });

  test('a transaction explains itself', () {
    final t = WalletTransaction.fromJson({
      'id': 12,
      'type': 'credit',
      'amount': 50.00,
      'balanceAfter': 200.00,
      'statusLabel': 'Earnings Deposited',
      'reason': 'Payout for Deal #DEAL-776611',
      'dealId': 98,
      'dealRef': 'DEAL-776611',
      'dateTime': '2026-08-03T10:15:00Z',
    });
    expect(t.statusLabel, 'Earnings Deposited');
    expect(t.dealRef, 'DEAL-776611');
    expect(t.createdAt, isNotNull);
    expect(t.isCredit, isTrue);
  });
}
