import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart' as img_picker;
import 'package:openai_dart/openai_dart.dart' hide Container;
import 'secrets.dart';
import 'main.dart'; // For colors

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});
  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isProcessing = false;
  String _aiSummary = "";
  bool _hasScanned = false;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    _cameras = await availableCameras();
    if (_cameras!.isNotEmpty) {
      _cameraController = CameraController(_cameras![0], ResolutionPreset.high);
      await _cameraController!.initialize();
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  Future<void> _processImage(File imageFile) async {
    setState(() { 
      _isProcessing = true; 
      _hasScanned = true; 
      _aiSummary = "Analyzing image..."; 
    });
    
    try {
      final bytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(bytes);
      final client = OpenAIClient(config: OpenAIConfig(authProvider: ApiKeyProvider(groqApiKey), baseUrl: 'https://api.groq.com/openai/v1'));
      
      final prompt = """
      Analyze this medicine image. Provide the summary in EXACTLY this format, one per line:
      Name: [Medicine Name]
      Function: [What it is used for, max 5 words]
      Dosage: [How often]
      Instructions: [How to take it]
      """;

      final response = await client.chat.completions.create(
        ChatCompletionCreateRequest(
          model: 'qwen/qwen3.8-27b',
          maxTokens: 300,
          messages: [ChatMessage.user([ContentPart.text(prompt), ContentPart.imageBase64(data: base64Image, mediaType: 'image/jpeg')])],
        ),
      );

      setState(() => _aiSummary = response.choices.first.message.content ?? "Error reading image.");
    } catch (e) {
      setState(() => _aiSummary = "Error: $e");
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _takePicture() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;
    final pic = await _cameraController!.takePicture();
    _processImage(File(pic.path));
  }

  Future<void> _pickGallery() async {
    final image = await img_picker.ImagePicker().pickImage(source: img_picker.ImageSource.gallery);
    if (image != null) _processImage(File(image.path));
  }

  Future<void> _saveToDatabase() async {
    if (_aiSummary.contains("Error")) return;
    setState(() => _isProcessing = true);
    try {
      await FirebaseFirestore.instance.collection('users').doc(FirebaseAuth.instance.currentUser!.uid).collection('medications').add({
        'aiSummary': _aiSummary,
        'timestamp': FieldValue.serverTimestamp(),
      });
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 👇 Change background based on whether we are showing the camera or results
      backgroundColor: _hasScanned ? kBgColor : const Color(0xFF0F172A),
      appBar: _hasScanned 
        ? AppBar(
            backgroundColor: kTeal,
            foregroundColor: Colors.white,
            title: const Text('AI Scan Results', style: TextStyle(fontWeight: FontWeight.bold)),
            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.only(bottomLeft: Radius.circular(20), bottomRight: Radius.circular(20))),
          )
        : null,
      // 👇 Switch entire body layout based on state
      body: _hasScanned ? _buildResultUI() : _buildCameraUI(),
    );
  }

  // ==========================================
  // 📷 CAMERA UI
  // ==========================================
  Widget _buildCameraUI() {
    return Stack(
      children: [
        // Camera Preview
        if (_cameraController != null && _cameraController!.value.isInitialized)
          Positioned.fill(child: CameraPreview(_cameraController!)),

        // Top App Bar (Overlay)
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CircleAvatar(backgroundColor: Colors.white.withOpacity(0.2), child: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context))),
                const Text('Scan medication', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                CircleAvatar(backgroundColor: Colors.white.withOpacity(0.2), child: IconButton(icon: const Icon(Icons.photo_library, color: Colors.white), onPressed: _pickGallery)),
              ],
            ),
          ),
        ),

        // Camera Frame Overlay
        Center(
          child: Container(
            width: 280, height: 180,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.tealAccent.withOpacity(0.5), width: 2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Center(child: Text('Align label here', style: TextStyle(color: Colors.white54))),
          ),
        ),

        // Bottom Controls
        Positioned(
          bottom: 0, left: 0, right: 0,
          child: Container(
            padding: const EdgeInsets.only(top: 30, bottom: 50, left: 24, right: 24),
            decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.only(topLeft: Radius.circular(30), topRight: Radius.circular(30))),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Fit the whole label inside the frame', style: TextStyle(color: kTextDark, fontWeight: FontWeight.bold)),
                const SizedBox(height: 30),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(onPressed: _pickGallery, icon: const Icon(Icons.image, size: 30, color: kTeal)),
                    GestureDetector(
                      onTap: _takePicture,
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: kTeal, width: 4)),
                        child: const Icon(Icons.camera_alt, color: kTeal, size: 40),
                      ),
                    ),
                    IconButton(onPressed: () {}, icon: const Icon(Icons.flash_on, size: 30, color: kTeal)),
                  ],
                )
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ==========================================
  // 📄 RESULTS UI
  // ==========================================
  Widget _buildResultUI() {
    List<String> lines = _aiSummary.split('\n').where((s) => s.trim().isNotEmpty).toList();
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: kTeal, size: 24),
              const SizedBox(width: 8),
              Text('AI Medical Summary', style: TextStyle(fontWeight: FontWeight.bold, color: kTextDark, fontSize: 18)),
              if (_isProcessing) const Padding(padding: EdgeInsets.only(left: 10), child: SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2))),
            ],
          ),
          const SizedBox(height: 20),
          
          if (_isProcessing)
            const Center(child: Padding(padding: EdgeInsets.all(20), child: Text("Extracting medical data...")))
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: lines.map((line) {
                  if (line.contains(':')) {
                    var parts = line.split(':');
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(parts[0], style: const TextStyle(fontWeight: FontWeight.bold, color: kTeal, fontSize: 14)),
                          const SizedBox(height: 4),
                          Text(parts.sublist(1).join(':').trim(), style: const TextStyle(fontSize: 16, color: kTextDark, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    );
                  }
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Text(line, style: const TextStyle(fontSize: 16, color: kTextDark)),
                  );
                }).toList(),
              ),
            ),
            
          const SizedBox(height: 30),
          
          // Save Button
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton.icon(
              onPressed: _isProcessing ? null : _saveToDatabase,
              icon: const Icon(Icons.check),
              label: const Text('Save to my medications', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: kTeal, 
                foregroundColor: Colors.white, 
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))
              ),
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Scan Again Button
          SizedBox(
            width: double.infinity,
            height: 55,
            child: OutlinedButton(
              onPressed: () => setState(() { _hasScanned = false; _aiSummary = ""; }),
              style: OutlinedButton.styleFrom(
                foregroundColor: kTeal, 
                side: const BorderSide(color: kTeal, width: 1.5), 
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))
              ),
              child: const Text('Scan again', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}