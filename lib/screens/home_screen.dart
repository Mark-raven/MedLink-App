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

  List<Medicine> medicines = [];

  Future<void> scanDevices() async {
    devices = await bleService.scanDevices();
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    loadSavedMedicines();
  }

  Future<void> loadSavedMedicines() async {
    final List<Medicine> savedMedicines = await storageService.loadMedicines();

    if (!mounted) return;

    setState(() {
      medicines = savedMedicines;
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
                  medicines.add(result);
                });

                await storageService.saveMedicines(medicines);

                debugPrint(
                  "Medicine added: ${result.name} "
                  "${result.hour.toString().padLeft(2, '0')}:"
                  "${result.minute.toString().padLeft(2, '0')}",
                );
              }
            },
            child: const Text("Add Medicine"),
          ),

          if (medicines.isEmpty)
            const ListTile(
              leading: Icon(Icons.medication_outlined),
              title: Text("No medicines added"),
            )
          else
            Column(
              children: medicines.map((medicine) {
                return ListTile(
                  leading: const Icon(Icons.medication),
                  title: Text(medicine.name),
                  subtitle: Text(
                    "${medicine.hour.toString().padLeft(2, '0')}:"
                    "${medicine.minute.toString().padLeft(2, '0')}",
                  ),
                );
              }).toList(),
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

                    await bleService.sendTime(device);

                    await Future.delayed(const Duration(milliseconds: 500));

                    await bleService.clearSchedule(device);

                    await Future.delayed(const Duration(milliseconds: 200));

                    await bleService.sendAllSchedules(device, medicines);

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
