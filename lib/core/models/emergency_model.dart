enum EmergencyType {
  accident, fire, medical;
  String get label => switch(this){EmergencyType.accident=>'Accident de la route',EmergencyType.fire=>'Incendie',EmergencyType.medical=>'Malaise médical'};
  String get icon  => switch(this){EmergencyType.accident=>'🚗',EmergencyType.fire=>'🔥',EmergencyType.medical=>'🏥'};
  String get phoneNumber => switch(this){EmergencyType.accident=>'180',EmergencyType.fire=>'180',EmergencyType.medical=>'185'};
  String get serviceName => switch(this){EmergencyType.accident=>'Sapeurs-Pompiers',EmergencyType.fire=>'Sapeurs-Pompiers',EmergencyType.medical=>'SAMU'};
  String get key => switch(this){EmergencyType.accident=>'accident',EmergencyType.fire=>'fire',EmergencyType.medical=>'medical'};
  static EmergencyType fromKey(String k) => switch(k){'accident'=>EmergencyType.accident,'fire'=>EmergencyType.fire,_=>EmergencyType.medical};
}

enum EmergencyStatus {
  pending, called, acknowledged, resolved, falseAlarm;
  static EmergencyStatus fromString(String s) => switch(s){'pending'=>EmergencyStatus.pending,'called'=>EmergencyStatus.called,'acknowledged'=>EmergencyStatus.acknowledged,'resolved'=>EmergencyStatus.resolved,'false_alarm'=>EmergencyStatus.falseAlarm,_=>EmergencyStatus.pending};
}

class EmergencyAlert {
  final String id, userId, userName, userPhone;
  final EmergencyType type;
  final EmergencyStatus status;
  final double latitude, longitude;
  final String? address, description;
  final DateTime createdAt;

  const EmergencyAlert({required this.id,required this.userId,required this.userName,required this.userPhone,required this.type,required this.status,required this.latitude,required this.longitude,this.address,this.description,required this.createdAt});

  Map<String,dynamic> toJson() => {'user_id':userId,'user_name':userName,'user_phone':userPhone,'type':type.key,'latitude':latitude,'longitude':longitude,'address':address,'description':description};

  factory EmergencyAlert.fromJson(Map<String,dynamic> j) => EmergencyAlert(id:j['id'] as String,userId:j['user_id'] as String,userName:j['user_name'] as String? ?? '',userPhone:j['user_phone'] as String? ?? '',type:EmergencyType.fromKey(j['type'] as String? ?? 'medical'),status:EmergencyStatus.fromString(j['status'] as String? ?? 'pending'),latitude:_num(j['latitude']),longitude:_num(j['longitude']),address:j['address'] as String?,description:j['description'] as String?,createdAt:DateTime.parse(j['created_at'] as String));
}

// Conversion tolérante : Laravel sérialise parfois les colonnes DECIMAL
// (latitude/longitude) sous forme de chaînes plutôt que de nombres JSON.
double _num(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0;
}