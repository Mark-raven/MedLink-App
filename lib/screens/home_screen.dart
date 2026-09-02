import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../services/permission_service.dart';
import '../ble/ble_service.dart';

import '../models/medicine.dart';
import 'medicine_screen.dart';
import '../services/storage_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final PermissionService permissionService = PermissionService();
  final BleService bleService = BleService();
  final StorageService storageService = StorageService();

  List<BluetoothDevice> devices = [];

  Medicine? medicine;

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

    if (medicine == null) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please add a medicine first")),
      );

      return;
    }

    await bleService.sendSchedule(
      device,
      medicine!.hour,
      medicine!.minute,
      medicine!.name,
    );

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
  void initState() {
    super.initState();
    loadSavedMedicine();
  }

  Future<void> loadSavedMedicine() async {
    final Medicine? savedMedicine = await storageService.loadMedicine();

    if (!mounted) return;

    setState(() {
      medicine = savedMedicine;
    });
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
              final Medicine? result = await Navigator.push<Medicine>(
                context,
                MaterialPageRoute(builder: (context) => const MedicineScreen()),
              );

              if (result != null) {
                setState(() {
                  medicine = result;
                });

                await storageService.saveMedicine(result);

                debugPrint(
                  "Medicine selected: ${medicine!.name} "
                  "${medicine!.hour.toString().padLeft(2, '0')}:"
                  "${medicine!.minute.toString().padLeft(2, '0')}",
                );
              }
            },
            child: const Text("Add Medicine"),
          ),

          if (medicine != null)
            ListTile(
              leading: const Icon(Icons.medication),
              title: Text(medicine!.name),
              subtitle: Text(
                "${medicine!.hour.toString().padLeft(2, '0')}:"
                "${medicine!.minute.toString().padLeft(2, '0')}",
              ),
            ),

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

                    if (medicine != null) {
                      await bleService.sendSchedule(
                        device,
                        medicine!.hour,
                        medicine!.minute,
                        medicine!.name,
                      );
                    }

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
