import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

class EventCreationResultPage extends StatelessWidget {
  const EventCreationResultPage({
    super.key,
    required this.isSuccess,
    required this.message,
  });

  final bool isSuccess;
  final String message;

  @override
  Widget build(BuildContext context) {
    final actionLabel = isSuccess ? 'Go to home' : 'Back to form';

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(isSuccess),
        ),
        title: const Text('Creation result'),
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
                  size: 132,
                  color: isSuccess ? AppTheme.teal : Colors.red,
                ),
                const SizedBox(height: 20),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
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
