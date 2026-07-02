class Review {
  final String reviewer;
  final int rating;
  final String comment;
  final String date;

  const Review({
    required this.reviewer,
    required this.rating,
    required this.comment,
    required this.date,
  });
}

const mockReviews = <Review>[
  Review(
    reviewer: 'Ahmed R.',
    rating: 5,
    comment: 'Smooth handover and great communication. Highly recommend!',
    date: 'May 2026',
  ),
  Review(
    reviewer: 'Lina B.',
    rating: 5,
    comment: 'Parcel arrived safe and on time. Thank you!',
    date: 'May 2026',
  ),
  Review(
    reviewer: 'Karim T.',
    rating: 4,
    comment: 'Good experience overall, slight delay at pickup.',
    date: 'Apr 2026',
  ),
];

double get averageRating =>
    mockReviews.map((r) => r.rating).reduce((a, b) => a + b) / mockReviews.length;
