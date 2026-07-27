import '../models/universal_rule.dart';
import 'package:uuid/uuid.dart';

// ══════════════════════════════════════════════════════════════════════════
// UNIVERSAL RULES REPOSITORY
// ══════════════════════════════════════════════════════════════════════════

abstract class UniversalRulesRepository {
  Future<List<UniversalRule>> getAllRules();
  Future<List<UniversalRule>> getActiveRules();
  Future<List<UniversalRule>> getArchivedRules();
  Future<List<UniversalRule>> getRulesByCategory(RuleCategory category);
  Future<UniversalRule?> getRule(String ruleId);
  
  Future<UniversalRule> createRule({
    required String title,
    String description = '',
    RuleCategory category = RuleCategory.custom,
    String colorTag = '#10B981',
    bool isPinned = false,
  });
  
  Future<void> updateRule(UniversalRule rule);
  Future<void> deleteRule(String ruleId);
  Future<void> archiveRule(String ruleId);
  Future<void> restoreRule(String ruleId);
  Future<void> togglePin(String ruleId);
  Future<void> markCompleted(String ruleId);
  Future<void> resetDailyCompletion();
  Future<List<UniversalRule>> getTodaysRules();
}

// ══════════════════════════════════════════════════════════════════════════
// LOCAL UNIVERSAL RULES REPOSITORY
// ══════════════════════════════════════════════════════════════════════════

class LocalUniversalRulesRepository implements UniversalRulesRepository {
  final Map<String, UniversalRule> _rules = {};
  static const _uuid = Uuid();

  @override
  Future<List<UniversalRule>> getAllRules() async {
    return _rules.values.toList();
  }

  @override
  Future<List<UniversalRule>> getActiveRules() async {
    return _rules.values.where((rule) => !rule.isArchived).toList();
  }

  @override
  Future<List<UniversalRule>> getArchivedRules() async {
    return _rules.values.where((rule) => rule.isArchived).toList();
  }

  @override
  Future<List<UniversalRule>> getRulesByCategory(RuleCategory category) async {
    return _rules.values.where((rule) => rule.category == category).toList();
  }

  @override
  Future<UniversalRule?> getRule(String ruleId) async {
    return _rules[ruleId];
  }

  @override
  Future<UniversalRule> createRule({
    required String title,
    String description = '',
    RuleCategory category = RuleCategory.custom,
    String colorTag = '#10B981',
    bool isPinned = false,
  }) async {
    final rule = UniversalRule(
      id: _uuid.v4(),
      title: title,
      description: description,
      category: category,
      colorTag: colorTag,
      isPinned: isPinned,
      createdAt: DateTime.now(),
    );
    _rules[rule.id] = rule;
    // TODO: Save to local storage
    return rule;
  }

  @override
  Future<void> updateRule(UniversalRule rule) async {
    _rules[rule.id] = rule;
    // TODO: Save to local storage
  }

  @override
  Future<void> deleteRule(String ruleId) async {
    _rules.remove(ruleId);
    // TODO: Save to local storage
  }

  @override
  Future<void> archiveRule(String ruleId) async {
    if (_rules.containsKey(ruleId)) {
      final rule = _rules[ruleId]!;
      _rules[ruleId] = rule.copyWith(isArchived: true);
      // TODO: Save to local storage
    }
  }

  @override
  Future<void> restoreRule(String ruleId) async {
    if (_rules.containsKey(ruleId)) {
      final rule = _rules[ruleId]!;
      _rules[ruleId] = rule.copyWith(isArchived: false);
      // TODO: Save to local storage
    }
  }

  @override
  Future<void> togglePin(String ruleId) async {
    if (_rules.containsKey(ruleId)) {
      final rule = _rules[ruleId]!;
      _rules[ruleId] = rule.copyWith(isPinned: !rule.isPinned);
      // TODO: Save to local storage
    }
  }

  @override
  Future<void> markCompleted(String ruleId) async {
    if (_rules.containsKey(ruleId)) {
      final rule = _rules[ruleId]!;
      _rules[ruleId] = rule.copyWith(
        isCompleted: true,
        lastCompletedAt: DateTime.now(),
      );
      // TODO: Save to local storage
    }
  }

  @override
  Future<void> resetDailyCompletion() async {
    // Reset all daily rules completion status
    for (final rule in _rules.values) {
      if (rule.repeatDaily) {
        _rules[rule.id] = rule.copyWith(isCompleted: false);
      }
    }
    // TODO: Save to local storage
  }

  @override
  Future<List<UniversalRule>> getTodaysRules() async {
    return _rules.values
        .where((rule) =>
            !rule.isArchived && rule.repeatDaily)
        .toList();
  }
}
