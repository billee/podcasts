// lib/services/usage_service.dart
import 'package:kapwa_companion_basic/models/subscription.dart';

class UsageService {
  static const Map<String, Map<String, int>> _planLimits = {
    'trial': {'gptQueries': 10, 'videoMinutes': 5},
    'basic': {'gptQueries': 75, 'videoMinutes': 30},
    'premium': {'gptQueries': -1, 'videoMinutes': -1}, // -1 = unlimited
  };

  static bool isWithinLimit(Subscription sub, String feature) {
    final limit = _planLimits[sub.plan]?[feature] ?? 0;
    if (limit == -1) return true; // Unlimited

    final used =
        feature == 'gptQueries' ? sub.gptQueriesUsed : sub.videoMinutesUsed;
    return used < limit;
  }

  static String getLimitMessage(Subscription sub, String feature) {
    final limit = _planLimits[sub.plan]?[feature] ?? 0;
    if (limit == -1) return 'Unlimited';

    final used =
        feature == 'gptQueries' ? sub.gptQueriesUsed : sub.videoMinutesUsed;
    return '$used/$limit (${sub.plan.toUpperCase()})';
  }
}
