import 'package:equatable/equatable.dart';

class ConversationSummary extends Equatable {
  const ConversationSummary({
    required this.id,
    required this.peerUserId,
    required this.peerDisplayName,
    this.peerAvatarUrl,
    this.lastMessagePreview = '',
    this.unreadCount = 0,
    this.peerOnline = false,
    this.lastMessageAt,
  });

  final String id;
  final String peerUserId;
  final String peerDisplayName;
  final String? peerAvatarUrl;
  final String lastMessagePreview;
  final int unreadCount;
  final bool peerOnline;
  final DateTime? lastMessageAt;

  factory ConversationSummary.fromJson(Map<String, dynamic> json) {
    return ConversationSummary(
      id: json['id'] as String? ?? '',
      peerUserId: json['peerUserId'] as String? ?? '',
      peerDisplayName: json['peerDisplayName'] as String? ?? 'User',
      peerAvatarUrl: json['peerAvatarUrl'] as String?,
      lastMessagePreview: json['lastMessagePreview'] as String? ?? '',
      unreadCount: json['unreadCount'] as int? ?? 0,
      peerOnline: json['peerOnline'] as bool? ?? false,
      lastMessageAt: json['lastMessageAt'] is String
          ? DateTime.tryParse(json['lastMessageAt'] as String)
          : null,
    );
  }

  ConversationSummary copyWith({String? lastMessagePreview, int? unreadCount}) {
    return ConversationSummary(
      id: id,
      peerUserId: peerUserId,
      peerDisplayName: peerDisplayName,
      peerAvatarUrl: peerAvatarUrl,
      lastMessagePreview: lastMessagePreview ?? this.lastMessagePreview,
      unreadCount: unreadCount ?? this.unreadCount,
      peerOnline: peerOnline,
      lastMessageAt: lastMessageAt,
    );
  }

  @override
  List<Object?> get props => [id, unreadCount, lastMessagePreview, peerOnline];
}

class ChatMessage extends Equatable {
  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.body,
    required this.createdAt,
    this.readAt,
    this.status = 'SENT',
    this.localStatus = 'sent',
    this.idempotencyKey,
  });

  final String id;
  final String conversationId;
  final String senderId;
  final String body;
  final DateTime createdAt;
  final DateTime? readAt;
  /// Server-authoritative: SENT | READ
  final String status;
  /// Local-only: sending | sent | failed
  final String localStatus;
  final String? idempotencyKey;

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final readAt = json['readAt'] is String
        ? DateTime.tryParse(json['readAt'] as String)
        : null;
    final status =
        json['status'] as String? ?? (readAt != null ? 'READ' : 'SENT');
    return ChatMessage(
      id: json['id'] as String? ?? '',
      conversationId: json['conversationId'] as String? ?? '',
      senderId: json['senderId'] as String? ?? '',
      body: json['body'] as String? ?? '',
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      readAt: readAt,
      status: status,
      localStatus: 'sent',
      idempotencyKey: json['idempotencyKey'] as String?,
    );
  }

  ChatMessage copyWith({
    String? id,
    DateTime? readAt,
    String? status,
    String? localStatus,
    String? idempotencyKey,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      conversationId: conversationId,
      senderId: senderId,
      body: body,
      createdAt: createdAt,
      readAt: readAt ?? this.readAt,
      status: status ?? this.status,
      localStatus: localStatus ?? this.localStatus,
      idempotencyKey: idempotencyKey ?? this.idempotencyKey,
    );
  }

  @override
  List<Object?> get props => [id, body, localStatus, status, readAt];
}
