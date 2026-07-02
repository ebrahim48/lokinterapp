import '../../posts/data/models/post_model.dart';
import 'deal_model.dart';

const _ahmed = PostUser(name: 'Ahmed R.', verified: true, rating: 4.7);
const _lina = PostUser(name: 'Lina B.', verified: true, rating: 4.9);
const _karim = PostUser(name: 'Karim T.', rating: 4.1);

final mockDeals = <Deal>[
  Deal(
    refId: 'LK-2041',
    type: PostType.deliver,
    location: PostLocation.international,
    fromCountry: 'Paris',
    toCountry: 'Tunis',
    date: DateTime(2026, 6, 8),
    weight: 2,
    profit: 'TND 50.000',
    status: DealStatus.accepted,
    counterpart: _ahmed,
  ),
  Deal(
    refId: 'LK-2038',
    type: PostType.trip,
    location: PostLocation.local,
    fromCountry: 'Tunis',
    toCountry: 'Sfax',
    date: DateTime(2026, 6, 3),
    weight: 5,
    profit: 'TND 20.000',
    status: DealStatus.pending,
    counterpart: _lina,
  ),
  Deal(
    refId: 'LK-2025',
    type: PostType.deliver,
    location: PostLocation.international,
    fromCountry: 'Istanbul',
    toCountry: 'Tunis',
    date: DateTime(2026, 5, 28),
    weight: 1,
    profit: 'USD 18.00',
    status: DealStatus.completed,
    counterpart: _karim,
  ),
  Deal(
    refId: 'LK-2017',
    type: PostType.deliver,
    location: PostLocation.international,
    fromCountry: 'Lyon',
    toCountry: 'Marseille',
    date: DateTime(2026, 5, 20),
    weight: 3,
    profit: 'EUR 35.00',
    status: DealStatus.disputes,
    counterpart: _ahmed,
    disputeReason: 'Item not delivered on the agreed date',
  ),
];
