// ignore_for_file: invalid_annotation_target
import 'package:freezed_annotation/freezed_annotation.dart';

part 'action_models.freezed.dart';
part 'action_models.g.dart';

@freezed
class ActionTemplate with _$ActionTemplate {
  const factory ActionTemplate({
    required String id,
    required String name,
    required String category,
    @JsonKey(name: 'base_xp') required int baseXp,
    @JsonKey(name: 'attr_strength') required int attrStrength,
    @JsonKey(name: 'attr_endurance') required int attrEndurance,
    @JsonKey(name: 'attr_knowledge') required int attrKnowledge,
  }) = _ActionTemplate;

  factory ActionTemplate.fromJson(Map<String, dynamic> json) => _$ActionTemplateFromJson(json);
}

@freezed
class ActionLog with _$ActionLog {
  const factory ActionLog({
    required String id,
    @JsonKey(name: 'occurred_at') required DateTime occurredAt,
    @JsonKey(name: 'duration_min') int? durationMin,
    String? notes,
    @JsonKey(name: 'earned_xp') required int earnedXp,
    @JsonKey(name: 'template_id') String? templateId,
    @JsonKey(name: 'activity_name') String? activityName,
    @JsonKey(name: 'image_url') String? imageUrl,
  }) = _ActionLog;

  factory ActionLog.fromJson(Map<String, dynamic> json) => _$ActionLogFromJson(json);
}

