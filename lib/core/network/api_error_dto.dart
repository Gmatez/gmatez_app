class ApiErrorDto {
  const ApiErrorDto({
    required this.code,
    required this.message,
    this.requestId,
    this.details,
  });

  final String code;
  final String message;
  final String? requestId;
  final Map<String, dynamic>? details;

  factory ApiErrorDto.fromJson(Map<String, dynamic> json) {
    final error = json['error'];
    if (error is Map<String, dynamic>) {
      return ApiErrorDto(
        code: error['code'] as String? ?? 'INTERNAL',
        message: error['message'] as String? ?? 'Something went wrong.',
        requestId: error['requestId'] as String?,
        details: error['details'] is Map<String, dynamic>
            ? error['details'] as Map<String, dynamic>
            : null,
      );
    }
    return ApiErrorDto(
      code: json['code'] as String? ?? 'INTERNAL',
      message: json['message'] as String? ?? 'Something went wrong.',
      requestId: json['requestId'] as String?,
    );
  }
}
