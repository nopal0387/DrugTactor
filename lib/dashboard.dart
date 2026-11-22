import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'scanner_screen.dart';
import 'medication_detail_screen.dart';
import 'main.dart'; // For colors

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: kTeal,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('My Medications', style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.logout, color: Colors.white),
                    onPressed: () async {
                      await FirebaseAuth.instance.signOut();
                      if (context.mounted) Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const LoginScreen()), (route) => false);
                    },
                  )
                ],
              ),
            ),
            
            // White Body
            Expanded(
              child: Container(
                decoration: const BoxDecoration(color: kBgColor, borderRadius: BorderRadius.only(topLeft: Radius.circular(40), topRight: Radius.circular(40))),
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('users').doc(user!.uid).collection('medications').orderBy('timestamp', descending: true).snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: kTeal));
                    
                    final meds = snapshot.data?.docs ?? [];

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                          child: Row(
                            children: [
                              const Text('Saved medicines', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kTextDark)),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(color: kTeal.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
                                child: Text('${meds.length}', style: const TextStyle(color: kTeal, fontWeight: FontWeight.bold, fontSize: 12)),
                              )
                            ],
                          ),
                        ),
                        
                        Expanded(
                          child: meds.isEmpty
                              ? Center(child: Text('No medicines saved yet.', style: TextStyle(color: kTextLight, fontSize: 16)))
                              : ListView.builder(
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                                  itemCount: meds.length,
                                  itemBuilder: (context, index) {
                                    final medData = meds[index].data() as Map<String, dynamic>;
                                    String aiSummary = medData['aiSummary'] ?? 'No summary';
                                    
                                    String name = "Unknown Medicine";
                                    String function = "Tap to view details";
                                    
                                    if (aiSummary.contains('Name:')) name = aiSummary.split('Name:')[1].split('\n')[0].trim();
                                    if (aiSummary.contains('Function:')) function = aiSummary.split('Function:')[1].split('\n')[0].trim();

                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 16),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(20),
                                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
                                      ),
                                      child: ListTile(
                                        contentPadding: const EdgeInsets.all(16),
                                        leading: Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(color: kTeal.withOpacity(0.1), borderRadius: BorderRadius.circular(14)),
                                          child: const Icon(Icons.medication, color: kTeal),
                                        ),
                                        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: kTextDark)),
                                        subtitle: Padding(
                                          padding: const EdgeInsets.only(top: 4.0),
                                          child: Text(function, style: const TextStyle(color: kTextLight, fontSize: 13)),
                                        ),
                                        trailing: const Icon(Icons.chevron_right, color: kTextLight),
                                        // 👇 Pass docId and userId to Detail Screen
                                        onTap: () => Navigator.push(
                                          context, 
                                          MaterialPageRoute(
                                            builder: (context) => MedicationDetailScreen(
                                              medicationData: medData,
                                              docId: meds[index].id,
                                              userId: user.uid,
                                            )
                                          )
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ),
                        
                        // Floating Scan Button Area
                        Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Center(
                            child: SizedBox(
                              height: 55,
                              child: ElevatedButton.icon(
                                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ScannerScreen())),
                                icon: const Icon(Icons.camera_alt),
                                label: const Text('Scan label', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: kTeal, foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                                  padding: const EdgeInsets.symmetric(horizontal: 32),
                                ),
                              ),
                            ),
                          ),
                        )
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}