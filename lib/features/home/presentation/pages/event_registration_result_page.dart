import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

class EventRegistrationResultPage extends StatelessWidget {
  const EventRegistrationResultPage({
    super.key,
    required this.isSuccess,
    this.message,
  });

  final bool isSuccess;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final title = message ?? (isSuccess ? 'Successful registration' : 'Registration failed');
    final actionLabel = isSuccess ? 'Back to home' : 'Back to search';

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(isSuccess),
        ),
        title: const Text('Registration result'),
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isSuccess ? Icons.check_circle : Icons.error,
                  size: 140,
                  color: isSuccess ? AppTheme.teal : Colors.red,
                ),
                const SizedBox(height: 24),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: isSuccess ? AppTheme.navy : Colors.red,
                      ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.of(context).pop(isSuccess),
                    icon: const Icon(Icons.arrow_back),
                    label: Text(actionLabel),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

