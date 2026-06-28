import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../core/constants/app_colors.dart';
import '../../../core/models/models.dart';
import '../../../core/services/api_service.dart';

class UserReviewsScreen extends StatelessWidget {
  const UserReviewsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ce que pensent les prestataires')),
      body: FutureBuilder<List<dynamic>>(
        future: ApiService.instance.getUserReviews(),
        builder: (_, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) return Center(child: Text('Erreur : ${snap.error}'));
          final reviews = (snap.data ?? [])
              .map((e) {
                try { return ReviewModel.fromJson(e as Map<String, dynamic>); }
                catch (_) { return null; }
              })
              .whereType<ReviewModel>()
              .toList();

          if (reviews.isEmpty) {
            return const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text('⭐', style: TextStyle(fontSize: 48)),
              SizedBox(height: 12),
              Text('Aucun avis recu pour le moment',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              SizedBox(height: 8),
              Text('Les prestataires peuvent vous noter apres une intervention.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary)),
            ]));
          }

          final avg = reviews.map((r) => r.rating).reduce((a, b) => a + b) / reviews.length;

          return ListView(padding: const EdgeInsets.all(16), children: [
            Container(
              padding: const EdgeInsets.all(20),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [AppColors.primary, Color(0xFF1A3A6B)]),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(children: [
                const Text('⭐', style: TextStyle(fontSize: 36)),
                const SizedBox(width: 16),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(avg.toStringAsFixed(1),
                      style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800)),
                  Text('${reviews.length} avis de prestataires',
                      style: const TextStyle(color: Colors.white70, fontSize: 13)),
                ]),
              ]),
            ),
            ...reviews.map((r) => _ReviewCard(review: r)),
          ]);
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
              color: AppColors.warning, size: 18))),
            Text(timeago.format(review.createdAt, locale: 'fr'),
                style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
          ]),
          if (review.comment != null && review.comment!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(review.comment!,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
          ],
        ]),
      );
}
