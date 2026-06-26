class AppConstants {
  AppConstants._();

  static const String appName      = 'VigiRoutes';
  static const String companyName  = 'Oyop MT';
  static const String supportPhone    = '+2250700000000';
  static const String supportWhatsapp = '+2250700000000';

  // Tarification (identique au backend Laravel PricingService)
  static const double commissionRate            = 0.15;
  static const double kmRate                    = 300.0;
  static const double searchRadiusKm            = 10.0;
  static const double subscriptionKmDiscount    = 0.30;

  // Statuts intervention
  static const String statusPending    = 'pending';
  static const String statusDispatching= 'dispatching';
  static const String statusAccepted   = 'accepted';
  static const String statusInProgress = 'in_progress';
  static const String statusCompleted  = 'completed';
  static const String statusCancelled  = 'cancelled';

  // SharedPreferences
  static const String prefOnboardingDone = 'onboarding_done';
  static const String prefFcmToken       = 'fcm_token';
}
