import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../core/theme.dart';
import '../../repositories/ai_repository.dart';
import '../../widgets/common/app_widgets.dart';

// ── Shared AI Study Widget ────────────────────────────────────────────────────

class _AiStudyScreen extends StatefulWidget {
  final String title;
  final String inputLabel;
  final String hintText;
  final String buttonLabel;
  final Future<String> Function(String input) onStudy;
  final String? prefillValue;

  const _AiStudyScreen({
    required this.title,
    required this.inputLabel,
    required this.hintText,
    required this.buttonLabel,
    required this.onStudy,
    this.prefillValue,
  });

  @override
  State<_AiStudyScreen> createState() => _AiStudyScreenState();
}

class _AiStudyScreenState extends State<_AiStudyScreen> {
  late final TextEditingController _ctrl;
  String? _result;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.prefillValue ?? '');
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _study() async {
    if (_ctrl.text.trim().isEmpty) return;
    setState(() { _loading = true; _error = null; _result = null; });
    try {
      final res = await widget.onStudy(_ctrl.text.trim());
      setState(() => _result = res);
    } catch (e) {
      setState(() => _error = 'AI service unavailable. Please try again.');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('AI-generated content. Verify with Scripture.'))),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextFormField(
            controller: _ctrl,
            decoration: InputDecoration(
              labelText: widget.inputLabel,
              hintText: widget.hintText,
            ),
            onFieldSubmitted: (_) => _study(),
          ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            onPressed: _loading ? null : _study,
            icon: _loading
                ? const SizedBox(width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.auto_awesome, size: 16),
            label: Text(_loading ? 'Studying...' : widget.buttonLabel),
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(_error!, style: const TextStyle(color: Colors.redAccent)),
          ],
          if (_result != null) ...[
            const GoldDivider(),
            Row(children: [
              const Icon(Icons.auto_awesome, color: AppTheme.gold, size: 16),
              const SizedBox(width: 8),
              Text('AI Study', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppTheme.gold)),
              const Spacer(),
              TextButton(
                onPressed: () => setState(() => _result = null),
                child: const Text('Clear'),
              ),
            ]),
            const SizedBox(height: 8),
            MarkdownBody(
              data: _result!,
              styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                p: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.7),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ],
      ),
    );
  }
}

// ── Explain Verse ─────────────────────────────────────────────────────────────

class ExplainVerseScreen extends StatelessWidget {
  final String? reference;
  final String? verseText;

  const ExplainVerseScreen({super.key, this.reference, this.verseText});

  @override
  Widget build(BuildContext context) {
    return _AiStudyScreen(
      title: 'Explain Verse',
      inputLabel: 'Verse Reference',
      hintText: 'e.g. John 3:16',
      buttonLabel: 'Explain this Verse',
      prefillValue: reference,
      onStudy: (input) => AiRepository().explainVerse(
        reference: input,
        verseText: verseText ?? '',
      ),
    );
  }
}

// ── Topic Study ───────────────────────────────────────────────────────────────

class TopicStudyScreen extends StatelessWidget {
  const TopicStudyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _AiStudyScreen(
      title: 'Topic Study',
      inputLabel: 'Biblical Topic',
      hintText: 'e.g. forgiveness, faith, the Holy Spirit',
      buttonLabel: 'Study this Topic',
      onStudy: (input) => AiRepository().topicStudy(input),
    );
  }
}

// ── Character Study ───────────────────────────────────────────────────────────

class CharacterStudyScreen extends StatelessWidget {
  const CharacterStudyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _AiStudyScreen(
      title: 'Character Study',
      inputLabel: 'Biblical Character',
      hintText: 'e.g. David, Paul, Esther, Moses',
      buttonLabel: 'Study this Character',
      onStudy: (input) => AiRepository().characterStudy(input),
    );
  }
}
