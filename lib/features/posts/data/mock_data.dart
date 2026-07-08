import 'models/post_model.dart';

// Static sample data for laying out the screens. Swapped for the API later.
class MockData {
  MockData._();

  static final _moncef =
      const PostUser(name: 'Moncef A.', verified: true, rating: 4.8, isTransporter: true);
  static final _belhassen = const PostUser(name: 'Belhassen J.', verified: true, rating: 4.6);
  static final _sami = const PostUser(name: 'Sami K.', rating: 4.2);

  static final List<Post> trips = [
    Post(
      type: PostType.trip,
      location: PostLocation.international,
      fromCountry: 'Paris',
      toCountry: 'Marseille',
      date: DateTime(2026, 6, 1),
      weight: 50,
      remainingWeight: 42,
      user: _moncef,
      recommended: true,
    ),
    Post(
      type: PostType.trip,
      location: PostLocation.local,
      fromCountry: 'Tunisia',
      fromCity: 'Tunis',
      toCity: 'Sfax',
      toCountry: 'Tunisia',
      date: DateTime(2026, 6, 1),
      weight: 50,
      remainingWeight: 50,
      user: _belhassen,
    ),
    Post(
      type: PostType.trip,
      location: PostLocation.international,
      fromCountry: 'Istanbul',
      toCountry: 'Tunis',
      date: DateTime(2026, 5, 25),
      weight: 8,
      remainingWeight: 3,
      user: _sami,
      recommended: true,
    ),
  ];

  static final List<Post> requests = [
    Post(
      type: PostType.deliver,
      location: PostLocation.international,
      wantTo: WantTo.buyAndDeliver,
      title: 'Petit colis Shein Lille...',
      description: 'Gold heeled sandals, size 38, from the Shein Lille order.',
      fromCountry: 'Paris',
      toCountry: 'Marseille',
      date: DateTime(2026, 6, 2),
      weight: 2,
      profit: 'TND 50.000',
      user: _belhassen,
    ),
    Post(
      type: PostType.deliver,
      location: PostLocation.local,
      wantTo: WantTo.send,
      title: 'Petit colis Shein Lille...',
      description: 'Small sealed parcel, clothes. Already packed and ready.',
      fromCountry: 'Paris',
      toCountry: 'Marseille',
      date: DateTime(2026, 6, 2),
      weight: 2,
      profit: 'TND 50.000',
      user: _belhassen,
    ),
  ];

  // travelers surfaced in the "Recommended Travelers" rail
  static final List<Post> recommendedTravelers =
      trips.where((t) => t.recommended).toList();

  // dropdown options used by the post/search forms
  static const countries = [
    'Tunisia', 'France', 'Turkey', 'Qatar', 'Egypt', 'Germany', 'Italy', 'Spain',
  ];
  static const cities = [
    'Tunis', 'Sfax', 'Sousse', 'Paris', 'Marseille', 'Lyon', 'Lille',
  ];
  static const categories = [
    'Electronics', 'Clothing', 'Documents', 'Food', 'Cosmetics', 'Jewelry', 'Other',
  ];
}
