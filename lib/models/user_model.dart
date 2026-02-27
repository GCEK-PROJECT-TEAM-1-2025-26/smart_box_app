class UserModel {
  final String uid;
  final String email;
  final String displayName;
  final String? phoneNumber;
  final String? photoURL;
  final bool isEmailVerified;
  final double walletBalance;
  final double totalUsage;
  final double totalSpent;
  final int sessionsCount;
  final DateTime? lastActiveAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final UserPreferences preferences;
  final UserStats stats;

  UserModel({
    required this.uid,
    required this.email,
    required this.displayName,
    this.phoneNumber,
    this.photoURL,
    required this.isEmailVerified,
    required this.walletBalance,
    required this.totalUsage,
    required this.totalSpent,
    required this.sessionsCount,
    this.lastActiveAt,
    required this.createdAt,
    required this.updatedAt,
    required this.preferences,
    required this.stats,
  });

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      displayName: map['displayName'] ?? '',
      phoneNumber: map['phoneNumber'],
      photoURL: map['photoURL'],
      isEmailVerified: map['isEmailVerified'] ?? false,
      walletBalance: (map['walletBalance'] ?? 0.0).toDouble(),
      totalUsage: (map['totalUsage'] ?? 0.0).toDouble(),
      totalSpent: (map['totalSpent'] ?? 0.0).toDouble(),
      sessionsCount: map['sessionsCount'] ?? 0,
      lastActiveAt: map['lastActiveAt']?.toDate(),
      createdAt: map['createdAt']?.toDate() ?? DateTime.now(),
      updatedAt: map['updatedAt']?.toDate() ?? DateTime.now(),
      preferences: UserPreferences.fromMap(map['preferences'] ?? {}),
      stats: UserStats.fromMap(map['stats'] ?? {}),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'phoneNumber': phoneNumber,
      'photoURL': photoURL,
      'isEmailVerified': isEmailVerified,
      'walletBalance': walletBalance,
      'totalUsage': totalUsage,
      'totalSpent': totalSpent,
      'sessionsCount': sessionsCount,
      'lastActiveAt': lastActiveAt,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'preferences': preferences.toMap(),
      'stats': stats.toMap(),
    };
  }

  UserModel copyWith({
    String? uid,
    String? email,
    String? displayName,
    String? phoneNumber,
    String? photoURL,
    bool? isEmailVerified,
    double? walletBalance,
    double? totalUsage,
    double? totalSpent,
    int? sessionsCount,
    DateTime? lastActiveAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    UserPreferences? preferences,
    UserStats? stats,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      photoURL: photoURL ?? this.photoURL,
      isEmailVerified: isEmailVerified ?? this.isEmailVerified,
      walletBalance: walletBalance ?? this.walletBalance,
      totalUsage: totalUsage ?? this.totalUsage,
      totalSpent: totalSpent ?? this.totalSpent,
      sessionsCount: sessionsCount ?? this.sessionsCount,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      preferences: preferences ?? this.preferences,
      stats: stats ?? this.stats,
    );
  }
}

class UserPreferences {
  final bool notifications;
  final String theme; // 'light', 'dark', 'system'
  final String language; // 'en', 'hi', etc.

  UserPreferences({
    required this.notifications,
    required this.theme,
    required this.language,
  });

  factory UserPreferences.fromMap(Map<String, dynamic> map) {
    return UserPreferences(
      notifications: map['notifications'] ?? true,
      theme: map['theme'] ?? 'system',
      language: map['language'] ?? 'en',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'notifications': notifications,
      'theme': theme,
      'language': language,
    };
  }

  UserPreferences copyWith({
    bool? notifications,
    String? theme,
    String? language,
  }) {
    return UserPreferences(
      notifications: notifications ?? this.notifications,
      theme: theme ?? this.theme,
      language: language ?? this.language,
    );
  }
}

class UserStats {
  final int totalSessions;
  final int totalTimeUsed; // in minutes
  final int averageSessionTime; // in minutes
  final List<String> favoriteBoxes; // box IDs

  UserStats({
    required this.totalSessions,
    required this.totalTimeUsed,
    required this.averageSessionTime,
    required this.favoriteBoxes,
  });

  factory UserStats.fromMap(Map<String, dynamic> map) {
    return UserStats(
      totalSessions: map['totalSessions'] ?? 0,
      totalTimeUsed: map['totalTimeUsed'] ?? 0,
      averageSessionTime: map['averageSessionTime'] ?? 0,
      favoriteBoxes: List<String>.from(map['favoriteBoxes'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'totalSessions': totalSessions,
      'totalTimeUsed': totalTimeUsed,
      'averageSessionTime': averageSessionTime,
      'favoriteBoxes': favoriteBoxes,
    };
  }

  UserStats copyWith({
    int? totalSessions,
    int? totalTimeUsed,
    int? averageSessionTime,
    List<String>? favoriteBoxes,
  }) {
    return UserStats(
      totalSessions: totalSessions ?? this.totalSessions,
      totalTimeUsed: totalTimeUsed ?? this.totalTimeUsed,
      averageSessionTime: averageSessionTime ?? this.averageSessionTime,
      favoriteBoxes: favoriteBoxes ?? this.favoriteBoxes,
    );
  }
}
