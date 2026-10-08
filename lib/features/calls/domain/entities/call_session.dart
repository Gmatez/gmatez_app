import 'package:equatable/equatable.dart';

import '../../../../core/calling/call_status.dart';

class CallRtcCredentials extends Equatable {
  const CallRtcCredentials({
    required this.appId,
    required this.channelName,
    required this.uid,
    required this.token,
    this.tokenExpiresAt,
  });

  final String appId;
  final String channelName;
  final int uid;
  final String token;
  final DateTime? tokenExpiresAt;

  factory CallRtcCredentials.fromJson(Map<String, dynamic> json) {
    DateTime? expires;
    final raw = json['tokenExpiresAt'];
    if (raw is String && raw.isNotEmpty) {
      expires = DateTime.tryParse(raw);
    }
    return CallRtcCredentials(
      appId: json['appId'] as String? ?? '',
      channelName: json['channelName'] as String? ?? '',
      uid: _asInt(json['uid']),
      token: json['token'] as String? ?? '',
      tokenExpiresAt: expires,
    );
  }

  @override
  List<Object?> get props => [appId, channelName, uid, token];
}

class CallSession extends Equatable {
  const CallSession({
    required this.id,
    required this.callerId,
    required this.calleeId,
    required this.callType,
    required this.status,
    required this.provider,
    required this.ratePerMinuteCents,
    this.settlementStatus = CallSettlementStatus.pending,
    this.providerSessionId,
    this.rtcChannelName,
    this.callerToken,
    this.calleeToken,
    this.rtc,
    this.callerDisplayName,
    this.calleeDisplayName,
    this.callerAvatarUrl,
    this.calleeAvatarUrl,
    this.billedSeconds = 0,
    this.billedAmountCents = 0,
    this.creatorEarningCents,
    this.platformFeeCents,
    this.direction,
    this.connectedAt,
    this.endedAt,
    this.endReason,
    this.createdAt,
  });

  final String id;
  final String callerId;
  final String calleeId;
  final String callType;
  final CallStatus status;
  /// Derived server field. ENDED does not imply SETTLED.
  final CallSettlementStatus settlementStatus;
  final String provider;
  final String? providerSessionId;
  final String? rtcChannelName;
  final String? callerToken;
  final String? calleeToken;
  final CallRtcCredentials? rtc;
  final String? callerDisplayName;
  final String? calleeDisplayName;
  final String? callerAvatarUrl;
  final String? calleeAvatarUrl;
  final int ratePerMinuteCents;
  final int billedSeconds;
  final int billedAmountCents;
  final int? creatorEarningCents;
  final int? platformFeeCents;
  final String? direction;
  final DateTime? connectedAt;
  final DateTime? endedAt;
  final String? endReason;
  final DateTime? createdAt;

  bool get isVideo => callType.toUpperCase() == 'VIDEO';
  bool get isMockProvider => provider == 'mock';

  CallSession copyWith({
    CallStatus? status,
    CallSettlementStatus? settlementStatus,
    String? callerToken,
    String? calleeToken,
    CallRtcCredentials? rtc,
    int? billedSeconds,
    int? billedAmountCents,
    DateTime? connectedAt,
    DateTime? endedAt,
    String? endReason,
  }) {
    return CallSession(
      id: id,
      callerId: callerId,
      calleeId: calleeId,
      callType: callType,
      status: status ?? this.status,
      settlementStatus: settlementStatus ?? this.settlementStatus,
      provider: provider,
      providerSessionId: providerSessionId,
      rtcChannelName: rtcChannelName,
      callerToken: callerToken ?? this.callerToken,
      calleeToken: calleeToken ?? this.calleeToken,
      rtc: rtc ?? this.rtc,
      callerDisplayName: callerDisplayName,
      calleeDisplayName: calleeDisplayName,
      callerAvatarUrl: callerAvatarUrl,
      calleeAvatarUrl: calleeAvatarUrl,
      ratePerMinuteCents: ratePerMinuteCents,
      billedSeconds: billedSeconds ?? this.billedSeconds,
      billedAmountCents: billedAmountCents ?? this.billedAmountCents,
      creatorEarningCents: creatorEarningCents,
      platformFeeCents: platformFeeCents,
      direction: direction,
      connectedAt: connectedAt ?? this.connectedAt,
      endedAt: endedAt ?? this.endedAt,
      endReason: endReason ?? this.endReason,
      createdAt: createdAt,
    );
  }

  factory CallSession.fromJson(Map<String, dynamic> json) {
    DateTime? parseTime(dynamic value) {
      if (value is String && value.isNotEmpty) {
        return DateTime.tryParse(value);
      }
      return null;
    }

    CallRtcCredentials? rtc;
    final rtcRaw = _asStringMap(json['rtc']);
    if (rtcRaw != null) {
      rtc = CallRtcCredentials.fromJson(rtcRaw);
    } else if (json['token'] is String && json['channelName'] is String) {
      rtc = CallRtcCredentials.fromJson(json);
    }

    return CallSession(
      id: (json['id'] ?? json['callId']) as String? ?? '',
      callerId: json['callerId'] as String? ?? '',
      calleeId: json['calleeId'] as String? ?? '',
      callType: json['callType'] as String? ?? 'VOICE',
      status: CallStatus.fromBackend(json['status'] as String? ?? 'FAILED'),
      settlementStatus: CallSettlementStatus.fromBackend(
        json['settlementStatus'] as String?,
      ),
      provider: json['provider'] as String? ?? 'mock',
      providerSessionId: json['providerSessionId'] as String?,
      rtcChannelName: json['rtcChannelName'] as String?,
      callerToken: json['callerToken'] as String?,
      calleeToken: json['calleeToken'] as String?,
      rtc: rtc,
      callerDisplayName: json['callerDisplayName'] as String?,
      calleeDisplayName: json['calleeDisplayName'] as String?,
      callerAvatarUrl: json['callerAvatarUrl'] as String?,
      calleeAvatarUrl: json['calleeAvatarUrl'] as String?,
      ratePerMinuteCents: json['ratePerMinuteCents'] as int? ?? 0,
      billedSeconds: json['billedSeconds'] as int? ?? 0,
      billedAmountCents: json['billedAmountCents'] as int? ?? 0,
      creatorEarningCents: json['creatorEarningCents'] as int?,
      platformFeeCents: json['platformFeeCents'] as int?,
      direction: json['direction'] as String?,
      connectedAt: parseTime(json['connectedAt']),
      endedAt: parseTime(json['endedAt']),
      endReason: json['endReason'] as String?,
      createdAt: parseTime(json['createdAt']),
    );
  }

  @override
  List<Object?> get props => [id, status, settlementStatus, billedAmountCents];
}

Map<String, dynamic>? _asStringMap(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }
  return null;
}

int _asInt(dynamic value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value) ?? 0;
  }
  return 0;
}
