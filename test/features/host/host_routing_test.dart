import 'package:flutter_test/flutter_test.dart';
import 'package:gmatez_app/core/utils/money.dart';
import 'package:gmatez_app/features/auth/domain/entities/session.dart';
import 'package:gmatez_app/features/discovery/domain/repositories/discovery_repository.dart';

void main() {
  test('formats integer cents without local billing math', () {
    expect(formatCents(500), r'$5.00');
    expect(formatCents(0), r'$0.00');
  });

  test('AuthUser host flags come from backend snapshot only', () {
    const pending = AuthUser(
      id: '1',
      email: 'eve@example.com',
      role: 'USER',
      status: 'ACTIVE',
      host: HostSnapshot(status: 'PENDING_REVIEW', availability: 'OFFLINE'),
    );
    const active = AuthUser(
      id: '2',
      email: 'bob@example.com',
      role: 'USER',
      status: 'ACTIVE',
      host: HostSnapshot(status: 'ACTIVE', availability: 'ONLINE'),
    );
    const suspendedHost = AuthUser(
      id: '4',
      email: 'sue@example.com',
      role: 'USER',
      status: 'ACTIVE',
      host: HostSnapshot(status: 'SUSPENDED', availability: 'OFFLINE'),
    );
    const admin = AuthUser(
      id: '3',
      email: 'admin@example.com',
      role: 'ADMIN',
      status: 'ACTIVE',
    );
    expect(pending.isPendingHost, isTrue);
    expect(pending.isActiveHost, isFalse);
    expect(active.isActiveHost, isTrue);
    expect(suspendedHost.isSuspendedHost, isTrue);
    expect(suspendedHost.isActiveHost, isFalse);
    expect(admin.isAdmin, isTrue);
    expect(admin.isActiveHost, isFalse);
  });

  test('discovery query sends call type and online filters', () {
    const query = DiscoveryQuery(
      onlineOnly: true,
      callType: 'VOICE',
      language: 'en',
      search: 'Bo',
    );
    expect(query.toQueryParameters()['online'], true);
    expect(query.toQueryParameters()['callType'], 'VOICE');
    expect(query.toQueryParameters()['language'], 'en');
  });
}
