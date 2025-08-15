// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'action_models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

ActionTemplate _$ActionTemplateFromJson(Map<String, dynamic> json) {
  return _ActionTemplate.fromJson(json);
}

/// @nodoc
mixin _$ActionTemplate {
  String get id => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  String get category => throw _privateConstructorUsedError;
  @JsonKey(name: 'base_xp')
  int get baseXp => throw _privateConstructorUsedError;
  @JsonKey(name: 'attr_strength')
  int get attrStrength => throw _privateConstructorUsedError;
  @JsonKey(name: 'attr_endurance')
  int get attrEndurance => throw _privateConstructorUsedError;
  @JsonKey(name: 'attr_knowledge')
  int get attrKnowledge => throw _privateConstructorUsedError;

  /// Serializes this ActionTemplate to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ActionTemplate
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ActionTemplateCopyWith<ActionTemplate> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ActionTemplateCopyWith<$Res> {
  factory $ActionTemplateCopyWith(
          ActionTemplate value, $Res Function(ActionTemplate) then) =
      _$ActionTemplateCopyWithImpl<$Res, ActionTemplate>;
  @useResult
  $Res call(
      {String id,
      String name,
      String category,
      @JsonKey(name: 'base_xp') int baseXp,
      @JsonKey(name: 'attr_strength') int attrStrength,
      @JsonKey(name: 'attr_endurance') int attrEndurance,
      @JsonKey(name: 'attr_knowledge') int attrKnowledge});
}

/// @nodoc
class _$ActionTemplateCopyWithImpl<$Res, $Val extends ActionTemplate>
    implements $ActionTemplateCopyWith<$Res> {
  _$ActionTemplateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ActionTemplate
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? category = null,
    Object? baseXp = null,
    Object? attrStrength = null,
    Object? attrEndurance = null,
    Object? attrKnowledge = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      category: null == category
          ? _value.category
          : category // ignore: cast_nullable_to_non_nullable
              as String,
      baseXp: null == baseXp
          ? _value.baseXp
          : baseXp // ignore: cast_nullable_to_non_nullable
              as int,
      attrStrength: null == attrStrength
          ? _value.attrStrength
          : attrStrength // ignore: cast_nullable_to_non_nullable
              as int,
      attrEndurance: null == attrEndurance
          ? _value.attrEndurance
          : attrEndurance // ignore: cast_nullable_to_non_nullable
              as int,
      attrKnowledge: null == attrKnowledge
          ? _value.attrKnowledge
          : attrKnowledge // ignore: cast_nullable_to_non_nullable
              as int,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$ActionTemplateImplCopyWith<$Res>
    implements $ActionTemplateCopyWith<$Res> {
  factory _$$ActionTemplateImplCopyWith(_$ActionTemplateImpl value,
          $Res Function(_$ActionTemplateImpl) then) =
      __$$ActionTemplateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String name,
      String category,
      @JsonKey(name: 'base_xp') int baseXp,
      @JsonKey(name: 'attr_strength') int attrStrength,
      @JsonKey(name: 'attr_endurance') int attrEndurance,
      @JsonKey(name: 'attr_knowledge') int attrKnowledge});
}

