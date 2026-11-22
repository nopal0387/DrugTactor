import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'main.dart'; // For colors

class MedicationDetailScreen extends StatelessWidget {
  final Map<String, dynamic> medicationData;
  final String docId;   // 👈 Received from Dashboard
  final String userId;  // 👈 Received from Dashboard

  const MedicationDetailScreen({
    super.key, 
    required this.medicationData,
    required this.docId,
    required this.userId,
  });

  // 🗑️ DELETE FUNCTION
  Future<void> _deleteMedication(BuildContext context) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Delete Medication?'),
          content: const Text('Are you sure you want to remove this medication from your list?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel', style: TextStyle(color: kTextLight)),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('medications')
            .doc(docId)
            .delete();
        
        if (context.mounted) {
          Navigator.pop(context); // Go back to Dashboard after deletion
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Medication deleted successfully.'), backgroundColor: kTeal),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    String aiSummary = medicationData['aiSummary'] ?? 'No AI summary available.';
    
    // Parse the AI text
    String name = "Medication Details";
    String dosage = "Take as directed";
    String instructions = "Check packaging for details";
    
    if (aiSummary.contains('Name:')) name = aiSummary.split('Name:')[1].split('\n')[0].trim();
    if (aiSummary.contains('Dosage:')) dosage = aiSummary.split('Dosage:')[1].split('\n')[0].trim();
    if (aiSummary.contains('Instructions:')) instructions = aiSummary.split('Instructions:')[1].split('\n')[0].trim();

    return Scaffold(
      backgroundColor: kBgColor,
      appBar: AppBar(
        backgroundColor: kTeal,
        foregroundColor: Colors.white,
        title: const Text('Medication details', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.only(bottomLeft: Radius.circular(20), bottomRight: Radius.circular(20))),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Main Info Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)]),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: kTeal.withOpacity(0.1), borderRadius: BorderRadius.circular(16)),
                    child: const Icon(Icons.medication, color: kTeal, size: 32),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kTextDark)),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: kBgColor, borderRadius: BorderRadius.circular(8)),
                          child: const Text('Timely brand', style: TextStyle(fontSize: 12, color: kTextLight, fontWeight: FontWeight.bold)),
                        )
                      ],
                    ),
                  )
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Dosage Card
            _buildInfoCard(
              icon: Icons.access_time,
              title: 'How often',
              content: dosage,
              extraWidgets: [
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildPill('8:00 AM'), const SizedBox(width: 8),
                    _buildPill('2:00 PM'), const SizedBox(width: 8),
                    _buildPill('8:00 PM'),
                  ],
                )
              ],
            ),
            const SizedBox(height: 16),

            // Instructions Card
            _buildInfoCard(
              icon: Icons.restaurant,
              title: 'How to take it',
              content: instructions,
            ),
            const SizedBox(height: 16),

            // Warning Box
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: const Color(0xFFFFF4E5), borderRadius: BorderRadius.circular(16)),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.orange),
                  const SizedBox(width: 12),
                  Expanded(child: Text('Dosage limits differ for children and adults. Always check the side panel.', style: TextStyle(color: Colors.orange.shade900, fontSize: 13))),
                ],
              ),
            ),
            const SizedBox(height: 30),

            // Footer Text
            const Center(child: Text('AI-generated summary. Please confirm with your pharmacist.', style: TextStyle(color: kTextLight, fontSize: 12))),
            const SizedBox(height: 16),

            // 🗑️ DELETE BUTTON (Matches Image 5)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _deleteMedication(context),
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                label: const Text('Delete medication', style: TextStyle(color: Colors.red, fontSize: 16, fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.red, width: 1.5),
                  minimumSize: const Size.fromHeight(55),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard({required IconData icon, required String title, required String content, List<Widget>? extraWidgets}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: kTeal, size: 20),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: kTextDark, fontSize: 15)),
            ],
          ),
          const SizedBox(height: 12),
          Text(content, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: kTextDark)),
          if (extraWidgets != null) ...extraWidgets,
        ],
      ),
    );
  }

  Widget _buildPill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: kTeal.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
      child: Text(text, style: const TextStyle(color: kTeal, fontWeight: FontWeight.bold, fontSize: 13)),
    );
  }
}