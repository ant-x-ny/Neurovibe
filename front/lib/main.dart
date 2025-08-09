import 'package:flutter/material.dart';
import 'package:vibration/vibration.dart';
import 'package:http/http.dart' as http;
import 'package:file_selector/file_selector.dart';
import 'dart:convert';
import 'dart:io';

const String serverUrl = 'http://192.168.127.120:5000';

void main() {
  runApp(const MorseVibrationApp());
}

class MorseVibrationApp extends StatelessWidget {
  const MorseVibrationApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const NeuroVibePage(),
    );
  }
}

class NeuroVibePage extends StatefulWidget {
  const NeuroVibePage({super.key});

  @override
  State<NeuroVibePage> createState() => _NeuroVibePageState();
}

class _NeuroVibePageState extends State<NeuroVibePage> {
  final TextEditingController _textController = TextEditingController();
  String _morseCode = "";
  bool _isLoading = false;

  Future<void> _convertAndVibrate() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('$serverUrl/morse'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'text': text}),
      );

      if (response.statusCode == 200) {
        final morse = jsonDecode(response.body)['morse'];
        setState(() => _morseCode = morse);
        _vibrateMorse(morse);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Morse Code: $morse")),
        );
      } else {
        throw Exception("Failed to get Morse code");
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }

    setState(() => _isLoading = false);
  }

  Future<void> _uploadPDFAndVibrate() async {
    final typeGroup = XTypeGroup(label: 'PDF', extensions: ['pdf']);
    final file = await openFile(acceptedTypeGroups: [typeGroup]);

    if (file != null) {
      setState(() => _isLoading = true);

      final pdfFile = File(file.path);
      try {
        var request = http.MultipartRequest(
          'POST',
          Uri.parse('$serverUrl/morsifyPDF'),
        );
        request.files.add(
          await http.MultipartFile.fromPath('file', pdfFile.path),
        );

        var response = await request.send();
        final responseData = await http.Response.fromStream(response);

        if (response.statusCode == 200) {
          final morse = jsonDecode(responseData.body)['morse'];
          setState(() => _morseCode = morse);
          _vibrateMorse(morse);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Morse from PDF: $morse")),
          );
        } else {
          throw Exception("Failed to process PDF");
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      }

      setState(() => _isLoading = false);
    }
  }

  Future<void> _uploadVideoAndVibrate() async {
    final typeGroup =
    XTypeGroup(label: 'Video', extensions: ['mp4', 'mov', 'avi']);
    final file = await openFile(acceptedTypeGroups: [typeGroup]);

    if (file != null) {
      setState(() => _isLoading = true);

      final videoFile = File(file.path);
      try {
        var request = http.MultipartRequest(
          'POST',
          Uri.parse('$serverUrl/convertVideo'),
        );
        request.files.add(
          await http.MultipartFile.fromPath('file', videoFile.path),
        );

        var response = await request.send();
        final responseData = await http.Response.fromStream(response);

        if (response.statusCode == 200) {
          final morse = jsonDecode(responseData.body)['morse'];
          setState(() => _morseCode = morse);
          _vibrateMorse(morse);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Morse from Video: $morse")),
          );
        } else {
          throw Exception("Failed to process video");
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      }

      setState(() => _isLoading = false);
    }
  }

  Future<void> _vibrateMorse(String morse) async {
    List<int> pattern = [0];
    int dot = 100;
    int dash = dot * 3;
    int gapIntra = dot;
    int gapInterWord = dot * 7;

    for (int i = 0; i < morse.length; i++) {
      String symbol = morse[i];
      if (symbol == '.') {
        pattern.add(dot);
        pattern.add(gapIntra);
      } else if (symbol == '_') {
        pattern.add(dash);
        pattern.add(gapIntra);
      } else if (symbol == ' ') {
        if (pattern.isNotEmpty) {
          pattern[pattern.length - 1] = gapInterWord;
        }
      }
    }

    if (pattern.isNotEmpty && pattern.last == gapIntra) {
      pattern.removeLast();
    }

    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(pattern: pattern);
    }
  }

  void _stopVibration() {
    Vibration.cancel();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Vibration stopped")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
          padding: EdgeInsets.only(
            left: 24.0,
            right: 24.0,
            top: 24.0,
            bottom:
            MediaQuery.of(context).viewInsets.bottom + 24.0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'neurovibe.',
                style: TextStyle(
                  fontFamily: 'Helvetica',
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 32),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1C1E),
                  borderRadius: BorderRadius.circular(16.0),
                ),
                child: TextField(
                  controller: _textController,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 18),
                  maxLines: 6,
                  decoration: const InputDecoration(
                    hintText: 'enter your text.......',
                    hintStyle: TextStyle(color: Colors.grey),
                    contentPadding: EdgeInsets.all(20.0),
                    border: InputBorder.none,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              _buildSliderButton(
                text: 'Convert & Vibrate',
                onSlide: _convertAndVibrate,
              ),
              const SizedBox(height: 16),
              _buildSliderButton(
                text: 'Upload PDF & Vibrate',
                onSlide: _uploadPDFAndVibrate,
              ),
              const SizedBox(height: 16),
              _buildSliderButton(
                text: 'Upload Video & Vibrate',
                onSlide: _uploadVideoAndVibrate,
              ),
              const SizedBox(height: 24),
              Center(
                child: ElevatedButton(
                  onPressed: _stopVibration,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 40, vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: const Text(
                    "STOP",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSliderButton(
      {required String text, required VoidCallback onSlide}) {
    return Dismissible(
      key: UniqueKey(),
      direction: DismissDirection.startToEnd,
      onDismissed: (direction) {
        onSlide();
        setState(() {});
      },
      background: Container(
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.5),
          borderRadius: BorderRadius.circular(40),
        ),
        padding: const EdgeInsets.only(left: 20),
        alignment: Alignment.centerLeft,
        child: const Icon(Icons.check, color: Colors.white),
      ),
      child: Container(
        height: 80,
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(40),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              spreadRadius: 1,
              blurRadius: 5,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.0),
              child: CircleAvatar(
                backgroundColor: Colors.white,
                radius: 24,
                child: Icon(Icons.arrow_forward_ios,
                    color: Colors.black, size: 18),
              ),
            ),
            Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
