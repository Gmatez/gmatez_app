enum CallStatus {
  initiated,
  ringing,
  accepted,
  connecting,
  connected,
  ended,
  rejected,
  cancelled,
  timeout,
  failed;

  static CallStatus fromBackend(String value) {
    return CallStatus.values.firstWhere(
      (status) => status.name.toUpperCase() == value.toUpperCase(),
      orElse: () => CallStatus.failed,
    );
  }

  String get backendValue => name.toUpperCase();

  bool get isTerminal =>
      this == ended ||
      this == rejected ||
      this == cancelled ||
      this == timeout ||
      this == failed;
}

/// Financial settlement is separate from [CallStatus].
/// ENDED ≠ SETTLED — always read this field (or billedAmountCents) from the server.
enum CallSettlementStatus {
  pending,
  settled,
  notApplicable;

  static CallSettlementStatus fromBackend(String? value) {
    switch ((value ?? 'PENDING').toUpperCase()) {
      case 'SETTLED':
        return CallSettlementStatus.settled;
      case 'NOT_APPLICABLE':
        return CallSettlementStatus.notApplicable;
      default:
        return CallSettlementStatus.pending;
    }
  }

  String get backendValue {
    return switch (this) {
      CallSettlementStatus.pending => 'PENDING',
      CallSettlementStatus.settled => 'SETTLED',
      CallSettlementStatus.notApplicable => 'NOT_APPLICABLE',
    };
  }
}
