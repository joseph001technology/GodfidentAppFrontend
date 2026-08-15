import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../providers/rules_provider.dart';

class RuleEditorScreen extends ConsumerStatefulWidget {
  final String? ruleId;

  const RuleEditorScreen({super.key, this.ruleId});

  @override
  ConsumerState<RuleEditorScreen> createState() => _RuleEditorScreenState();
}

class _RuleEditorScreenState extends ConsumerState<RuleEditorScreen> {
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  int? _selectedCategoryId;
  // Default matches the backend Rule model's own default ('#6C5CE7').
  String _selectedColorHex = '#6C5CE7';
  bool _isPinned = false;
  bool _isFavorite = false;
  bool _loading = false;

  static const Map<String, String> _colorHexMap = {
    'Violet': '#6C5CE7',
    'Emerald': '#10B981',
    'Gold': '#C9A96E',
    'Soft Blue': '#60A5FA',
    'Midnight Purple': '#2D1B4E',
    'Warm Gray': '#9CA3AF',
  };

  static const Map<String, Color> _colorDisplayMap = {
    '#6C5CE7': Color(0xFF6C5CE7),
    '#10B981': Color(0xFF10B981),
    '#C9A96E': Color(0xFFC9A96E),
    '#60A5FA': Color(0xFF60A5FA),
    '#2D1B4E': Color(0xFF2D1B4E),
    '#9CA3AF': Color(0xFF9CA3AF),
  };

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _descriptionController = TextEditingController();
    if (widget.ruleId != null) {
      _loadExisting();
    }
  }

  /// The old version of this screen never loaded the existing rule's data
  /// when editing — fields opened blank. rulesProvider's cached list might
  /// not have this rule yet (e.g. deep link), so fetch it directly via
  /// GET /api/rules/{id}/ rather than assuming it's already loaded.
  Future<void> _loadExisting() async {
    setState(() => _loading = true);
    try {
      final id = int.tryParse(widget.ruleId!);
      if (id == null) return;
      final rule = await ref.read(rulesRepositoryProvider).getById(id);
      if (!mounted) return;
      setState(() {
        _titleController.text = rule.title;
        _descriptionController.text = rule.description ?? '';
        _selectedCategoryId = rule.category;
        _selectedColorHex = _colorDisplayMap.containsKey(rule.color) ? rule.color : '#6C5CE7';
        _isPinned = rule.isPinned;
        _isFavorite = rule.isFavorite;
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not load this rule')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveRule() async {
    if (_titleController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title is required')),
      );
      return;
    }

    final rulesRepo = ref.read(rulesRepositoryProvider);

    final data = <String, dynamic>{
      'title': _titleController.text,
      if (_descriptionController.text.isNotEmpty) 'description': _descriptionController.text,
      'category': _selectedCategoryId,
      'color': _selectedColorHex,
      'is_pinned': _isPinned,
      'is_favorite': _isFavorite,
    };

    if (widget.ruleId != null) {
      final id = int.tryParse(widget.ruleId!) ?? 0;
      await rulesRepo.update(id, data);
    } else {
      await rulesRepo.create(data);
    }

    ref.invalidate(rulesProvider);
    ref.invalidate(todayRulesProvider);

    if (mounted) {
      context.pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.ruleId != null ? 'Rule updated' : 'Rule created')),
      );
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final displayColor = _colorDisplayMap[_selectedColorHex] ?? const Color(0xFF6C5CE7);

    return Scaffold(
      backgroundColor: AppTheme.navy,
      appBar: AppBar(
        title: Text(widget.ruleId != null ? 'Edit Rule' : 'Create Rule'),
        backgroundColor: AppTheme.navySurface,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: ElevatedButton.icon(
                onPressed: _loading ? null : _saveRule,
                icon: const Icon(Icons.check, size: 16),
                label: const Text('Save'),
                style: ElevatedButton.styleFrom(
                  minimumSize: Size.zero,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  backgroundColor: AppTheme.emerald,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: displayColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: displayColor, width: 2),
                        ),
                        child: const Center(child: Text('📌', style: TextStyle(fontSize: 28))),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextField(
                          controller: _titleController,
                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                          decoration: InputDecoration(
                            hintText: 'Rule title',
                            hintStyle: TextStyle(color: AppTheme.warmGray.withValues(alpha: 0.5)),
                            border: InputBorder.none,
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text('Description', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white)),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: AppTheme.navyVariant,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.warmGray.withValues(alpha: 0.2)),
                    ),
                    child: TextField(
                      controller: _descriptionController,
                      style: const TextStyle(color: Colors.white, height: 1.6),
                      decoration: InputDecoration(
                        hintText: 'Describe your rule...',
                        hintStyle: TextStyle(color: AppTheme.warmGray.withValues(alpha: 0.5)),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.all(12),
                      ),
                      maxLines: 4,
                      minLines: 3,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text('Category', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white)),
                  const SizedBox(height: 8),
                  _buildCategorySelector(),
                  const SizedBox(height: 24),
                  Text('Color', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white)),
                  const SizedBox(height: 8),
                  _buildColorSelector(),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Pin Rule', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white)),
                      Switch(value: _isPinned, onChanged: (v) => setState(() => _isPinned = v), activeThumbColor: AppTheme.emerald),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Favorite', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white)),
                      Switch(value: _isFavorite, onChanged: (v) => setState(() => _isFavorite = v), activeThumbColor: AppTheme.accentPink),
                    ],
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildCategorySelector() {
    final categoriesAsync = ref.watch(ruleCategoriesProvider);
    return categoriesAsync.when(
      data: (categories) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: categories.map((cat) {
          final isSelected = _selectedCategoryId == cat.id;
          return GestureDetector(
            onTap: () => setState(() => _selectedCategoryId = isSelected ? null : cat.id),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                border: Border.all(
                  color: isSelected ? AppTheme.emerald : AppTheme.warmGray.withValues(alpha: 0.3),
                  width: isSelected ? 2 : 1,
                ),
                borderRadius: BorderRadius.circular(20),
                color: isSelected ? AppTheme.emerald.withValues(alpha: 0.15) : Colors.transparent,
              ),
              child: Text(
                cat.name,
                style: TextStyle(color: isSelected ? AppTheme.emerald : AppTheme.warmGray, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
              ),
            ),
          );
        }).toList(),
      ),
      loading: () => const CircularProgressIndicator(),
      error: (_, __) => const Text('Could not load categories', style: TextStyle(color: AppTheme.warmGray)),
    );
  }

  Widget _buildColorSelector() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: _colorHexMap.entries.map((entry) {
        final isSelected = _selectedColorHex == entry.value;
        final color = _colorDisplayMap[entry.value] ?? const Color(0xFF6C5CE7);
        return GestureDetector(
          onTap: () => setState(() => _selectedColorHex = entry.value),
          child: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isSelected ? Colors.white : Colors.transparent, width: isSelected ? 3 : 0),
              boxShadow: [
                if (isSelected) BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 8, spreadRadius: 2),
              ],
            ),
            child: isSelected ? const Icon(Icons.check, color: Colors.white) : null,
          ),
        );
      }).toList(),
    );
  }
}