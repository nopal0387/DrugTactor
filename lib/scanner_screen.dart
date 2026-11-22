import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isProcessing = false;

  String _rawText = "Point camera at a medicine label and press the button.";
  String _aiSummary = "";

  // 🔑 PASTE YOUR GEMINI API KEY HERE
  final String _apiKey = 'YOUR_GEMINI_API_KEY_HERE';

  // 🚀 Use the fastest model
  final String _modelName = 'gemini-2.5-flash-lite';

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

  // 🧠 AI Generation with Streaming
  Future<void> _generateAISummary(String text) async {
    setState(() {
      _aiSummary = "🧠 Asking AI for medical details...";
    });

    try {
      final model = GenerativeModel(
        model: _modelName,
        apiKey: _apiKey,
      );

      final prompt = _buildPrompt(text);

      // 🚀 Use streaming for real-time token display
      final stream = model.generateContentStream([Content.text(prompt)]);

      String fullResponse = "";
      await for (final chunk in stream) {
        if (chunk.text != null) {
          fullResponse += chunk.text!;
          if (mounted) {
            setState(() {
              _aiSummary = fullResponse;
            });
          }
        }
      }

    } on GenerativeAIException catch (e) {
      // If 503, try fallback. Otherwise show the error.
      if (e.message.contains('503') || e.message.contains('UNAVAILABLE')) {
        await _tryFallbackModel(text);
      } else {
        setState(() {
          _aiSummary = "AI Error: ${e.message}";
        });
      }
    } catch (e) {
      setState(() {
        _aiSummary = "An unexpected error occurred: $e";
      });
    }
  }

  // Fallback method if the primary model is overloaded
  Future<void> _tryFallbackModel(String text) async {
    setState(() {
      _aiSummary = "🔄 Primary model busy. Trying backup...";
    });

    try {
      final fallbackModel = GenerativeModel(
        model: 'gemini-2.5-flash',
        apiKey: _apiKey,
      );

      final prompt = _buildPrompt(text);
      final response = await fallbackModel.generateContent([Content.text(prompt)]);

      setState(() {
        _aiSummary = response.text ?? "Could not generate AI summary.";
      });
    } catch (e) {
      setState(() {
        _aiSummary = "The AI service is currently busy. Please try again in a minute.";
      });
    }
  }

  String _buildPrompt(String text) {
    return """
    Analyze this medicine label text:
    "$text"

    Based ONLY on the text above, provide a brief, clear summary with exactly these three points:
    1. Function: What is this medicine used for?
    2. Dosage: How many times per day?
    3. Instructions: When to take it (e.g., before food, after food)?
    Keep it short and easy to read. If the text does not contain this information, just say "Information not found on label".
    """;
  }

  // 📸 Process Image (From Camera or Gallery)
  Future<void> _processImage(File imageFile) async {
    setState(() {
      _isProcessing = true;
      _aiSummary = "";
      _rawText = "Analyzing image with OCR...";
    });

    try {
      final InputImage inputImage = InputImage.fromFile(imageFile);
      final textRecognizer = TextRecognizer();
      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
      textRecognizer.close();

      if (recognizedText.text.isEmpty) {
        setState(() {
          _rawText = "No text found. Please try again.";
          _isProcessing = false;
        });
        return;
      }

      setState(() {
        _rawText = recognizedText.text;
      });

      await _generateAISummary(recognizedText.text);

    } catch (e) {
      setState(() {
        _aiSummary = "Error: $e";
      });
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _scanImage() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;
    final XFile picture = await _cameraController!.takePicture();
    _processImage(File(picture.path));
  }

  Future<void> _pickFromGallery() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      _processImage(File(image.path));
    }
  }

  // 💾 Save to Database
  Future<void> _saveToDatabase() async {
    if (_rawText.contains("Point camera") || _rawText.contains("No text") || _rawText.contains("Analyzing")) return;
    setState(() { _isProcessing = true; });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('medications')
            .add({
          'rawText': _rawText,
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
    // 🚀 FIXED CONDITION: Show save button if we have raw text and we are not currently loading
    bool showSaveButton = !_isProcessing && 
                          _rawText.isNotEmpty && 
                          !_rawText.contains("Point camera") && 
                          !_rawText.contains("No text") && 
                          !_rawText.contains("Analyzing");

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
                          Text("Raw Text: $_rawText", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          const Divider(),
                          const Text("AI Medical Summary:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal)),
                          const SizedBox(height: 5),
                          Text(_aiSummary, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                  ),
                  
                  // Save Button
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