import 'dart:async';
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
  StreamSubscription<List<BluetoothDevice>>? scanResultsSubscription;

  List<BluetoothDevice> devices = [];

  List<Medicine> medicines = [];

  bool isScanning = false;

  Future<void> scanDevices() async {
    if (isScanning) return;

    setState(() {
      isScanning = true;
      devices = [];
    });

    try {
      await bleService.startScan();

      // Wait for the automatic 5-second scan timeout.
      await Future.delayed(const Duration(seconds: 5));

      final scannedDevices = await bleService.stopScan();

      if (!mounted) return;

      setState(() {
        devices = scannedDevices;
        isScanning = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isScanning = false;
      });

      debugPrint("Scan failed: $e");

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to scan for devices")),
      );
    }
  }

  Future<void> stopScanning() async {
    if (!isScanning) return;

    final scannedDevices = await bleService.stopScan();

    if (!mounted) return;

    setState(() {
      devices = scannedDevices;
      isScanning = false;
    });

    debugPrint("Scanning stopped by user");
  }

  @override
  void initState() {
    super.initState();

    loadSavedMedicines();

    scanResultsSubscription = bleService.scanResultsStream.listen((
      scannedDevices,
    ) {
      if (!mounted) return;

      setState(() {
        devices = scannedDevices;
      });
    });
  }

  @override
  void dispose() {
    scanResultsSubscription?.cancel();
    super.dispose();
  }

  Future<void> loadSavedMedicines() async {
    final List<Medicine> savedMedicines = await storageService.loadMedicines();

    if (!mounted) return;

    setState(() {
      medicines = savedMedicines;
    });
  }

  Future<void> deleteMedicine(int index) async {
    final Medicine medicine = medicines[index];

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Delete Medicine?"),
          content: Text('Are you sure you want to delete "${medicine.name}"?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: const Text("Delete"),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    setState(() {
      medicines.removeAt(index);
    });

    await storageService.saveMedicines(medicines);

    debugPrint("Medicine deleted: ${medicine.name}");
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
              children: medicines.asMap().entries.map((entry) {
                final int index = entry.key;
                final Medicine medicine = entry.value;
                return ListTile(
                  leading: const Icon(Icons.medication),
                  title: Text(medicine.name),
                  subtitle: Text(
                    "${medicine.hour.toString().padLeft(2, '0')}:"
                    "${medicine.minute.toString().padLeft(2, '0')}",
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: "Delete medicine",
                    onPressed: () => deleteMedicine(index),
                  ),
                );
              }).toList(),
            ),

          ElevatedButton(
            onPressed: isScanning
                ? stopScanning
                : () async {
                    bool granted = await permissionService.requestPermissions();

                    if (!granted) {
                      debugPrint("Permission Denied");

                      if (!context.mounted) return;

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            "Bluetooth permissions are required to scan.",
                          ),
                        ),
                      );

                      return;
                    }

                    debugPrint("Scanning...");
                    await scanDevices();
                  },
            child: isScanning
                ? const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 10),
                      Text("Stop Scanning"),
                    ],
                  )
                : const Text("Scan Devices"),
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
