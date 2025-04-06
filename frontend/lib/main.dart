import 'package:flutter/material.dart';
import 'package:vibration/vibration.dart';
import 'package:http/http.dart' as http;
import 'package:file_selector/file_selector.dart';
import 'dart:convert';
import 'dart:io';

const String serverUrl = 'http://backendURL';

void main() {
  runApp(const MorseVibrationApp());
}

class MorseVibrationApp extends StatelessWidget {
  const MorseVibrationApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Morse Code Vibration',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.light().copyWith(
        primaryColor: Colors.blueAccent,
        scaffoldBackgroundColor: Colors.white,
      ),
      home: const MorseCodeScreen(),
    );
  }
}

class MorseCodeScreen extends StatefulWidget {
  const MorseCodeScreen({super.key});

  @override
  State<MorseCodeScreen> createState() => _MorseCodeScreenState();
}

class _MorseCodeScreenState extends State<MorseCodeScreen> {
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
    final typeGroup = XTypeGroup(label: 'Video', extensions: ['mp4', 'mov', 'avi']);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Morse Code Vibration"),
        backgroundColor: Colors.blueAccent,
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                "Enter text to convert into Morse Code and feel vibrations:",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _textController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: "Enter text",
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _convertAndVibrate,
                child: const Text("Convert & Vibrate"),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _uploadPDFAndVibrate,
                child: const Text("Upload PDF & Vibrate"),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _uploadVideoAndVibrate,
                child: const Text("Upload Video & Vibrate"),
              ),
              const SizedBox(height: 20),
              if (_morseCode.isNotEmpty)
                Text(
                  "Morse: $_morseCode",
                  style: const TextStyle(fontSize: 16),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
