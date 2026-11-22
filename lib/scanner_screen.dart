import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart' as img_picker;
// 👇 Hide Container to avoid conflict with Flutter's Container widget
import 'package:openai_dart/openai_dart.dart' hide Container;

import 'secrets.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isProcessing = false;

  String _aiSummary = "Point camera at a medicine label and press the button.";

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
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

  // 🧠 AI Generation with Groq Vision (Corrected API)
  Future<void> _generateAISummaryFromImage(File imageFile) async {
    setState(() {
      _aiSummary = "🧠 Groq is analyzing the image...";
    });

    try {
      // 1. Read the image file and convert it to Base64
      final bytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(bytes);

      // 2. Initialize the OpenAI client for Groq
      final client = OpenAIClient(
        config: OpenAIConfig(
          authProvider: ApiKeyProvider(groqApiKey),
          baseUrl: 'https://api.groq.com/openai/v1',
        ),
      );

      // 3. Build the prompt
      final prompt = """
      You are a helpful medical assistant. Analyze the image of this medicine packaging.
      Provide a brief, clear summary with exactly these three points:
      1. Function: What is this medicine used for?
      2. Dosage: How many times per day?
      3. Instructions: When to take it (e.g., before food, after food)?
      Keep it short and easy to read. If the image is too blurry to read, just say "Image unclear, please retake."
      """;

      // 4. Send the request using the correct `ChatMessage` and `ContentPart` API
      final response = await client.chat.completions.create(
        ChatCompletionCreateRequest(
          model: 'qwen/qwen3.8-27b', // Groq's fast, free vision model
          maxTokens: 500,
          messages: [
            // 👇 Use ChatMessage.user with a list of ContentParts
            ChatMessage.user([
              ContentPart.text(prompt),
              ContentPart.imageBase64(
                data: base64Image,
                mediaType: 'image/jpeg', // Or 'image/png'
              ),
            ]),
          ],
        ),
      );

      // 5. Update the UI with the result
      setState(() {
        _aiSummary = response.choices.first.message.content ?? "Could not generate AI summary.";
      });

    } catch (e) {
      setState(() {
        _aiSummary = "Error: $e";
      });
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  // 📸 Process Image (From Camera or Gallery)
  Future<void> _processImage(File imageFile) async {
    setState(() {
      _isProcessing = true;
      _aiSummary = "Preparing image for AI...";
    });
    await _generateAISummaryFromImage(imageFile);
  }

  // 📷 Take Photo
  Future<void> _scanImage() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;
    final XFile picture = await _cameraController!.takePicture();
    _processImage(File(picture.path));
  }

  // 🖼️ Pick from Gallery
  Future<void> _pickFromGallery() async {
    final img_picker.ImagePicker picker = img_picker.ImagePicker();
    final XFile? image = await picker.pickImage(source: img_picker.ImageSource.gallery);
    if (image != null) {
      _processImage(File(image.path));
    }
  }

  // 💾 Save to Database
  Future<void> _saveToDatabase() async {
    if (_aiSummary.contains("Point camera") || _aiSummary.contains("Error")) return;
    setState(() { _isProcessing = true; });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('medications')
            .add({
          'aiSummary': _aiSummary,
          'timestamp': FieldValue.serverTimestamp(),
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Medication saved successfully!')),
          );
          Navigator.pop(context);
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() { _isProcessing = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    bool showSaveButton = !_isProcessing && 
                          _aiSummary.isNotEmpty && 
                          !_aiSummary.contains("Point camera") &&
                          !_aiSummary.contains("Error");

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Medication'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.photo_library),
            onPressed: _isProcessing ? null : _pickFromGallery,
            tooltip: 'Upload from Gallery',
          )
        ],
      ),
      body: Column(
        children: [
          Expanded(
            flex: 2,
            child: _cameraController == null || !_cameraController!.value.isInitialized
                ? const Center(child: CircularProgressIndicator())
                : CameraPreview(_cameraController!),
          ),
          Expanded(
            flex: 2,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: Colors.grey[100],
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("AI Medical Summary:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal)),
                          const SizedBox(height: 5),
                          Text(_aiSummary, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                  ),
                  if (showSaveButton)
                    ElevatedButton.icon(
                      onPressed: _saveToDatabase,
                      icon: const Icon(Icons.save),
                      label: const Text('Save Medication to App'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(45),
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white,
                      ),
                    )
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _isProcessing ? null : _scanImage,
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        child: _isProcessing
            ? const CircularProgressIndicator(color: Colors.white)
            : const Icon(Icons.camera_alt, size: 30),
      ),
    );
  }
}