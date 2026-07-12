import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/models.dart';
import '../../../core/services/api_service.dart';
import '../../../core/utils/price_calculator.dart';

/// Détail d'un magasin : tous ses produits disponibles, sélection des
/// quantités, validation de la commande.
class StoreDetailScreen extends StatefulWidget {
  final String storeId;
  const StoreDetailScreen({super.key, required this.storeId});

  @override
  State<StoreDetailScreen> createState() => _StoreDetailScreenState();
}

class _StoreDetailScreenState extends State<StoreDetailScreen> {
  StoreModel? _store;
  bool _loading = true;
  bool _error = false;
  bool _submitting = false;

  final Map<String, int> _quantities = {}; // productId -> quantité

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = false;
    });
    try {
      final data = await ApiService.instance
          .getStoreDetail(widget.storeId)
          .timeout(const Duration(seconds: 20));
      if (!mounted) return;
      setState(() {
        _store = StoreModel.fromJson(data);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = true;
      });
    }
  }

  double get _total {
    double sum = 0;
    for (final p in _store?.products ?? <StoreProductModel>[]) {
      final qty = _quantities[p.id] ?? 0;
      sum += qty * p.unitPrice;
    }
    return sum;
  }

  int get _itemCount => _quantities.values.where((q) => q > 0).length;

  Future<void> _submitOrder() async {
    final items = (_store?.products ?? <StoreProductModel>[])
        .where((p) => (_quantities[p.id] ?? 0) > 0)
        .map((p) => {'store_product_id': p.id, 'quantity': _quantities[p.id]})
        .toList();

    if (items.isEmpty) return;

    setState(() => _submitting = true);
    try {
      await ApiService.instance.createPartOrder(
        storeId: widget.storeId,
        items: items,
      ).timeout(const Duration(seconds: 20));
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('✅ Commande envoyée !'),
          content: const Text('Le magasin va préparer votre commande. Vous pourrez suivre son statut depuis "Mes commandes".'),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                context.pop();
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Erreur lors de l\'envoi de la commande. Réessayez.')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(_store?.name ?? 'Magasin',
            style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600)),
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, color: AppColors.error, size: 48),
                      const SizedBox(height: 12),
                      const Text('Impossible de charger ce magasin.'),
                      const SizedBox(height: 16),
                      ElevatedButton(onPressed: _load, child: const Text('Réessayer')),
                    ],
                  ),
                )
              : Column(
                  children: [
                    if (_store!.address != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        child: Row(children: [
                          const Icon(Icons.location_on_outlined, size: 16, color: AppColors.textMuted),
                          const SizedBox(width: 6),
                          Expanded(child: Text(_store!.address!,
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13))),
                        ]),
                      ),
                    Expanded(
                      child: _store!.products.isEmpty
                          ? const Center(child: Text('Aucun produit disponible pour l\'instant.'))
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _store!.products.length,
                              itemBuilder: (_, i) {
                                final p = _store!.products[i];
                                final qty = _quantities[p.id] ?? 0;
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(14),
                                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)],
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                                            Text(PriceCalculator.formatFcfa(p.unitPrice),
                                                style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 13)),
                                          ],
                                        ),
                                      ),
                                      Row(
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.remove_circle_outline),
                                            onPressed: qty > 0
                                                ? () => setState(() => _quantities[p.id] = qty - 1)
                                                : null,
                                          ),
                                          Text('$qty', style: const TextStyle(fontWeight: FontWeight.w700)),
                                          IconButton(
                                            icon: const Icon(Icons.add_circle_outline, color: AppColors.primary),
                                            onPressed: () => setState(() => _quantities[p.id] = qty + 1),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                    if (_itemCount > 0)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 10)],
                        ),
                        child: SafeArea(
                          top: false,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '$_itemCount article(s)',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  Text(
                                    PriceCalculator.formatFcfa(_total),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 16,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: _submitting ? null : _submitOrder,
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                  ),
                                  child: _submitting
                                      ? const SizedBox(
                                          width: 18, height: 18,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2, color: Colors.white))
                                      : const Text('Passer la commande'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
    );
  }
}
