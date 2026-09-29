import 'package:flutter_test/flutter_test.dart';
import 'package:shutitoff/controllers/permission_controller.dart';
import 'package:shutitoff/models/pairing_handshake.dart';

void main() {
  group('Pairing & Handshake Engine Tests', () {
    test('generateHandshakeCode produces exactly 6 numeric digits', () {
      for (int i = 0; i < 50; i++) {
        final code = generateHandshakeCode();
        expect(code.length, equals(6));
        expect(RegExp(r'^\d{6}$').hasMatch(code), isTrue);
      }
    });

    test('verifyHandshakeCode validates exact match and rejects invalid inputs', () {
      const validCode = '123456';
      expect(verifyHandshakeCode('123456', validCode), isTrue);
      expect(verifyHandshakeCode(' 123456 ', validCode), isTrue);
      expect(verifyHandshakeCode('654321', validCode), isFalse);
      expect(verifyHandshakeCode('12345', validCode), isFalse);
      expect(verifyHandshakeCode('1234567', validCode), isFalse);
      expect(verifyHandshakeCode('abcdef', validCode), isFalse);
    });

    test('PairingSession toMap and fromMap serialization roundtrip', () {
      const original = PairingSession(
        id: 1,
        friendName: 'Roommate Bob',
        connectionCode: '987654',
        isAuthorized: true,
        canTurnOff: true,
        canSnooze: false,
      );

      final map = original.toMap();
      final reconstructed = PairingSession.fromMap(map);

      expect(reconstructed.id, equals(original.id));
      expect(reconstructed.friendName, equals(original.friendName));
      expect(reconstructed.connectionCode, equals(original.connectionCode));
      expect(reconstructed.isAuthorized, equals(original.isAuthorized));
      expect(reconstructed.canTurnOff, equals(original.canTurnOff));
      expect(reconstructed.canSnooze, equals(original.canSnooze));
    });
  });

  group('PermissionController Security & Protocol Tests', () {
    late PermissionController controller;

    setUp(() {
      controller = PermissionController();
      controller.pairedDevices = [
        const PairingSession(
          id: 10,
          friendName: 'Full Access Peer',
          connectionCode: '111111',
          isAuthorized: true,
          canTurnOff: true,
          canSnooze: true,
        ),
        const PairingSession(
          id: 20,
          friendName: 'Snooze Only Peer',
          connectionCode: '222222',
          isAuthorized: true,
          canTurnOff: false,
          canSnooze: true,
        ),
        const PairingSession(
          id: 30,
          friendName: 'Revoked Peer',
          connectionCode: '333333',
          isAuthorized: false,
          canTurnOff: true,
          canSnooze: true,
        ),
      ];
    });

    test('verifyCanExecuteTurnOff enforces permissions and authorization', () {
      expect(controller.verifyCanExecuteTurnOff(10), isTrue);
      expect(controller.verifyCanExecuteTurnOff(20), isFalse);
      expect(controller.verifyCanExecuteTurnOff(30), isFalse);
      expect(controller.verifyCanExecuteTurnOff(999), isFalse);
    });

    test('verifyCanExecuteSnooze enforces permissions and authorization', () {
      expect(controller.verifyCanExecuteSnooze(10), isTrue);
      expect(controller.verifyCanExecuteSnooze(20), isTrue);
      expect(controller.verifyCanExecuteSnooze(30), isFalse);
      expect(controller.verifyCanExecuteSnooze(999), isFalse);
    });

    test('Hardcoded safety blocks reject any database tampering attempts', () {
      // Direct safety checks
      expect(controller.canChangeBaseTime(10), isFalse);
      expect(controller.canReadDatabaseFiles(10), isFalse);
      expect(controller.canAlterAlarmTable(10), isFalse);

      // Blocked remote action dispatch checks
      expect(
        controller.validateRemoteInstruction(
          pairedDeviceId: 10,
          action: 'CREATE_ALARM',
        ),
        isFalse,
      );
      expect(
        controller.validateRemoteInstruction(
          pairedDeviceId: 10,
          action: 'UPDATE_ALARM',
        ),
        isFalse,
      );
      expect(
        controller.validateRemoteInstruction(
          pairedDeviceId: 10,
          action: 'DELETE_ALARM',
        ),
        isFalse,
      );
      expect(
        controller.validateRemoteInstruction(
          pairedDeviceId: 10,
          action: 'MODIFY_BASE_TIME',
        ),
        isFalse,
      );
      expect(
        controller.validateRemoteInstruction(
          pairedDeviceId: 10,
          action: 'READ_DATABASE_FILES',
        ),
        isFalse,
      );
    });

    test('validateRemoteInstruction correctly permits authorized actions only', () {
      expect(
        controller.validateRemoteInstruction(
          pairedDeviceId: 10,
          action: 'TURN_OFF',
        ),
        isTrue,
      );
      expect(
        controller.validateRemoteInstruction(
          pairedDeviceId: 10,
          action: 'SNOOZE',
        ),
        isTrue,
      );

      expect(
        controller.validateRemoteInstruction(
          pairedDeviceId: 20,
          action: 'TURN_OFF',
        ),
        isFalse,
      );
      expect(
        controller.validateRemoteInstruction(
          pairedDeviceId: 20,
          action: 'SNOOZE',
        ),
        isTrue,
      );

      expect(
        controller.validateRemoteInstruction(
          pairedDeviceId: 30,
          action: 'TURN_OFF',
        ),
        isFalse,
      );
    });
  });
}
