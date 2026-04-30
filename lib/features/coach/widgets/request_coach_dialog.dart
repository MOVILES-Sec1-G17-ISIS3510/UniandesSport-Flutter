import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class RequestCoachDialog extends StatefulWidget {
  const RequestCoachDialog({Key? key}) : super(key: key);

  @override
  State<RequestCoachDialog> createState() => _RequestCoachDialogState();
}

class _RequestCoachDialogState extends State<RequestCoachDialog> {
  String sport = "Soccer";
  String skillLevel = "Beginner";
  bool isSubmitting = false;

  DateTime? selectedSchedule;
  final notesController = TextEditingController();

  Future<void> _pickSchedule() async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: selectedSchedule ?? now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (pickedDate == null || !mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(selectedSchedule ?? now),
    );
    if (pickedTime == null || !mounted) return;

    setState(() {
      selectedSchedule = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
    });
  }

  String _formatSchedule(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final hour12 = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return "${months[dt.month - 1]} ${dt.day}, ${dt.year} · $hour12:$minute $period";
  }

  Future<void> _submit() async {
    if (selectedSchedule == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a preferred schedule")),
      );
      return;
    }

    setState(() => isSubmitting = true);

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;

      await FirebaseFirestore.instance.collection('coach_requests').add({
        'userId': uid,
        'sport': sport,
        'skillLevel': skillLevel,
        'schedule': Timestamp.fromDate(selectedSchedule!),
        'notes': notesController.text.trim(),
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.teal,
          content: Text("Request sent successfully"),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error sending request: $e")),
      );
    } finally {
      if (mounted) setState(() => isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: SingleChildScrollView(
        child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            /// HEADER
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "REQUEST COACH",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),

            const SizedBox(height: 10),

            /// SPORT
            Align(
              alignment: Alignment.centerLeft,
              child: Text("Sport", style: TextStyle(color: Colors.grey.shade700)),
            ),
            const SizedBox(height: 5),
            DropdownButtonFormField<String>(
              initialValue: sport,
              decoration: _inputDecoration(),
              items: ["Soccer", "Tennis", "Basketball"]
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (value) => setState(() => sport = value!),
            ),

            const SizedBox(height: 15),

            /// SKILL LEVEL
            Align(
              alignment: Alignment.centerLeft,
              child: Text("Skill Level", style: TextStyle(color: Colors.grey.shade700)),
            ),
            const SizedBox(height: 5),
            DropdownButtonFormField<String>(
              initialValue: skillLevel,
              decoration: _inputDecoration(),
              items: ["Beginner", "Intermediate", "Advanced"]
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (value) => setState(() => skillLevel = value!),
            ),

            const SizedBox(height: 15),

            /// SCHEDULE
            Align(
              alignment: Alignment.centerLeft,
              child: Text("Preferred Schedule", style: TextStyle(color: Colors.grey.shade700)),
            ),
            const SizedBox(height: 5),
            InkWell(
              onTap: _pickSchedule,
              borderRadius: BorderRadius.circular(12),
              child: InputDecorator(
                decoration: _inputDecoration().copyWith(
                  suffixIcon: const Icon(Icons.calendar_today, color: Colors.teal, size: 20),
                ),
                child: Text(
                  selectedSchedule != null
                      ? _formatSchedule(selectedSchedule!)
                      : "Select a date and time",
                  style: TextStyle(
                    color: selectedSchedule != null
                        ? Colors.black
                        : Colors.grey.shade600,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 15),

            /// NOTES
            Align(
              alignment: Alignment.centerLeft,
              child: Text("Notes", style: TextStyle(color: Colors.grey.shade700)),
            ),
            const SizedBox(height: 5),
            TextField(
              controller: notesController,
              maxLines: 3,
              decoration: _inputDecoration(hint: "Anything specific you're looking for..."),
            ),

            const SizedBox(height: 20),

            /// BUTTONS
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: BorderSide(color: Colors.grey.shade400),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text("Cancel"),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: isSubmitting ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: const Color(0xFF2E7D74),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: isSubmitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text("Submit"),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
        ),
    );
  }

  InputDecoration _inputDecoration({String? hint}) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Colors.grey.shade100,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
    );
  }
}
