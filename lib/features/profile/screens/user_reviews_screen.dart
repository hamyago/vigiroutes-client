import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../core/constants/app_colors.dart';
import '../../../core/models/models.dart';
import '../../../core/services/api_service.dart';
import '../../auth/controllers/auth_controller.dart';

class UserReviewsScreen extends StatelessWidget {
  const UserReviewsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userId = context.read<AuthController>().user?.id ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('Mes avis reçus')),
      body: FutureBuilder<List<dynamic>>(
        future: ApiService.instance.getUserReviews(),
        builder: (_, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Erreur : ${snap.error}'));
          }
          final reviews = (snap.data ?? [])
              .map((e) => ReviewModel.fromJson(e as Map<String, dynamic>))
              .toList();

          if (reviews.isEmpty) {
            return const Center(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text('⭐', style: TextStyle(fontSize: 48)),
                SizedBox(height: 12),
                Text('Aucun avis pour le moment',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ]),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: reviews.length,
            itemBuilder: (_, i) => _ReviewCard(review: reviews[i]),
          );
        },
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final ReviewModel review;
  const _ReviewCard({required this.review});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Row(children: List.generate(5, (i) => Icon(
              i < review.rating ? Icons.star : Icons.star_border,
              color: AppColors.warning, size: 18,
            ))),
            Text(timeago.format(review.createdAt, locale: 'fr'),
                style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
          ]),
          if (review.comment != null) ...[
            const SizedBox(height: 8),
            Text(review.comment!,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
          ],
        ]),
      );
}
