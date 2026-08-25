import 'package:flutter/material.dart';

import '../models/medicine.dart';

class MedicineScreen extends StatefulWidget {
  const MedicineScreen({super.key});

  @override
  State<MedicineScreen> createState() => _MedicineScreenState();
}

class _MedicineScreenState extends State<MedicineScreen> {
  final TextEditingController medicineController = TextEditingController();

  TimeOfDay? selectedTime;

  Future<void> selectTime() async {
    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (pickedTime != null) {
      setState(() {
        selectedTime = pickedTime;
      });
    }
  }

  void saveMedicine() {
    final String name = medicineController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a medicine name")),
      );
      return;
    }

    if (selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a reminder time")),
      );
      return;
    }

    final Medicine medicine = Medicine(
      name: name,
      hour: selectedTime!.hour,
      minute: selectedTime!.minute,
    );

    debugPrint(
      "Medicine: ${medicine.name}, "
      "Time: ${medicine.hour.toString().padLeft(2, '0')}:"
      "${medicine.minute.toString().padLeft(2, '0')}",
    );

    Navigator.pop(context, medicine);
  }

  @override
  void dispose() {
    medicineController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Add Medicine")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: medicineController,
              decoration: const InputDecoration(
                labelText: "Medicine Name",
                hintText: "Example: Vitamin D",
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 20),

            ListTile(
              title: const Text("Reminder Time"),
              subtitle: Text(
                selectedTime == null
                    ? "No time selected"
                    : selectedTime!.format(context),
              ),
              trailing: const Icon(Icons.access_time),
              onTap: selectTime,
            ),

            const SizedBox(height: 30),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: saveMedicine,
                child: const Text("Save Medicine"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
