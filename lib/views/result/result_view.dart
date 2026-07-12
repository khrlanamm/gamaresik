import 'dart:io';
import 'package:flutter/material.dart';
import '../../services/firebase_service.dart';

class ResultView extends StatelessWidget {
  final String imagePath;
  const ResultView({super.key, required this.imagePath});

  @override
  Widget build(BuildContext context) {
    // Mock result for now
    const result = "Recycle Bersih";
    final FirebaseService firebaseService = FirebaseService();

    // Placeholder function to save to Firestore
    void saveResult() async {
      await firebaseService.saveClassification({
        'result': result,
        'imagePath': imagePath, // In a real app, upload to Storage first and save URL
      });
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Scan Result')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.file(File(imagePath), fit: BoxFit.cover),
              ),
            ),
            const SizedBox(height: 24),
            const Text('Classification Result:', style: TextStyle(fontSize: 18)),
            const SizedBox(height: 8),
            const Text(
              result,
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.blue),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                OutlinedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Scan Again'),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    saveResult();
                    Navigator.popUntil(context, (route) => route.isFirst);
                  },
                  icon: const Icon(Icons.home),
                  label: const Text('Finish'),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
