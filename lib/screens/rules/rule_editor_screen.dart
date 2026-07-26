import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../models/universal_rule.dart';
import '../../providers/remaining_providers.dart';

class RuleEditorScreen extends ConsumerStatefulWidget {
  final String? ruleId;

  const RuleEditorScreen({
    super.key,
    this.ruleId,
  });

  @override
  ConsumerState<RuleEditorScreen> createState() => _RuleEditorScreenState();
}

class _RuleEditorScreenState extends ConsumerState<RuleEditorScreen> {
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late RuleCategory _selectedCategory;
  String _selectedColorHex = '#10B981';
  bool _isPinned = false;

  static const Map<String, String> _colorHexMap = {
    'Emerald': '#10B981',
    'Gold': '#C9A96E',
    'Soft Blue': '#60A5FA',
    'Midnight Purple': '#2D1B4E',
    'Warm Gray': '#9CA3AF',
  };

  static const Map<String, Color> _colorDisplayMap = {
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
    _selectedCategory = RuleCategory.custom;

    // Load existing rule if editing
    if (widget.ruleId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadRule());
    }
  }

  void _loadRule() async {
    final rulesRepo = ref.read(rulesRepositoryProvider);
    try {
      // TODO: Implement getRuleById in repository
      // final rule = await rulesRepo.getRuleById(widget.ruleId!);
      // if (rule != null && mounted) {
      //   setState(() {
      //     _titleController.text = rule.title;
      //     _descriptionController.text = rule.description;
      //     _selectedCategory = rule.category;
      //     _selectedColorHex = rule.colorTag;
      //     _isPinned = rule.isPinned;
      //   });
      // }
    } catch (e) {
      // Handle error
    }
  }

  Future<void> _saveRule() async {
    if (_titleController.text.isEmpty || _descriptionController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title and description are required')),
      );
      return;
    }

    final rulesRepo = ref.read(rulesRepositoryProvider);

    if (widget.ruleId != null) {
      // Update existing rule
      final rule = UniversalRule(
        id: widget.ruleId!,
        title: _titleController.text,
        description: _descriptionController.text,
        category: _selectedCategory,
        colorTag: _selectedColorHex,
        isPinned: _isPinned,
        isArchived: false,
        isCompleted: false,
        repeatDaily: true,
      );
      await rulesRepo.updateRule(rule);
    } else {
      // Create new rule
      final rule = UniversalRule(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: _titleController.text,
        description: _descriptionController.text,
        category: _selectedCategory,
        colorTag: _selectedColorHex,
        isPinned: _isPinned,
        isArchived: false,
        isCompleted: false,
        repeatDaily: true,
      );
      await rulesRepo.createRule(
        title: rule.title,
        description: rule.description,
        category: rule.category,
        colorTag: rule.colorTag,
        isPinned: rule.isPinned,
      );
    }

    // Invalidate providers to refresh the UI
    ref.invalidate(universalRulesProvider);
    ref.invalidate(todaysRulesProvider);
    ref.invalidate(archivedRulesProvider);

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
    final displayColor = _colorDisplayMap[_selectedColorHex] ?? const Color(0xFF10B981);

    return Scaffold(
      backgroundColor: AppTheme.navy,
      appBar: AppBar(
        title: Text(widget.ruleId != null ? 'Edit Rule' : 'Create Rule'),
        backgroundColor: AppTheme.navySurface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: ElevatedButton.icon(
              onPressed: _saveRule,
              icon: const Icon(Icons.check, size: 18),
              label: const Text('Save'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.emerald,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Emoji and title section
            Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: displayColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: displayColor,
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Text(_selectedCategory.toString().split('.').last == 'prayer' ? '🙏'
                        : _selectedCategory.toString().split('.').last == 'reading' ? '📖'
                        : _selectedCategory.toString().split('.').last == 'discipline' ? '💪'
                        : _selectedCategory.toString().split('.').last == 'lifestyle' ? '✨'
                        : _selectedCategory.toString().split('.').last == 'devotion' ? '⛪'
                        : '📌', 
                      style: const TextStyle(fontSize: 28),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _titleController,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
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
            // Description field
            Text(
              'Description',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.white,
              ),
            ),
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
            // Category selector
            Text(
              'Category',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            _buildCategorySelector(),
            const SizedBox(height: 24),
            // Color selector
            Text(
              'Color',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            _buildColorSelector(),
            const SizedBox(height: 24),
            // Pin button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Pin Rule',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                  ),
                ),
                Switch(
                  value: _isPinned,
                  onChanged: (value) => setState(() => _isPinned = value),
                  activeColor: AppTheme.emerald,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategorySelector() {
    const categories = [
      RuleCategory.prayer,
      RuleCategory.reading,
      RuleCategory.discipline,
      RuleCategory.lifestyle,
      RuleCategory.devotion,
      RuleCategory.custom,
    ];
    
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: categories.map((cat) {
        final isSelected = _selectedCategory == cat;
        final catName = cat.toString().split('.').last;
        return GestureDetector(
          onTap: () => setState(() => _selectedCategory = cat),
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
              catName.replaceFirst(catName[0], catName[0].toUpperCase()),
              style: TextStyle(
                color: isSelected ? AppTheme.emerald : AppTheme.warmGray,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildColorSelector() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: _colorHexMap.entries.map((entry) {
        final isSelected = _selectedColorHex == entry.value;
        final color = _colorDisplayMap[entry.value] ?? const Color(0xFF10B981);
        return GestureDetector(
          onTap: () => setState(() => _selectedColorHex = entry.value),
          child: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? Colors.white : Colors.transparent,
                width: isSelected ? 3 : 0,
              ),
              boxShadow: [
                if (isSelected)
                  BoxShadow(
                    color: color.withValues(alpha: 0.5),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
              ],
            ),
            child: isSelected
                ? const Icon(Icons.check, color: Colors.white)
                : null,
          ),
        );
      }).toList(),
    );
  }
}

