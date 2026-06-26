import 'package:flutter/material.dart';

class ServiceTypeModel {
  final String id;
  final String name;
  final String slug;
  final String description;
  final String icon;
  final double defaultBasePrice;
  final double defaultPricePerKm;
  final double minimumTotal;
  final double commissionRate;
  final String color;

  const ServiceTypeModel({
    required this.id,
    required this.name,
    required this.slug,
    required this.description,
    required this.icon,
    required this.defaultBasePrice,
    required this.defaultPricePerKm,
    required this.minimumTotal,
    required this.commissionRate,
    required this.color,
  });

  factory ServiceTypeModel.fromJson(Map<String, dynamic> json) =>
      ServiceTypeModel(
        id:                json['id']                  as String,
        name:              json['name']                as String,
        slug:              json['slug']                as String,
        description:       json['description']         as String? ?? '',
        icon:              json['icon']                as String? ?? 'build',
        defaultBasePrice:  double.parse(json['default_base_price'].toString()),
        defaultPricePerKm: double.parse(json['default_price_per_km'].toString()),
        minimumTotal:      double.parse(json['minimum_total'].toString()),
        commissionRate:    double.parse(json['commission_rate'].toString()),
        color:             _colorFromSlug(json['slug'] as String? ?? ''),
      );

  Map<String, dynamic> toJson() => {
        'id':                  id,
        'name':                name,
        'slug':                slug,
        'description':         description,
        'icon':                icon,
        'default_base_price':  defaultBasePrice,
        'default_price_per_km':defaultPricePerKm,
        'minimum_total':       minimumTotal,
        'commission_rate':     commissionRate,
      };

  /// Icône Material depuis le slug
  IconData get materialIcon {
    switch (slug) {
      case 'depannage':  return Icons.build;
      case 'remorquage': return Icons.local_shipping;
      case 'pneu':       return Icons.tire_repair;
      case 'batterie':   return Icons.battery_charging_full;
      case 'carburant':  return Icons.local_gas_station;
      case 'serrurier':  return Icons.key;
      default:           return Icons.build_circle;
    }
  }

  /// Emoji depuis le slug
  String get emoji {
    switch (slug) {
      case 'depannage':  return '🔧';
      case 'remorquage': return '🚛';
      case 'pneu':       return '🔩';
      case 'batterie':   return '🔋';
      case 'carburant':  return '⛽';
      case 'serrurier':  return '🔑';
      default:           return '🛠️';
    }
  }

  static String _colorFromSlug(String slug) {
    switch (slug) {
      case 'depannage':  return '#FF6B35';
      case 'remorquage': return '#4299E1';
      case 'pneu':       return '#48BB78';
      case 'batterie':   return '#9F7AEA';
      case 'carburant':  return '#FC8181';
      case 'serrurier':  return '#68D391';
      default:           return '#63B3ED';
    }
  }

  Color get colorValue {
    final hex = color.replaceAll('#', '');
    return Color(int.parse('FF$hex', radix: 16));
  }

  /// Formater le prix en FCFA
  String get formattedBasePrice =>
      '${defaultBasePrice.toInt()} FCFA';

  String get formattedPricePerKm =>
      '${defaultPricePerKm.toInt()} FCFA/km';

  String get formattedMinimum =>
      '${minimumTotal.toInt()} FCFA minimum';
}