/// @nodoc
class __$$ActionTemplateImplCopyWithImpl<$Res>
    extends _$ActionTemplateCopyWithImpl<$Res, _$ActionTemplateImpl>
    implements _$$ActionTemplateImplCopyWith<$Res> {
  __$$ActionTemplateImplCopyWithImpl(
      _$ActionTemplateImpl _value, $Res Function(_$ActionTemplateImpl) _then)
      : super(_value, _then);

  /// Create a copy of ActionTemplate
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? category = null,
    Object? baseXp = null,
    Object? attrStrength = null,
    Object? attrEndurance = null,
    Object? attrKnowledge = null,
  }) {
    return _then(_$ActionTemplateImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      category: null == category
          ? _value.category
          : category // ignore: cast_nullable_to_non_nullable
              as String,
      baseXp: null == baseXp
          ? _value.baseXp
          : baseXp // ignore: cast_nullable_to_non_nullable
              as int,
      attrStrength: null == attrStrength
          ? _value.attrStrength
          : attrStrength // ignore: cast_nullable_to_non_nullable
              as int,
      attrEndurance: null == attrEndurance
          ? _value.attrEndurance
          : attrEndurance // ignore: cast_nullable_to_non_nullable
              as int,
      attrKnowledge: null == attrKnowledge
          ? _value.attrKnowledge
          : attrKnowledge // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$ActionTemplateImpl implements _ActionTemplate {
  const _$ActionTemplateImpl(
      {required this.id,
      required this.name,
      required this.category,
      @JsonKey(name: 'base_xp') required this.baseXp,
      @JsonKey(name: 'attr_strength') required this.attrStrength,
      @JsonKey(name: 'attr_endurance') required this.attrEndurance,
      @JsonKey(name: 'attr_knowledge') required this.attrKnowledge});

  factory _$ActionTemplateImpl.fromJson(Map<String, dynamic> json) =>
      _$$ActionTemplateImplFromJson(json);

  @override
  final String id;
  @override
  final String name;
  @override
  final String category;
  @override
  @JsonKey(name: 'base_xp')
  final int baseXp;
  @override
  @JsonKey(name: 'attr_strength')
  final int attrStrength;
  @override
  @JsonKey(name: 'attr_endurance')
  final int attrEndurance;
  @override
  @JsonKey(name: 'attr_knowledge')
  final int attrKnowledge;

  @override
  String toString() {
    return 'ActionTemplate(id: $id, name: $name, category: $category, baseXp: $baseXp, attrStrength: $attrStrength, attrEndurance: $attrEndurance, attrKnowledge: $attrKnowledge)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ActionTemplateImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.category, category) ||
                other.category == category) &&
            (identical(other.baseXp, baseXp) || other.baseXp == baseXp) &&
            (identical(other.attrStrength, attrStrength) ||
                other.attrStrength == attrStrength) &&
            (identical(other.attrEndurance, attrEndurance) ||
                other.attrEndurance == attrEndurance) &&
            (identical(other.attrKnowledge, attrKnowledge) ||
                other.attrKnowledge == attrKnowledge));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, name, category, baseXp,
      attrStrength, attrEndurance, attrKnowledge);

  /// Create a copy of ActionTemplate
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ActionTemplateImplCopyWith<_$ActionTemplateImpl> get copyWith =>
      __$$ActionTemplateImplCopyWithImpl<_$ActionTemplateImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ActionTemplateImplToJson(
      this,
    );
  }
}

abstract class _ActionTemplate implements ActionTemplate {
  const factory _ActionTemplate(
          {required final String id,
          required final String name,
          required final String category,
          @JsonKey(name: 'base_xp') required final int baseXp,
          @JsonKey(name: 'attr_strength') required final int attrStrength,
          @JsonKey(name: 'attr_endurance') required final int attrEndurance,
          @JsonKey(name: 'attr_knowledge') required final int attrKnowledge}) =
      _$ActionTemplateImpl;

  factory _ActionTemplate.fromJson(Map<String, dynamic> json) =
      _$ActionTemplateImpl.fromJson;

  @override
  String get id;
  @override
  String get name;
  @override
  String get category;
  @override
  @JsonKey(name: 'base_xp')
  int get baseXp;
  @override
  @JsonKey(name: 'attr_strength')
  int get attrStrength;
  @override
  @JsonKey(name: 'attr_endurance')
  int get attrEndurance;
  @override
  @JsonKey(name: 'attr_knowledge')
  int get attrKnowledge;

  /// Create a copy of ActionTemplate
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ActionTemplateImplCopyWith<_$ActionTemplateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

ActionLog _$ActionLogFromJson(Map<String, dynamic> json) {
  return _ActionLog.fromJson(json);
}

/// @nodoc
mixin _$ActionLog {
  String get id => throw _privateConstructorUsedError;
  @JsonKey(name: 'occurred_at')
  DateTime get occurredAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'duration_min')
  int? get durationMin => throw _privateConstructorUsedError;
  String? get notes => throw _privateConstructorUsedError;
  @JsonKey(name: 'earned_xp')
  int get earnedXp => throw _privateConstructorUsedError;
  @JsonKey(name: 'template_id')
  String? get templateId => throw _privateConstructorUsedError;
  @JsonKey(name: 'activity_name')
  String? get activityName => throw _privateConstructorUsedError;
  @JsonKey(name: 'image_url')
  String? get imageUrl => throw _privateConstructorUsedError;

