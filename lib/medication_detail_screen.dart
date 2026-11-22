import 'package:flutter/material.dart';

class MedicationDetailScreen extends StatelessWidget {
  final Map<String, dynamic> medicationData;

  const MedicationDetailScreen({super.key, required this.medicationData});

  @override
  Widget build(BuildContext context) {
    String aiSummary = medicationData['aiSummary'] ?? 'No AI summary available.';
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Medication Details'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.teal.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.teal, width: 1.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.smart_toy, color: Colors.teal),
                      SizedBox(width: 8),
                      Text(
                        'Claude AI Analysis',
                        style: TextStyle(
                          fontSize: 18, 
                          fontWeight: FontWeight.bold, 
                          color: Colors.teal
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    aiSummary,
                    style: const TextStyle(fontSize: 16, height: 1.6, color: Colors.black87),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}