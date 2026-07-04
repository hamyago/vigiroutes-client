import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/api_service.dart';
import '../../../shared/widgets/custom_button.dart';

/// Écran de soumission d'un avis (client → prestataire) après une
/// intervention terminée.
///
/// AJOUTÉ : le bouton "Noter" existait déjà (context.push vers
/// /user/review/{id}) mais aucun écran ni route ne correspondait — clic
/// dessus produisait une erreur de navigation. L'écran de lecture des
/// avis déjà reçus (user_reviews_screen.dart, route /user/reviews) est
/// un écran différent.
class ReviewScreen extends StatefulWidget {
  final String interventionId;
  const ReviewScreen({super.key, required this.interventionId});

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  int _rating = 0;
  final _commentCtrl = TextEditingController();
  bool _submitting = false;
  String? _error;
  bool _done = false;

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_rating == 0) {
      setState(() => _error = 'Sélectionnez une note avant d\'envoyer.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ApiService.instance.submitReview(
        interventionId: widget.interventionId,
        rating: _rating,
        comment: _commentCtrl.text.trim(),
      ).timeout(const Duration(seconds: 20));
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _done = true;
      });
    } catch (e) {
      if (!mounted) return;
      final already = e.toString().contains('409') ||
          e.toString().toLowerCase().contains('déjà noté');
      setState(() {
        _submitting = false;
        _error = already
            ? 'Vous avez déjà noté cette intervention.'
            : 'Impossible d\'envoyer votre avis. Réessayez.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('Noter le prestataire',
            style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600)),
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: _done ? _buildDone(context) : _buildForm(),
    );
  }

  Widget _buildDone(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('🎉', style: TextStyle(fontSize: 56)),
              const SizedBox(height: 16),
              const Text('Merci pour votre avis !',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              const Text(
                'Votre note aide les autres utilisateurs et le prestataire à s\'améliorer.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 24),
              AppButton(
                label: 'Retour à l\'accueil',
                onPressed: () => context.go('/user/home'),
              ),
            ],
          ),
        ),
      );

  Widget _buildForm() => SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 12),
            const Text(
              'Comment s\'est passée votre intervention ?',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (i) {
                final filled = i < _rating;
                return IconButton(
                  iconSize: 42,
                  onPressed: () => setState(() {
                    _rating = i + 1;
                    _error = null;
                  }),
                  icon: Icon(
                    filled ? Icons.star_rounded : Icons.star_border_rounded,
                    color: AppColors.primary,
                  ),
                );
              }),
            ),
            const SizedBox(height: 8),
            if (_rating > 0)
              Center(
                child: Text(
                  _ratingLabel(_rating),
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                ),
              ),
            const SizedBox(height: 24),
            TextField(
              controller: _commentCtrl,
              maxLines: 4,
              maxLength: 500,
              decoration: InputDecoration(
                hintText: 'Un commentaire à ajouter ? (facultatif)',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: AppColors.error)),
            ],
            const SizedBox(height: 16),
            AppButton(
              label: 'Envoyer mon avis',
              isLoading: _submitting,
              onPressed: _submit,
            ),
          ],
        ),
      );

  String _ratingLabel(int r) => const {
        1: 'Très déçu',
        2: 'Déçu',
        3: 'Correct',
        4: 'Satisfait',
        5: 'Excellent !',
      }[r]!;
}
