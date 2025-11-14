class NotificationPreferences {
  const NotificationPreferences({
    required this.pushEnabled,
    required this.friendRequestAlerts,
    required this.friendActivityAlerts,
    required this.inspirationTips,
  });

  const NotificationPreferences.defaults()
      : pushEnabled = true,
        friendRequestAlerts = true,
        friendActivityAlerts = true,
        inspirationTips = false;

  final bool pushEnabled;
  final bool friendRequestAlerts;
  final bool friendActivityAlerts;
  final bool inspirationTips;

  factory NotificationPreferences.fromMap(Map<String, dynamic>? data) {
    if (data == null) {
      return const NotificationPreferences.defaults();
    }

    bool readBool(String key, bool fallback) {
      final value = data[key];
      if (value is bool) return value;
      if (value is num) return value != 0;
      if (value is String) {
        return value.toLowerCase() == 'true' || value == '1';
      }
      return fallback;
    }

    return NotificationPreferences(
      pushEnabled: readBool('pushEnabled', true),
      friendRequestAlerts: readBool('friendRequestAlerts', true),
      friendActivityAlerts: readBool('friendActivityAlerts', true),
      inspirationTips: readBool('inspirationTips', false),
    );
  }

  NotificationPreferences copyWith({
    bool? pushEnabled,
    bool? friendRequestAlerts,
    bool? friendActivityAlerts,
    bool? inspirationTips,
  }) {
    return NotificationPreferences(
      pushEnabled: pushEnabled ?? this.pushEnabled,
      friendRequestAlerts: friendRequestAlerts ?? this.friendRequestAlerts,
      friendActivityAlerts: friendActivityAlerts ?? this.friendActivityAlerts,
      inspirationTips: inspirationTips ?? this.inspirationTips,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'pushEnabled': pushEnabled,
      'friendRequestAlerts': friendRequestAlerts,
      'friendActivityAlerts': friendActivityAlerts,
      'inspirationTips': inspirationTips,
    };
  }
}