  /// Serializes this ActionLog to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ActionLog
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ActionLogCopyWith<ActionLog> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ActionLogCopyWith<$Res> {
  factory $ActionLogCopyWith(ActionLog value, $Res Function(ActionLog) then) =
      _$ActionLogCopyWithImpl<$Res, ActionLog>;
  @useResult
  $Res call(
      {String id,
      @JsonKey(name: 'occurred_at') DateTime occurredAt,
      @JsonKey(name: 'duration_min') int? durationMin,
      String? notes,
      @JsonKey(name: 'earned_xp') int earnedXp,
      @JsonKey(name: 'template_id') String? templateId,
      @JsonKey(name: 'activity_name') String? activityName,
      @JsonKey(name: 'image_url') String? imageUrl});
}

/// @nodoc
class _$ActionLogCopyWithImpl<$Res, $Val extends ActionLog>
    implements $ActionLogCopyWith<$Res> {
  _$ActionLogCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ActionLog
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? occurredAt = null,
    Object? durationMin = freezed,
    Object? notes = freezed,
    Object? earnedXp = null,
    Object? templateId = freezed,
    Object? activityName = freezed,
    Object? imageUrl = freezed,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      occurredAt: null == occurredAt
          ? _value.occurredAt
          : occurredAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      durationMin: freezed == durationMin
          ? _value.durationMin
          : durationMin // ignore: cast_nullable_to_non_nullable
              as int?,
      notes: freezed == notes
          ? _value.notes
          : notes // ignore: cast_nullable_to_non_nullable
              as String?,
      earnedXp: null == earnedXp
          ? _value.earnedXp
          : earnedXp // ignore: cast_nullable_to_non_nullable
              as int,
      templateId: freezed == templateId
          ? _value.templateId
          : templateId // ignore: cast_nullable_to_non_nullable
              as String?,
      activityName: freezed == activityName
          ? _value.activityName
          : activityName // ignore: cast_nullable_to_non_nullable
              as String?,
      imageUrl: freezed == imageUrl
          ? _value.imageUrl
          : imageUrl // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$ActionLogImplCopyWith<$Res>
    implements $ActionLogCopyWith<$Res> {
  factory _$$ActionLogImplCopyWith(
          _$ActionLogImpl value, $Res Function(_$ActionLogImpl) then) =
      __$$ActionLogImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      @JsonKey(name: 'occurred_at') DateTime occurredAt,
      @JsonKey(name: 'duration_min') int? durationMin,
      String? notes,
      @JsonKey(name: 'earned_xp') int earnedXp,
      @JsonKey(name: 'template_id') String? templateId,
      @JsonKey(name: 'activity_name') String? activityName,
      @JsonKey(name: 'image_url') String? imageUrl});
}

