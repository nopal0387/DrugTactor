import 'package:flutter/material.dart';

class MedicationDetailScreen extends StatelessWidget {
  final Map<String, dynamic> medicationData;

  const MedicationDetailScreen({super.key, required this.medicationData});

  @override
  Widget build(BuildContext context) {
    // Extract data safely
    String rawText = medicationData['rawText'] ?? 'No raw text available.';
    String aiSummary = medicationData['aiSummary'] ?? 'No AI summary available.';
    
    // Get the title from the first line of the raw text
    String title = 'Medication Details';
    if (rawText.contains('\n')) {
      title = rawText.split('\n').first.trim();
    } else {
      title = rawText.trim();
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // AI Summary Section
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
                        'AI Medical Summary',
                        style: TextStyle(
                          fontSize: 18, 
                          fontWeight: FontWeight.bold, 
                          color: Colors.teal
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    aiSummary,
                    style: const TextStyle(fontSize: 16, height: 1.5, color: Colors.black87),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),

            // Raw Text Section
            const Row(
              children: [
                Icon(Icons.document_scanner, color: Colors.grey),
                SizedBox(width: 8),
                Text(
                  'Scanned Label Text (OCR)',
                  style: TextStyle(
                    fontSize: 18, 
                    fontWeight: FontWeight.bold, 
                    color: Colors.black54
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                rawText,
                style: const TextStyle(fontSize: 14, color: Colors.black87),
              ),
            ),
          ],
        ),
      ),
    );
  }
}