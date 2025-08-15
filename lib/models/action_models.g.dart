// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'action_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ActionTemplateImpl _$$ActionTemplateImplFromJson(Map<String, dynamic> json) =>
    _$ActionTemplateImpl(
      id: json['id'] as String,
      name: json['name'] as String,
      category: json['category'] as String,
      baseXp: (json['base_xp'] as num).toInt(),
      attrStrength: (json['attr_strength'] as num).toInt(),
      attrEndurance: (json['attr_endurance'] as num).toInt(),
      attrKnowledge: (json['attr_knowledge'] as num).toInt(),
    );

Map<String, dynamic> _$$ActionTemplateImplToJson(
        _$ActionTemplateImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'category': instance.category,
      'base_xp': instance.baseXp,
      'attr_strength': instance.attrStrength,
      'attr_endurance': instance.attrEndurance,
      'attr_knowledge': instance.attrKnowledge,
    };

_$ActionLogImpl _$$ActionLogImplFromJson(Map<String, dynamic> json) =>
    _$ActionLogImpl(
      id: json['id'] as String,
      occurredAt: DateTime.parse(json['occurred_at'] as String),
      durationMin: (json['duration_min'] as num?)?.toInt(),
      notes: json['notes'] as String?,
      earnedXp: (json['earned_xp'] as num).toInt(),
      templateId: json['template_id'] as String?,
      activityName: json['activity_name'] as String?,
      imageUrl: json['image_url'] as String?,
    );

Map<String, dynamic> _$$ActionLogImplToJson(_$ActionLogImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'occurred_at': instance.occurredAt.toIso8601String(),
      'duration_min': instance.durationMin,
      'notes': instance.notes,
      'earned_xp': instance.earnedXp,
      'template_id': instance.templateId,
      'activity_name': instance.activityName,
      'image_url': instance.imageUrl,
    };
