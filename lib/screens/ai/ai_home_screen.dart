import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';

class AiHomeScreen extends StatelessWidget {
  const AiHomeScreen({super.key});

  static const _tools = [
    _AiTool('Chat', 'Free Bible-focused conversation', Icons.chat_outlined, '/ai/chat'),
    _AiTool('Explain Verse', 'Deep explanation with context & application', Icons.auto_stories_outlined, '/ai/explain-verse'),
    _AiTool('Topic Study', 'Research any biblical topic', Icons.topic_outlined, '/ai/topic-study'),
    _AiTool('Character Study', 'Study any person in the Bible', Icons.person_search_outlined, '/ai/character-study'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI Bible Assistant')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.gold.withOpacity(0.2), AppTheme.navyVariant],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.gold.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.auto_awesome, color: AppTheme.gold, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Powered by Claude AI',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppTheme.gold)),
                      const SizedBox(height: 4),
                      Text('Your personal Bible study companion',
                          style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text('Study Tools', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 1.2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: _tools.length,
            itemBuilder: (_, i) => _AiToolCard(tool: _tools[i]),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

class _AiTool {
  final String title;
  final String desc;
  final IconData icon;
  final String route;
  const _AiTool(this.title, this.desc, this.icon, this.route);
}

class _AiToolCard extends StatelessWidget {
  final _AiTool tool;
  const _AiToolCard({super.key, required this.tool});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: () => context.push(tool.route),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(tool.icon, color: AppTheme.gold, size: 28),
              const SizedBox(height: 10),
              Text(tool.title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(tool.desc,
                  style: Theme.of(context).textTheme.bodySmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }
}
