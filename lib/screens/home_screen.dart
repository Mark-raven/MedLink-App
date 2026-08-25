import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../services/permission_service.dart';
import '../ble/ble_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final PermissionService permissionService = PermissionService();
  final BleService bleService = BleService();

  List<BluetoothDevice> devices = [];

  Future<void> scanDevices() async {
    devices = await bleService.scanDevices();
    setState(() {});
  }

  Future<void> selectReminderTime(BluetoothDevice device) async {
    final TimeOfDay? selectedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (selectedTime == null) {
      return;
    }

    print(
      "Selected Reminder Time: "
      "${selectedTime.hour.toString().padLeft(2, '0')}:"
      "${selectedTime.minute.toString().padLeft(2, '0')}",
    );

    await bleService.sendSchedule(device, 1, 46, "Vitamin D");

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          "Reminder set for "
          "${selectedTime.hour.toString().padLeft(2, '0')}:"
          "${selectedTime.minute.toString().padLeft(2, '0')}",
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("MedLink")),

      body: Column(
        children: [
          const SizedBox(height: 20),

          ElevatedButton(
            onPressed: () async {
              bool granted = await permissionService.requestPermissions();

              if (!granted) {
                debugPrint("Permission Denied");
                return;
              }

              debugPrint("Scanning...");

              await scanDevices();
            },
            child: const Text("Scan Devices"),
          ),

          Expanded(
            child: ListView.builder(
              itemCount: devices.length,

              itemBuilder: (context, index) {
                final device = devices[index];

                return ListTile(
                  title: Text(
                    device.platformName.isEmpty
                        ? "Unknown Device"
                        : device.platformName,
                  ),

                  subtitle: Text(device.remoteId.str),

                  trailing: const Icon(Icons.bluetooth),

                  onTap: () async {
                    bool connected = await bleService.connectToDevice(device);

                    if (!connected) {
                      if (!context.mounted) return;

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Connection Failed")),
                      );

                      return;
                    }

                    // Synchronize watch time
                    await bleService.sendTime(device);

                    await Future.delayed(const Duration(milliseconds: 500));

                    // Ask user for reminder time
                    await selectReminderTime(device);

                    if (!context.mounted) return;

                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(const SnackBar(content: Text("Connected")));
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
