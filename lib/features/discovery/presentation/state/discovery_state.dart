import 'package:equatable/equatable.dart';

import '../../../../core/errors/app_failure.dart';
import '../../../profile/domain/entities/user_profile.dart';

enum DiscoveryStatus { loading, refreshing, success, empty, error }

class DiscoveryState extends Equatable {
  const DiscoveryState({
    required this.status,
    this.users = const [],
    this.query = '',
    this.language,
    this.onlineOnly = false,
    this.callType,
    this.nextCursor,
    this.loadingMore = false,
    this.failure,
    this.requestId = 0,
  });

  const DiscoveryState.loading() : this(status: DiscoveryStatus.loading);

  final DiscoveryStatus status;
  final List<UserProfile> users;
  final String query;
  final String? language;
  final bool onlineOnly;
  final String? callType;
  final String? nextCursor;
  final bool loadingMore;
  final AppFailure? failure;
  final int requestId;

  bool get hasMore => nextCursor != null && nextCursor!.isNotEmpty;
  bool get isBusy =>
      status == DiscoveryStatus.loading || status == DiscoveryStatus.refreshing;

  DiscoveryState copyWith({
    DiscoveryStatus? status,
    List<UserProfile>? users,
    String? query,
    String? language,
    bool? onlineOnly,
    String? callType,
    String? nextCursor,
    bool? loadingMore,
    AppFailure? failure,
    int? requestId,
    bool clearFailure = false,
    bool clearCursor = false,
    bool clearLanguage = false,
    bool clearCallType = false,
  }) {
    return DiscoveryState(
      status: status ?? this.status,
      users: users ?? this.users,
      query: query ?? this.query,
      language: clearLanguage ? null : language ?? this.language,
      onlineOnly: onlineOnly ?? this.onlineOnly,
      callType: clearCallType ? null : callType ?? this.callType,
      nextCursor: clearCursor ? null : nextCursor ?? this.nextCursor,
      loadingMore: loadingMore ?? this.loadingMore,
      failure: clearFailure ? null : failure ?? this.failure,
      requestId: requestId ?? this.requestId,
    );
  }

  @override
  List<Object?> get props => [
    status,
    users,
    query,
    language,
    onlineOnly,
    callType,
    nextCursor,
    loadingMore,
    failure,
    requestId,
  ];
}
