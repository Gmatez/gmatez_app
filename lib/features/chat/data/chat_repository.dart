import '../../../../core/constants/api_paths.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/pagination/cursor_page.dart';
import '../../../../core/utils/result.dart';
import '../domain/entities/chat_models.dart';

class ChatRepository {
  ChatRepository(this._client);
  final ApiClient _client;

  Future<Result<ConversationSummary>> open(String userId) {
    return _client.post(
      ApiPaths.conversations,
      body: {'userId': userId},
      parser: (data) => ConversationSummary.fromJson(
        data is Map<String, dynamic> ? data : const {},
      ),
    );
  }

  Future<Result<CursorPage<ConversationSummary>>> list({String? cursor}) {
    return _client.get(
      ApiPaths.conversations,
      query: {'cursor': ?cursor},
      parser: (data) => CursorPage.fromJson(data, ConversationSummary.fromJson),
    );
  }

  Future<Result<CursorPage<ChatMessage>>> messages(
    String conversationId, {
    String? cursor,
  }) {
    return _client.get(
      ApiPaths.conversationMessages(conversationId),
      query: {'cursor': ?cursor},
      parser: (data) => CursorPage.fromJson(data, ChatMessage.fromJson),
    );
  }

  Future<Result<ChatMessage>> send({
    required String conversationId,
    required String body,
    required String idempotencyKey,
  }) {
    return _client.post(
      ApiPaths.conversationMessages(conversationId),
      body: {'body': body, 'idempotencyKey': idempotencyKey},
      parser: (data) =>
          ChatMessage.fromJson(data is Map<String, dynamic> ? data : const {}),
    );
  }

  Future<Result<void>> markRead(String conversationId) {
    return _client.post(
      ApiPaths.conversationRead(conversationId),
      parser: (_) {},
    );
  }
}
