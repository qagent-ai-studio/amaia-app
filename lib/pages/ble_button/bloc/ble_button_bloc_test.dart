import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:amaia/pages/ble_button/bloc/ble_button_bloc.dart';
import 'package:amaia/pages/ble_button/data/ble_button_repository.dart';
import 'package:amaia/pages/ble_button/domain/models.dart';

class MockBleButtonRepository extends Mock implements BleButtonRepository {}

void main() {
  late MockBleButtonRepository repository;

  setUp(() {
    repository = MockBleButtonRepository();
    when(() => repository.onDeviceScanned)
        .thenAnswer((_) => const Stream.empty());
    when(() => repository.onConnectionStatusChanged)
        .thenAnswer((_) => const Stream.empty());
    when(() => repository.onButtonPress)
        .thenAnswer((_) => const Stream.empty());
    when(() => repository.onTaskResult)
        .thenAnswer((_) => const Stream.empty());
  });

  group('BleButtonBloc', () {
    group('ScanStarted', () {
      blocTest<BleButtonBloc, BleButtonState>(
        'emits [BleButtonScanning] when scan starts successfully',
        setUp: () {
          when(() => repository.startScan()).thenAnswer((_) async {});
        },
        build: () => BleButtonBloc(repository: repository),
        act: (bloc) => bloc.add(const ScanStarted()),
        expect: () => [const BleButtonScanning()],
      );

      blocTest<BleButtonBloc, BleButtonState>(
        'emits [BleButtonError] when scan fails',
        setUp: () {
          when(() => repository.startScan()).thenThrow(
            const BleButtonException(code: 'BT_DISABLED', message: 'BT off'),
          );
        },
        build: () => BleButtonBloc(repository: repository),
        act: (bloc) => bloc.add(const ScanStarted()),
        expect: () => [const BleButtonError(message: 'BT off')],
      );
    });

    group('ScanStopped', () {
      blocTest<BleButtonBloc, BleButtonState>(
        'emits [BleButtonDisconnected] when scan stops',
        setUp: () {
          when(() => repository.stopScan()).thenAnswer((_) async {});
        },
        build: () => BleButtonBloc(repository: repository),
        seed: () => const BleButtonScanning(),
        act: (bloc) => bloc.add(const ScanStopped()),
        expect: () => [const BleButtonDisconnected()],
      );
    });

    group('DeviceConnectRequested', () {
      blocTest<BleButtonBloc, BleButtonState>(
        'emits [BleButtonConnecting] with provided mac',
        setUp: () {
          when(() => repository.stopScan()).thenAnswer((_) async {});
          when(() => repository.connect(any())).thenAnswer((_) async {});
        },
        build: () => BleButtonBloc(repository: repository),
        act: (bloc) => bloc.add(
          const DeviceConnectRequested(mac: 'AA:BB:CC:DD:EE:FF'),
        ),
        expect: () => [
          const BleButtonConnecting(mac: 'AA:BB:CC:DD:EE:FF'),
        ],
      );
    });

    group('AdvIntervalUpdateRequested', () {
      blocTest<BleButtonBloc, BleButtonState>(
        'calls setAdvInterval and emits loading then done state',
        setUp: () {
          when(() => repository.setAdvInterval(any())).thenAnswer((_) async {});
        },
        build: () => BleButtonBloc(repository: repository),
        seed: () => const BleButtonConnected(mac: 'AA:BB:CC:DD:EE:FF'),
        act: (bloc) => bloc.add(
          const AdvIntervalUpdateRequested(intervalMs: 1000),
        ),
        verify: (_) {
          verify(() => repository.setAdvInterval(1000)).called(1);
        },
      );
    });

    group('DeviceResetRequested', () {
      blocTest<BleButtonBloc, BleButtonState>(
        'calls resetDevice on repository',
        setUp: () {
          when(() => repository.resetDevice()).thenAnswer((_) async {});
        },
        build: () => BleButtonBloc(repository: repository),
        seed: () => const BleButtonConnected(mac: 'AA:BB:CC:DD:EE:FF'),
        act: (bloc) => bloc.add(const DeviceResetRequested()),
        verify: (_) {
          verify(() => repository.resetDevice()).called(1);
        },
      );
    });
  });
}
