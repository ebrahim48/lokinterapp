import 'package:get/get.dart';
class Review {
  final String reviewer;
  final int rating;
  final String comment;
  final String date;

  const Review({
    required this.reviewer,
    required this.rating,
    required this.comment,
    this.date = '',
  });

  factory Review.fromJson(Map<String, dynamic> json) => Review(
        reviewer: json['user']?['name'] ?? 'anonymous'.tr,
        rating: json['stars'] ?? 0,
        comment: json['comment'] ?? '',
        date: (json['createdAt'] ?? json['created_at'] ?? '').toString(),
      );
}
