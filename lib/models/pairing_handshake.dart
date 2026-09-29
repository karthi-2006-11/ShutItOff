import 'dart:math';

class PairingSession {
  final int? id;
  final String friendName;
  final String connectionCode;
  final bool isAuthorized;
  final bool canSnooze;
  final bool canTurnOff;

  const PairingSession({
    this.id,
    required this.friendName,
    required this.connectionCode,
    this.isAuthorized = true,
    this.canSnooze = false,
    this.canTurnOff = false,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'friend_name': friendName,
      'connection_code': connectionCode,
      'is_authorized': isAuthorized ? 1 : 0,
      'can_snooze': canSnooze ? 1 : 0,
      'can_turn_off': canTurnOff ? 1 : 0,
    };
  }

  factory PairingSession.fromMap(Map<String, dynamic> map) {
    return PairingSession(
      id: map['id'] as int?,
      friendName: map['friend_name'] as String? ?? '',
      connectionCode: map['connection_code'] as String? ?? '',
      isAuthorized: (map['is_authorized'] as int? ?? 0) == 1,
      canSnooze: (map['can_snooze'] as int? ?? 0) == 1,
      canTurnOff: (map['can_turn_off'] as int? ?? 0) == 1,
    );
  }

  PairingSession copyWith({
    int? id,
    String? friendName,
    String? connectionCode,
    bool? isAuthorized,
    bool? canSnooze,
    bool? canTurnOff,
  }) {
    return PairingSession(
      id: id ?? this.id,
      friendName: friendName ?? this.friendName,
      connectionCode: connectionCode ?? this.connectionCode,
      isAuthorized: isAuthorized ?? this.isAuthorized,
      canSnooze: canSnooze ?? this.canSnooze,
      canTurnOff: canTurnOff ?? this.canTurnOff,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PairingSession &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          friendName == other.friendName &&
          connectionCode == other.connectionCode &&
          isAuthorized == other.isAuthorized &&
          canSnooze == other.canSnooze &&
          canTurnOff == other.canTurnOff;

  @override
  int get hashCode =>
      id.hashCode ^
      friendName.hashCode ^
      connectionCode.hashCode ^
      isAuthorized.hashCode ^
      canSnooze.hashCode ^
      canTurnOff.hashCode;
}

String generateHandshakeCode() {
  final random = Random.secure();
  final code = random.nextInt(900000) + 100000;
  return code.toString();
}

bool verifyHandshakeCode(String inputCode, String generatedCode) {
  final cleanInput = inputCode.trim();
  final cleanGenerated = generatedCode.trim();

  if (cleanInput.length != 6 || !RegExp(r'^\d{6}$').hasMatch(cleanInput)) {
    return false;
  }

  return cleanInput == cleanGenerated;
}
