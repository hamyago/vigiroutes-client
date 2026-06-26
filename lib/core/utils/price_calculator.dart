class PriceCalculator {
  PriceCalculator._();

  static String formatFcfa(double amount) {
    final formatted = amount.toStringAsFixed(0)
        .replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]} ');
    return '$formatted FCFA';
  }

  static double applySubscriptionDiscount(double price) => price * 0.70;
}