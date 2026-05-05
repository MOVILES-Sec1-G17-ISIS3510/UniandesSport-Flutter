import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../viewmodels/play_view_model.dart';

class MyScheduledEventsPage extends StatefulWidget {
  const MyScheduledEventsPage({super.key});

  @override
  State<MyScheduledEventsPage> createState() => _MyScheduledEventsPageState();
}

class _MyScheduledEventsPageState extends State<MyScheduledEventsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<PlayViewModel>().loadMyScheduled(forceRefresh: true);
    });
  }

  Future<bool> _confirmCancelEvent(BuildContext context, String title) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Cancel event?'),
          content: Text(
            'This will delete "$title" for everyone and cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Keep'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Cancel event'),
            ),
          ],
        );
      },
    );

    return confirmed ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<PlayViewModel>();

    return Scaffold(
      appBar: AppBar(title: const Text('My scheduled events')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: vm.isLoadingMyScheduled
              ? const Center(child: CircularProgressIndicator())
              : vm.myScheduledError != null
                  ? Center(child: Text(vm.myScheduledError!))
                  : vm.myScheduledEvents.isEmpty
                      ? const Center(
                          child: Text('You do not have active scheduled events.'),
                        )
                      : ListView.separated(
                          itemCount: vm.myScheduledEvents.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final event = vm.myScheduledEvents[index];
                            final isOwner = event.createdBy == vm.profile.uid;
                            final actionLabel = isOwner ? 'Cancel' : 'Leave';
                            final actionColor = isOwner ? Colors.red : null;

                            return Card(
                              child: ListTile(
                                title: Text(event.title),
                                subtitle: Text(vm.formatSchedule(event.scheduledAt)),
                                trailing: TextButton(
                                  style: actionColor == null
                                      ? null
                                      : TextButton.styleFrom(foregroundColor: actionColor),
                                  onPressed: () async {
                                    if (isOwner) {
                                      final confirmed = await _confirmCancelEvent(context, event.title);
                                      if (!confirmed || !context.mounted) return;

                                      vm.cancelScheduledEvent(event).then((removed) {
                                        if (!context.mounted || removed != true) return;
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Event canceled successfully.'),
                                          ),
                                        );
                                      });
                                      return;
                                    }

                                    vm.leaveScheduledEvent(event).then((removed) {
                                      if (!context.mounted || removed != true) return;
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Event left successfully.'),
                                        ),
                                      );
                                    });
                                  },
                                  child: Text(actionLabel),
                                ),
                              ),
                            );
                          },
                        ),
        ),
      ),
    );
  }
}