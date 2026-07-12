import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/models.dart';
import '../../../core/services/api_service.dart';

const _statusLabels = {
  'pending': 'En attente', 'accepted': 'Acceptée', 'ready': 'Prête',
  'completed': 'Terminée', 'cancelled': 'Annulée',
};
const _statusColors = {
  'pending': AppColors.warning, 'accepted': AppColors.primary, 'ready': AppColors.primary,
  'completed': AppColors.success, 'cancelled': AppColors.error,
};

/// Historique des commandes de pièces du client.
class PartOrdersScreen extends StatefulWidget {
  const PartOrdersScreen({super.key});

  @override
  State<PartOrdersScreen> createState() => _PartOrdersScreenState();
}

class _PartOrdersScreenState extends State<PartOrdersScreen> {
  List<PartOrderModel> _orders = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await ApiService.instance.getMyPartOrders();
      if (!mounted) return;
      setState(() {
        _orders = data
            .map((e) => PartOrderModel.fromJson(e as Map<String, dynamic>))
            .toList();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _orders = [];
        _loading = false;
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
        title: const Text('Mes commandes de pièces',
            style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600)),
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _orders.isEmpty
              ? const Center(child: Text('Aucune commande de pièces pour l\'instant.'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _orders.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      final o = _orders[i];
                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6)],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                              Text(o.store?['name'] as String? ?? 'Magasin',
                                  style: const TextStyle(fontWeight: FontWeight.w700)),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: (_statusColors[o.status] ?? AppColors.textMuted).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(_statusLabels[o.status] ?? o.status,
                                    style: TextStyle(color: _statusColors[o.status], fontSize: 12, fontWeight: FontWeight.w600)),
                              ),
                            ]),
                            const SizedBox(height: 6),
                            ...o.items.map((it) => Text('${it.quantity} × ${it.productName}',
                                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13))),
                            const SizedBox(height: 6),
                            Text('${o.totalAmount.toStringAsFixed(0)} FCFA',
                                style: const TextStyle(fontWeight: FontWeight.w700)),
                          ],
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
