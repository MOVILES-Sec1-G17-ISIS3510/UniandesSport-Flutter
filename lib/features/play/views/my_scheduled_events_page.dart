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
                            return Card(
                              child: ListTile(
                                title: Text(event.title),
                                subtitle: Text(vm.formatSchedule(event.scheduledAt)),
                                trailing: TextButton(
                                  onPressed: () async {
                                    final removed = await vm.leaveScheduledEvent(event);
                                    if (!context.mounted) return;
                                    if (removed) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Event left successfully.'),
                                        ),
                                      );
                                    }
                                  },
                                  child: const Text('Leave'),
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