/// @nodoc
class __$$ActionLogImplCopyWithImpl<$Res>
    extends _$ActionLogCopyWithImpl<$Res, _$ActionLogImpl>
    implements _$$ActionLogImplCopyWith<$Res> {
  __$$ActionLogImplCopyWithImpl(
      _$ActionLogImpl _value, $Res Function(_$ActionLogImpl) _then)
      : super(_value, _then);

  /// Create a copy of ActionLog
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? occurredAt = null,
    Object? durationMin = freezed,
    Object? notes = freezed,
    Object? earnedXp = null,
    Object? templateId = freezed,
    Object? activityName = freezed,
    Object? imageUrl = freezed,
  }) {
    return _then(_$ActionLogImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      occurredAt: null == occurredAt
          ? _value.occurredAt
          : occurredAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      durationMin: freezed == durationMin
          ? _value.durationMin
          : durationMin // ignore: cast_nullable_to_non_nullable
              as int?,
      notes: freezed == notes
          ? _value.notes
          : notes // ignore: cast_nullable_to_non_nullable
              as String?,
      earnedXp: null == earnedXp
          ? _value.earnedXp
          : earnedXp // ignore: cast_nullable_to_non_nullable
              as int,
      templateId: freezed == templateId
          ? _value.templateId
          : templateId // ignore: cast_nullable_to_non_nullable
              as String?,
      activityName: freezed == activityName
          ? _value.activityName
          : activityName // ignore: cast_nullable_to_non_nullable
              as String?,
      imageUrl: freezed == imageUrl
          ? _value.imageUrl
          : imageUrl // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$ActionLogImpl implements _ActionLog {
  const _$ActionLogImpl(
      {required this.id,
      @JsonKey(name: 'occurred_at') required this.occurredAt,
      @JsonKey(name: 'duration_min') this.durationMin,
      this.notes,
      @JsonKey(name: 'earned_xp') required this.earnedXp,
      @JsonKey(name: 'template_id') this.templateId,
      @JsonKey(name: 'activity_name') this.activityName,
      @JsonKey(name: 'image_url') this.imageUrl});

  factory _$ActionLogImpl.fromJson(Map<String, dynamic> json) =>
      _$$ActionLogImplFromJson(json);

  @override
  final String id;
  @override
  @JsonKey(name: 'occurred_at')
  final DateTime occurredAt;
  @override
  @JsonKey(name: 'duration_min')
  final int? durationMin;
  @override
  final String? notes;
  @override
  @JsonKey(name: 'earned_xp')
  final int earnedXp;
  @override
  @JsonKey(name: 'template_id')
  final String? templateId;
  @override
  @JsonKey(name: 'activity_name')
  final String? activityName;
  @override
  @JsonKey(name: 'image_url')
  final String? imageUrl;

  @override
  String toString() {
    return 'ActionLog(id: $id, occurredAt: $occurredAt, durationMin: $durationMin, notes: $notes, earnedXp: $earnedXp, templateId: $templateId, activityName: $activityName, imageUrl: $imageUrl)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ActionLogImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.occurredAt, occurredAt) ||
                other.occurredAt == occurredAt) &&
            (identical(other.durationMin, durationMin) ||
                other.durationMin == durationMin) &&
            (identical(other.notes, notes) || other.notes == notes) &&
            (identical(other.earnedXp, earnedXp) ||
                other.earnedXp == earnedXp) &&
            (identical(other.templateId, templateId) ||
                other.templateId == templateId) &&
            (identical(other.activityName, activityName) ||
                other.activityName == activityName) &&
            (identical(other.imageUrl, imageUrl) ||
                other.imageUrl == imageUrl));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, occurredAt, durationMin,
      notes, earnedXp, templateId, activityName, imageUrl);

  /// Create a copy of ActionLog
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ActionLogImplCopyWith<_$ActionLogImpl> get copyWith =>
      __$$ActionLogImplCopyWithImpl<_$ActionLogImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ActionLogImplToJson(
      this,
    );
  }
}

abstract class _ActionLog implements ActionLog {
  const factory _ActionLog(
      {required final String id,
      @JsonKey(name: 'occurred_at') required final DateTime occurredAt,
      @JsonKey(name: 'duration_min') final int? durationMin,
      final String? notes,
      @JsonKey(name: 'earned_xp') required final int earnedXp,
      @JsonKey(name: 'template_id') final String? templateId,
      @JsonKey(name: 'activity_name') final String? activityName,
      @JsonKey(name: 'image_url') final String? imageUrl}) = _$ActionLogImpl;

  factory _ActionLog.fromJson(Map<String, dynamic> json) =
      _$ActionLogImpl.fromJson;

  @override
  String get id;
  @override
  @JsonKey(name: 'occurred_at')
  DateTime get occurredAt;
  @override
  @JsonKey(name: 'duration_min')
  int? get durationMin;
  @override
  String? get notes;
  @override
  @JsonKey(name: 'earned_xp')
  int get earnedXp;
  @override
  @JsonKey(name: 'template_id')
  String? get templateId;
  @override
  @JsonKey(name: 'activity_name')
  String? get activityName;
  @override
  @JsonKey(name: 'image_url')
  String? get imageUrl;

  /// Create a copy of ActionLog
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ActionLogImplCopyWith<_$ActionLogImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
