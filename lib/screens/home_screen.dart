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
  // Create the object here
  final PermissionService permissionService = PermissionService();

  final BleService bleService = BleService();

  List<BluetoothDevice> devices = [];

  Future<void> scanDevices() async {
    devices = await bleService.scanDevices();

    setState(() {});
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

                    await bleService.sendTime(device);

                    await Future.delayed(const Duration(milliseconds: 500));

                    await bleService.sendSchedule(device, 01, 37);

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
