// lib/core/models/vehicle_stats_model.dart
// ─────────────────────────────────────────────────────────────────────────────
// Modèle de statistiques d'interventions par véhicule (S18).
//
// Contient :
//   - Les stats des 30 derniers jours (count, cost, répartition par type)
//   - Les alertes de récurrence (>= 3 interventions du même type)
//   - Les stats "vie entière" du véhicule
// ─────────────────────────────────────────────────────────────────────────────

class VehicleStatsModel {
  final String vehicleId;
  final String registrationNumber;
  final String brand;
  final String model;

  final int periodDays;

  final int currentCount;
  final double currentCost;
  final List<VehicleStatsType> byType;
  final List<VehicleStatsAlert> alerts;

  final int lifetimeCount;
  final double lifetimeCost;

  const VehicleStatsModel({
    required this.vehicleId,
    required this.registrationNumber,
    required this.brand,
    required this.model,
    required this.periodDays,
    required this.currentCount,
    required this.currentCost,
    required this.byType,
    required this.alerts,
    required this.lifetimeCount,
    required this.lifetimeCost,
  });

  bool get hasData => currentCount > 0 || lifetimeCount > 0;
  bool get hasAlerts => alerts.isNotEmpty;

  factory VehicleStatsModel.fromJson(Map<String, dynamic> json) {
    final vehicle = (json['vehicle'] as Map<String, dynamic>?) ?? {};
    final current = (json['current'] as Map<String, dynamic>?) ?? {};
    final lifetime = (json['lifetime'] as Map<String, dynamic>?) ?? {};

    final byTypeRaw = (current['by_type'] as List?) ?? [];
    final alertsRaw = (current['alerts'] as List?) ?? [];

    return VehicleStatsModel(
      vehicleId:          (vehicle['id'] ?? '').toString(),
      registrationNumber: (vehicle['registration_number'] ?? '').toString(),
      brand:              (vehicle['brand'] ?? '').toString(),
      model:              (vehicle['model'] ?? '').toString(),
      periodDays:         (json['period_days'] as num?)?.toInt() ?? 30,
      currentCount:       (current['total_count'] as num?)?.toInt() ?? 0,
      currentCost:        (current['total_cost'] as num?)?.toDouble() ?? 0,
      byType: byTypeRaw
          .map((e) => VehicleStatsType.fromJson(
                (e as Map).cast<String, dynamic>(),
              ))
          .toList(),
      alerts: alertsRaw
          .map((e) => VehicleStatsAlert.fromJson(
                (e as Map).cast<String, dynamic>(),
              ))
          .toList(),
      lifetimeCount:      (lifetime['total_count'] as num?)?.toInt() ?? 0,
      lifetimeCost:       (lifetime['total_cost'] as num?)?.toDouble() ?? 0,
    );
  }
}

class VehicleStatsType {
  final String serviceTypeId;
  final String serviceTypeName;
  final int count;
  final double cost;

  const VehicleStatsType({
    required this.serviceTypeId,
    required this.serviceTypeName,
    required this.count,
    required this.cost,
  });

  factory VehicleStatsType.fromJson(Map<String, dynamic> json) {
    return VehicleStatsType(
      serviceTypeId:   (json['service_type_id'] ?? '').toString(),
      serviceTypeName: (json['service_type_name'] ?? '').toString(),
      count:           (json['count'] as num?)?.toInt() ?? 0,
      cost:            (json['cost'] as num?)?.toDouble() ?? 0,
    );
  }
}

class VehicleStatsAlert {
  final String serviceTypeId;
  final String serviceTypeName;
  final int count;
  final String message;

  const VehicleStatsAlert({
    required this.serviceTypeId,
    required this.serviceTypeName,
    required this.count,
    required this.message,
  });

  factory VehicleStatsAlert.fromJson(Map<String, dynamic> json) {
    return VehicleStatsAlert(
      serviceTypeId:   (json['service_type_id'] ?? '').toString(),
      serviceTypeName: (json['service_type_name'] ?? '').toString(),
      count:           (json['count'] as num?)?.toInt() ?? 0,
      message:         (json['message'] ?? '').toString(),
    );
  }
}
