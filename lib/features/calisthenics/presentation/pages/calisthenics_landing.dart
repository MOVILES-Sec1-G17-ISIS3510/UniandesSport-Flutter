import 'package:flutter/material.dart';

import 'calisthenics_analysis_example.dart';

class CalisthenicsLandingScreen extends StatelessWidget {
  const CalisthenicsLandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Calisthenics Assistant'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 12),
            const Text(
              'Analyze your exercise form with the Calisthenics Assistant.\n\nPress Start to open the camera and run an analysis.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const CalisthenicsAnalysisExampleScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.camera_alt),
              label: const Text('Start Analysis'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () {
                // Optionally show last analysis if exists
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Opening history is not implemented yet')),
                );
              },
              child: const Text('View Last Analysis'),
            ),
          ],
        ),
      ),
    );
  }
}

