import 'package:flutter/material.dart';
import '../../../auth/domain/models/user_profile.dart';

class SocialPage extends StatelessWidget {
  final UserProfile profile;

  const SocialPage({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TU RED DEPORTIVA',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Colors.teal,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Social',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 24),

                // Sports tabs
                DefaultTabController(
                  length: 4,
                  child: Column(
                    children: [
                      TabBar(
                        isScrollable: true,
                        tabs: const [
                          Tab(text: 'Soccer'),
                          Tab(text: 'Tennis'),
                          Tab(text: 'Basketball'),
                          Tab(text: 'Running'),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 400,
                        child: TabBarView(
                          children: [
                            _SportCommunityView(
                              sport: 'Soccer',
                              members: 48,
                              posts: 3,
                            ),
                            _SportCommunityView(
                              sport: 'Tennis',
                              members: 32,
                              posts: 2,
                            ),
                            _SportCommunityView(
                              sport: 'Basketball',
                              members: 25,
                              posts: 5,
                            ),
                            _SportCommunityView(
                              sport: 'Running',
                              members: 67,
                              posts: 8,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                Text(
                  'DISCOVER MORE',
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                _CommunityCard(
                  icon: 'B',
                  title: 'Basketball Warriors',
                  description: 'Competitive basketball clan 3x3 and 5x5.',
                  tag: 'CLAN',
                  sport: 'Basketball',
                  members: 24,
                  posts: 3,
                ),
                const SizedBox(height: 12),
                _CommunityCard(
                  icon: 'R',
                  title: 'Running UniAndes',
                  description: 'Runners group for all levels.',
                  tag: 'COMMUNITY',
                  sport: 'Running',
                  members: 67,
                  posts: 8,
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SportCommunityView extends StatelessWidget {
  final String sport;
  final int members;
  final int posts;

  const _SportCommunityView({
    required this.sport,
    required this.members,
    required this.posts,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue[900],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                children: [
                  Text(
                    '👥 $members',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Column(
                children: [
                  Text(
                    '💬 $posts',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CommunityCard extends StatelessWidget {
  final String icon;
  final String title;
  final String description;
  final String tag;
  final String sport;
  final int members;
  final int posts;

  const _CommunityCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.tag,
    required this.sport,
    required this.members,
    required this.posts,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.teal[100],
                child: Text(
                  icon,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 24,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue[900],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  tag,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                sport,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
              ),
              const Spacer(),
              Text('👥 $members', style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(width: 8),
              Text('💬 $posts', style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ],
      ),
    );
  }
}
