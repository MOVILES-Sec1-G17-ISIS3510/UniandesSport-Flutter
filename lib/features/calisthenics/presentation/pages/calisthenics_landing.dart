import 'package:flutter/material.dart';

import 'calisthenics_analysis_example.dart';
import '../../services/calisthenics_ai_service.dart';
import '../../../core/local_storage/preferences_service.dart';

class CalisthenicsLandingScreen extends StatefulWidget {
  const CalisthenicsLandingScreen({super.key});

  @override
  State<CalisthenicsLandingScreen> createState() => _CalisthenicsLandingScreenState();
}

class _CalisthenicsLandingScreenState extends State<CalisthenicsLandingScreen> {
  bool _canAnalyzeToday = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkDailyLimit();
  }

  Future<void> _checkDailyLimit() async {
    final prefs = PreferencesService();
    final lastDate = await prefs.getLastCalisthenicsAnalysisDate();
    
    if (!mounted) return;
    
    if (lastDate != null) {
      final now = DateTime.now();
      if (lastDate.year == now.year && lastDate.month == now.month && lastDate.day == now.day) {
        setState(() {
          _canAnalyzeToday = false;
        });
      }
    }
    setState(() {
      _isLoading = false;
    });
  }

  void _navigateToAnalysis({bool gallery = false, bool viewOnly = false}) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CalisthenicsAnalysisExampleScreen(
          startWithGallery: gallery,
          viewOnlyMode: viewOnly,
        ),
      ),
    );
    // Refresh limits when returning
    _checkDailyLimit();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

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
            Text(
              _canAnalyzeToday 
                ? 'Analyze your exercise form with the Calisthenics Assistant.\n\nTake a photo or upload one from your gallery to run an analysis.'
                : 'You have already completed your daily analysis. Great job!\n\nYou can review your feedback below.',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            
            if (_canAnalyzeToday) ...[
              ElevatedButton.icon(
                onPressed: () => _navigateToAnalysis(),
                icon: const Icon(Icons.camera_alt),
                label: const Text('Start Analysis'),
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: () => _navigateToAnalysis(gallery: true),
                icon: const Icon(Icons.photo_library),
                label: const Text('Upload from Gallery'),
              ),
              const SizedBox(height: 8),
            ],
            
            OutlinedButton.icon(
              onPressed: () => _navigateToAnalysis(viewOnly: true),
              icon: const Icon(Icons.history),
              label: Text(_canAnalyzeToday ? 'View Last Analysis' : 'View Today\'s Analysis'),
            ),
          ],
        ),
      ),
    );
  }
}

