// lib/core/prompt/prompt_manager.dart

import '../config/models.dart';
import 'prompt_builder.dart';
import 'task_prompts.dart';

/// Prompt 管理器 - 负责模块化 Prompt 的加载、版本管理和组装
class PromptManager {
  Future<String> build(AIRequest request) async {
    final context = request.context ?? const <String, dynamic>{};
    return PromptBuilder.build(
      userId: request.userId,
      taskType: _taskTypeFor(request.intent),
      userMessage: request.userInput,
      userContext: UserContext(
        userId: request.userId,
        isPremium: request.isPremium,
        constitution: context['constitution']?.toString(),
        currentSeason: context['current_season']?.toString() ?? 'spring',
        healthGoals: _stringList(context['health_goals']),
        recentTopics: _stringList(context['recent_topics']),
        lastCareStatus: context['last_care_status']?.toString(),
        followUpContext: context['follow_up_context']?.toString(),
      ),
    ).prompt;
  }

  TaskType _taskTypeFor(String? intent) => switch (intent) {
    'daily_plan' => TaskType.dailyPlan,
    'solar_term' => TaskType.solarTerm,
    'emotion_support' => TaskType.emotionSupport,
    'follow_up' => TaskType.followUp,
    'safe_mode' => TaskType.safeMode,
    'constitution' => TaskType.constitution,
    'dietary_advice' => TaskType.dietary,
    _ => TaskType.chat,
  };

  List<String> _stringList(Object? value) =>
      value is List ? value.map((item) => item.toString()).toList() : const [];
}
