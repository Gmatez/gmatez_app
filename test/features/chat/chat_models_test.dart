import 'package:flutter_test/flutter_test.dart';
import 'package:gmatez_app/features/chat/domain/entities/chat_models.dart';

void main() {
  test('parses chat messages and ignores missing readAt', () {
    final message = ChatMessage.fromJson({
      'id': 'm1',
      'conversationId': 'c1',
      'senderId': 'u1',
      'body': 'hello',
      'createdAt': '2026-09-12T10:00:00.000Z',
    });
    expect(message.id, 'm1');
    expect(message.body, 'hello');
    expect(message.readAt, isNull);
    expect(message.status, 'SENT');
    expect(message.copyWith(localStatus: 'failed').localStatus, 'failed');
  });

  test('parses READ status from server', () {
    final message = ChatMessage.fromJson({
      'id': 'm2',
      'conversationId': 'c1',
      'senderId': 'u1',
      'body': 'hi',
      'status': 'READ',
      'readAt': '2026-09-12T10:01:00.000Z',
      'createdAt': '2026-09-12T10:00:00.000Z',
    });
    expect(message.status, 'READ');
    expect(message.readAt, isNotNull);
  });

  test('conversation summary parses peerOnline', () {
    final row = ConversationSummary.fromJson({
      'id': 'c1',
      'peerUserId': 'u2',
      'peerDisplayName': 'Bob',
      'unreadCount': 2,
      'peerOnline': true,
      'lastMessagePreview': 'hello',
    });
    expect(row.peerOnline, isTrue);
    expect(row.unreadCount, 2);
  });
}
