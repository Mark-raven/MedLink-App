import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../models/medicine.dart';

const String MEDLINK_SERVICE_UUID = "12345678-1234-5678-1234-56789abcdef0";

const String MEDLINK_RX_UUID = "12345678-1234-5678-1234-56789abcdef1";

const String MEDLINK_TX_UUID = "12345678-1234-5678-1234-56789abcdef2";

class BleService {
  StreamSubscription<List<int>>? notificationSubscription;
  StreamSubscription<List<ScanResult>>? scanSubscription;

  final StreamController<List<BluetoothDevice>> scanResultsController =
      StreamController<List<BluetoothDevice>>.broadcast();

  Stream<List<BluetoothDevice>> get scanResultsStream =>
      scanResultsController.stream;

  BluetoothCharacteristic? rxChar;
  BluetoothCharacteristic? txChar;

  bool isScanning = false;

  final List<BluetoothDevice> scannedDevices = [];

  Future<void> startScan() async {
    if (isScanning) return;

    isScanning = true;
    scannedDevices.clear();

    await scanSubscription?.cancel();

    scanSubscription = FlutterBluePlus.scanResults.listen((results) {
      for (final result in results) {
        if (!scannedDevices.any(
          (device) => device.remoteId == result.device.remoteId,
        )) {
          scannedDevices.add(result.device);

          scanResultsController.add(List<BluetoothDevice>.from(scannedDevices));
        }
      }
    });

    try {
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));
    } catch (e) {
      print("Scan failed: $e");

      await scanSubscription?.cancel();
      scanSubscription = null;

      isScanning = false;

      rethrow;
    }
  }

  Future<List<BluetoothDevice>> stopScan() async {
    if (!isScanning) {
      return List<BluetoothDevice>.from(scannedDevices);
    }

    try {
      await FlutterBluePlus.stopScan();
    } catch (e) {
      print("Stop scan error: $e");
    }

    await scanSubscription?.cancel();
    scanSubscription = null;

    isScanning = false;

    return List<BluetoothDevice>.from(scannedDevices);
  }

  Future<void> dispose() async {
    await scanSubscription?.cancel();
    await notificationSubscription?.cancel();
    await scanResultsController.close();
  }

  Future<bool> connectToDevice(BluetoothDevice device) async {
    try {
      await FlutterBluePlus.stopScan();
    } catch (_) {}

    try {
      await device.disconnect();
    } catch (_) {}

    try {
      await device.connect(timeout: const Duration(seconds: 10));

      print("Connected to ${device.platformName}");

      // Discover services once
      List<BluetoothService> services = await device.discoverServices();

      for (BluetoothService service in services) {
        if (service.uuid.toString().toLowerCase() == MEDLINK_SERVICE_UUID) {
          for (BluetoothCharacteristic characteristic
              in service.characteristics) {
            print("Characteristic: ${characteristic.uuid}");

            if (characteristic.uuid.toString().toLowerCase() ==
                MEDLINK_RX_UUID) {
              rxChar = characteristic;
            }

            if (characteristic.uuid.toString().toLowerCase() ==
                MEDLINK_TX_UUID) {
              txChar = characteristic;
            }
          }
        }
      }

      print("RX = ${rxChar?.uuid}");
      print("TX = ${txChar?.uuid}");

      if (txChar != null) {
        await txChar!.setNotifyValue(true);

        notificationSubscription = txChar!.onValueReceived.listen((value) {
          print("Received: ${String.fromCharCodes(value)}");
        });
      }

      return true;
    } catch (e) {
      print("Connection Failed: $e");
      return false;
    }
  }

  Future<void> sendMessage(BluetoothDevice device, String message) async {
    List<BluetoothService> services = await device.discoverServices();

    for (BluetoothService service in services) {
      if (service.uuid.toString().toLowerCase() == MEDLINK_SERVICE_UUID) {
        for (BluetoothCharacteristic characteristic
            in service.characteristics) {
          print("Characteristic: ${characteristic.uuid}");

          if (characteristic.uuid.toString().toLowerCase() == MEDLINK_RX_UUID) {
            rxChar = characteristic;
          }

          if (characteristic.uuid.toString().toLowerCase() == MEDLINK_TX_UUID) {
            txChar = characteristic;
          }
        }
      }
    }

    print("RX Characteristic = ${rxChar?.uuid}");
    print("TX Characteristic = ${txChar?.uuid}");

    if (txChar != null) {
      if (notificationSubscription == null) {
        await txChar!.setNotifyValue(true);

        print("Enabling notifications on ${txChar!.uuid}");

        notificationSubscription = txChar!.lastValueStream.listen((value) {
          //if (value.isEmpty) return;

          print("Received: ${String.fromCharCodes(value)}");
        });

        await txChar!.setNotifyValue(true);
      }
    } else {
      print("TX Characteristic not found");
    }

    if (rxChar != null) {
      const int CMD_PING = 0x01;

      await rxChar!.write([CMD_PING]);

      print("Sent: $message");
    } else {
      print("RX Characteristic not found");
    }
  }

  Future<void> sendPacket(BluetoothDevice device, List<int> packet) async {
    BluetoothCharacteristic? rxChar;

    List<BluetoothService> services = await device.discoverServices();

    for (BluetoothService service in services) {
      if (service.uuid.toString().toLowerCase() == MEDLINK_SERVICE_UUID) {
        for (BluetoothCharacteristic characteristic
            in service.characteristics) {
          if (characteristic.uuid.toString().toLowerCase() == MEDLINK_RX_UUID) {
            rxChar = characteristic;
            break;
          }
        }
      }
    }

    if (rxChar == null) {
      print("RX Characteristic not found");
      return;
    }

    await rxChar.write(packet);

    print("Packet Sent: $packet");
  }

  Future<void> sendTime(BluetoothDevice device) async {
    final now = DateTime.now();

    List<int> packet = [
      0x02, // CMD_TIME_SYNC
      (now.year >> 8) & 0xFF, // Year High
      now.year & 0xFF, // Year Low
      now.month,
      now.day,
      now.hour,
      now.minute,
      now.second,
    ];

    BluetoothCharacteristic? rxChar;

    List<BluetoothService> services = await device.discoverServices();

    for (BluetoothService service in services) {
      if (service.uuid.toString().toLowerCase() == MEDLINK_SERVICE_UUID) {
        for (BluetoothCharacteristic characteristic
            in service.characteristics) {
          if (characteristic.uuid.toString().toLowerCase() == MEDLINK_RX_UUID) {
            rxChar = characteristic;
          }
        }
      }
    }
    if (rxChar != null) {
      await rxChar.write(packet);

      print("Time Packet Sent");
    } else {
      print("RX Characteristic not found");
    }
  }

  Future<void> sendSchedule(
    BluetoothDevice device,
    int hour,
    int minute,
    String medicineName,
  ) async {
    List<int> packet = [0x03, hour, minute, ...medicineName.codeUnits];

    await sendPacket(device, packet);

    print(
      "Schedule Packet Sent: "
      "$medicineName at "
      "${hour.toString().padLeft(2, '0')}:"
      "${minute.toString().padLeft(2, '0')}",
    );
  }

  Future<void> sendAllSchedules(
    BluetoothDevice device,
    List<Medicine> medicines,
  ) async {
    for (final medicine in medicines) {
      await sendSchedule(device, medicine.hour, medicine.minute, medicine.name);

      await Future.delayed(const Duration(milliseconds: 200));
    }

    print("All schedules sent: ${medicines.length}");
  }

  Future<void> testReminder(BluetoothDevice device) async {
    final now = DateTime.now();

    // Set reminder 2 minutes from now
    final reminderTime = now.add(const Duration(minutes: 2));

    print(
      "Setting test reminder: "
      "${reminderTime.hour.toString().padLeft(2, '0')}:"
      "${reminderTime.minute.toString().padLeft(2, '0')}",
    );

    await sendSchedule(
      device,
      reminderTime.hour,
      reminderTime.minute,
      "Vitamin D",
    );
  }

  Future<void> clearSchedule(BluetoothDevice device) async {
    final List<int> packet = [0x07];

    await sendPacket(device, packet);
  }

  Future<void> disconnectDevice(BluetoothDevice device) async {
    await notificationSubscription?.cancel();
    notificationSubscription = null;

    await device.disconnect();
  }
}
