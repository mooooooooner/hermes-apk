// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $SessionsTable extends Sessions with TableInfo<$SessionsTable, Session> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SessionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _previewMeta = const VerificationMeta(
    'preview',
  );
  @override
  late final GeneratedColumn<String> preview = GeneratedColumn<String>(
    'preview',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _activeRunIdMeta = const VerificationMeta(
    'activeRunId',
  );
  @override
  late final GeneratedColumn<String> activeRunId = GeneratedColumn<String>(
    'active_run_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _activeRunStateMeta = const VerificationMeta(
    'activeRunState',
  );
  @override
  late final GeneratedColumn<String> activeRunState = GeneratedColumn<String>(
    'active_run_state',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    createdAt,
    updatedAt,
    preview,
    activeRunId,
    activeRunState,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sessions';
  @override
  VerificationContext validateIntegrity(
    Insertable<Session> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('preview')) {
      context.handle(
        _previewMeta,
        preview.isAcceptableOrUnknown(data['preview']!, _previewMeta),
      );
    }
    if (data.containsKey('active_run_id')) {
      context.handle(
        _activeRunIdMeta,
        activeRunId.isAcceptableOrUnknown(
          data['active_run_id']!,
          _activeRunIdMeta,
        ),
      );
    }
    if (data.containsKey('active_run_state')) {
      context.handle(
        _activeRunStateMeta,
        activeRunState.isAcceptableOrUnknown(
          data['active_run_state']!,
          _activeRunStateMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Session map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Session(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      preview: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}preview'],
      )!,
      activeRunId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}active_run_id'],
      ),
      activeRunState: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}active_run_state'],
      ),
    );
  }

  @override
  $SessionsTable createAlias(String alias) {
    return $SessionsTable(attachedDatabase, alias);
  }
}

class Session extends DataClass implements Insertable<Session> {
  final String id;
  final String title;
  final int createdAt;
  final int updatedAt;
  final String preview;
  final String? activeRunId;
  final String? activeRunState;
  const Session({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    required this.preview,
    this.activeRunId,
    this.activeRunState,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    map['preview'] = Variable<String>(preview);
    if (!nullToAbsent || activeRunId != null) {
      map['active_run_id'] = Variable<String>(activeRunId);
    }
    if (!nullToAbsent || activeRunState != null) {
      map['active_run_state'] = Variable<String>(activeRunState);
    }
    return map;
  }

  SessionsCompanion toCompanion(bool nullToAbsent) {
    return SessionsCompanion(
      id: Value(id),
      title: Value(title),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      preview: Value(preview),
      activeRunId: activeRunId == null && nullToAbsent
          ? const Value.absent()
          : Value(activeRunId),
      activeRunState: activeRunState == null && nullToAbsent
          ? const Value.absent()
          : Value(activeRunState),
    );
  }

  factory Session.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Session(
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      preview: serializer.fromJson<String>(json['preview']),
      activeRunId: serializer.fromJson<String?>(json['activeRunId']),
      activeRunState: serializer.fromJson<String?>(json['activeRunState']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'preview': serializer.toJson<String>(preview),
      'activeRunId': serializer.toJson<String?>(activeRunId),
      'activeRunState': serializer.toJson<String?>(activeRunState),
    };
  }

  Session copyWith({
    String? id,
    String? title,
    int? createdAt,
    int? updatedAt,
    String? preview,
    Value<String?> activeRunId = const Value.absent(),
    Value<String?> activeRunState = const Value.absent(),
  }) => Session(
    id: id ?? this.id,
    title: title ?? this.title,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    preview: preview ?? this.preview,
    activeRunId: activeRunId.present ? activeRunId.value : this.activeRunId,
    activeRunState: activeRunState.present
        ? activeRunState.value
        : this.activeRunState,
  );
  Session copyWithCompanion(SessionsCompanion data) {
    return Session(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      preview: data.preview.present ? data.preview.value : this.preview,
      activeRunId: data.activeRunId.present
          ? data.activeRunId.value
          : this.activeRunId,
      activeRunState: data.activeRunState.present
          ? data.activeRunState.value
          : this.activeRunState,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Session(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('preview: $preview, ')
          ..write('activeRunId: $activeRunId, ')
          ..write('activeRunState: $activeRunState')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    title,
    createdAt,
    updatedAt,
    preview,
    activeRunId,
    activeRunState,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Session &&
          other.id == this.id &&
          other.title == this.title &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.preview == this.preview &&
          other.activeRunId == this.activeRunId &&
          other.activeRunState == this.activeRunState);
}

class SessionsCompanion extends UpdateCompanion<Session> {
  final Value<String> id;
  final Value<String> title;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<String> preview;
  final Value<String?> activeRunId;
  final Value<String?> activeRunState;
  final Value<int> rowid;
  const SessionsCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.preview = const Value.absent(),
    this.activeRunId = const Value.absent(),
    this.activeRunState = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SessionsCompanion.insert({
    required String id,
    required String title,
    required int createdAt,
    required int updatedAt,
    this.preview = const Value.absent(),
    this.activeRunId = const Value.absent(),
    this.activeRunState = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       title = Value(title),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<Session> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<String>? preview,
    Expression<String>? activeRunId,
    Expression<String>? activeRunState,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (preview != null) 'preview': preview,
      if (activeRunId != null) 'active_run_id': activeRunId,
      if (activeRunState != null) 'active_run_state': activeRunState,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SessionsCompanion copyWith({
    Value<String>? id,
    Value<String>? title,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<String>? preview,
    Value<String?>? activeRunId,
    Value<String?>? activeRunState,
    Value<int>? rowid,
  }) {
    return SessionsCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      preview: preview ?? this.preview,
      activeRunId: activeRunId ?? this.activeRunId,
      activeRunState: activeRunState ?? this.activeRunState,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (preview.present) {
      map['preview'] = Variable<String>(preview.value);
    }
    if (activeRunId.present) {
      map['active_run_id'] = Variable<String>(activeRunId.value);
    }
    if (activeRunState.present) {
      map['active_run_state'] = Variable<String>(activeRunState.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SessionsCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('preview: $preview, ')
          ..write('activeRunId: $activeRunId, ')
          ..write('activeRunState: $activeRunState, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MessagesTable extends Messages with TableInfo<$MessagesTable, Message> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MessagesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _sessionIdMeta = const VerificationMeta(
    'sessionId',
  );
  @override
  late final GeneratedColumn<String> sessionId = GeneratedColumn<String>(
    'session_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _roleMeta = const VerificationMeta('role');
  @override
  late final GeneratedColumn<String> role = GeneratedColumn<String>(
    'role',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contentMeta = const VerificationMeta(
    'content',
  );
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
    'content',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _reasoningMeta = const VerificationMeta(
    'reasoning',
  );
  @override
  late final GeneratedColumn<String> reasoning = GeneratedColumn<String>(
    'reasoning',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _runIdMeta = const VerificationMeta('runId');
  @override
  late final GeneratedColumn<String> runId = GeneratedColumn<String>(
    'run_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _seqMeta = const VerificationMeta('seq');
  @override
  late final GeneratedColumn<int> seq = GeneratedColumn<int>(
    'seq',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _attachmentsMeta = const VerificationMeta(
    'attachments',
  );
  @override
  late final GeneratedColumn<String> attachments = GeneratedColumn<String>(
    'attachments',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _toolEventsMeta = const VerificationMeta(
    'toolEvents',
  );
  @override
  late final GeneratedColumn<String> toolEvents = GeneratedColumn<String>(
    'tool_events',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _segmentsMeta = const VerificationMeta(
    'segments',
  );
  @override
  late final GeneratedColumn<String> segments = GeneratedColumn<String>(
    'segments',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _errorMeta = const VerificationMeta('error');
  @override
  late final GeneratedColumn<String> error = GeneratedColumn<String>(
    'error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _usageMeta = const VerificationMeta('usage');
  @override
  late final GeneratedColumn<String> usage = GeneratedColumn<String>(
    'usage',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _serverIdMeta = const VerificationMeta(
    'serverId',
  );
  @override
  late final GeneratedColumn<int> serverId = GeneratedColumn<int>(
    'server_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    sessionId,
    role,
    content,
    reasoning,
    status,
    runId,
    seq,
    createdAt,
    updatedAt,
    attachments,
    toolEvents,
    segments,
    error,
    usage,
    serverId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'messages';
  @override
  VerificationContext validateIntegrity(
    Insertable<Message> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('session_id')) {
      context.handle(
        _sessionIdMeta,
        sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('role')) {
      context.handle(
        _roleMeta,
        role.isAcceptableOrUnknown(data['role']!, _roleMeta),
      );
    } else if (isInserting) {
      context.missing(_roleMeta);
    }
    if (data.containsKey('content')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['content']!, _contentMeta),
      );
    }
    if (data.containsKey('reasoning')) {
      context.handle(
        _reasoningMeta,
        reasoning.isAcceptableOrUnknown(data['reasoning']!, _reasoningMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('run_id')) {
      context.handle(
        _runIdMeta,
        runId.isAcceptableOrUnknown(data['run_id']!, _runIdMeta),
      );
    }
    if (data.containsKey('seq')) {
      context.handle(
        _seqMeta,
        seq.isAcceptableOrUnknown(data['seq']!, _seqMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('attachments')) {
      context.handle(
        _attachmentsMeta,
        attachments.isAcceptableOrUnknown(
          data['attachments']!,
          _attachmentsMeta,
        ),
      );
    }
    if (data.containsKey('tool_events')) {
      context.handle(
        _toolEventsMeta,
        toolEvents.isAcceptableOrUnknown(data['tool_events']!, _toolEventsMeta),
      );
    }
    if (data.containsKey('segments')) {
      context.handle(
        _segmentsMeta,
        segments.isAcceptableOrUnknown(data['segments']!, _segmentsMeta),
      );
    }
    if (data.containsKey('error')) {
      context.handle(
        _errorMeta,
        error.isAcceptableOrUnknown(data['error']!, _errorMeta),
      );
    }
    if (data.containsKey('usage')) {
      context.handle(
        _usageMeta,
        usage.isAcceptableOrUnknown(data['usage']!, _usageMeta),
      );
    }
    if (data.containsKey('server_id')) {
      context.handle(
        _serverIdMeta,
        serverId.isAcceptableOrUnknown(data['server_id']!, _serverIdMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Message map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Message(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      sessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}session_id'],
      )!,
      role: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}role'],
      )!,
      content: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content'],
      )!,
      reasoning: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reasoning'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      runId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}run_id'],
      ),
      seq: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}seq'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      attachments: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}attachments'],
      )!,
      toolEvents: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tool_events'],
      )!,
      segments: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}segments'],
      )!,
      error: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}error'],
      ),
      usage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}usage'],
      ),
      serverId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}server_id'],
      ),
    );
  }

  @override
  $MessagesTable createAlias(String alias) {
    return $MessagesTable(attachedDatabase, alias);
  }
}

class Message extends DataClass implements Insertable<Message> {
  final int id;
  final String sessionId;
  final String role;
  final String content;
  final String reasoning;
  final String status;
  final String? runId;
  final int seq;
  final int createdAt;
  final int updatedAt;
  final String attachments;
  final String toolEvents;
  final String segments;
  final String? error;
  final String? usage;
  final int? serverId;
  const Message({
    required this.id,
    required this.sessionId,
    required this.role,
    required this.content,
    required this.reasoning,
    required this.status,
    this.runId,
    required this.seq,
    required this.createdAt,
    required this.updatedAt,
    required this.attachments,
    required this.toolEvents,
    required this.segments,
    this.error,
    this.usage,
    this.serverId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['session_id'] = Variable<String>(sessionId);
    map['role'] = Variable<String>(role);
    map['content'] = Variable<String>(content);
    map['reasoning'] = Variable<String>(reasoning);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || runId != null) {
      map['run_id'] = Variable<String>(runId);
    }
    map['seq'] = Variable<int>(seq);
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    map['attachments'] = Variable<String>(attachments);
    map['tool_events'] = Variable<String>(toolEvents);
    map['segments'] = Variable<String>(segments);
    if (!nullToAbsent || error != null) {
      map['error'] = Variable<String>(error);
    }
    if (!nullToAbsent || usage != null) {
      map['usage'] = Variable<String>(usage);
    }
    if (!nullToAbsent || serverId != null) {
      map['server_id'] = Variable<int>(serverId);
    }
    return map;
  }

  MessagesCompanion toCompanion(bool nullToAbsent) {
    return MessagesCompanion(
      id: Value(id),
      sessionId: Value(sessionId),
      role: Value(role),
      content: Value(content),
      reasoning: Value(reasoning),
      status: Value(status),
      runId: runId == null && nullToAbsent
          ? const Value.absent()
          : Value(runId),
      seq: Value(seq),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      attachments: Value(attachments),
      toolEvents: Value(toolEvents),
      segments: Value(segments),
      error: error == null && nullToAbsent
          ? const Value.absent()
          : Value(error),
      usage: usage == null && nullToAbsent
          ? const Value.absent()
          : Value(usage),
      serverId: serverId == null && nullToAbsent
          ? const Value.absent()
          : Value(serverId),
    );
  }

  factory Message.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Message(
      id: serializer.fromJson<int>(json['id']),
      sessionId: serializer.fromJson<String>(json['sessionId']),
      role: serializer.fromJson<String>(json['role']),
      content: serializer.fromJson<String>(json['content']),
      reasoning: serializer.fromJson<String>(json['reasoning']),
      status: serializer.fromJson<String>(json['status']),
      runId: serializer.fromJson<String?>(json['runId']),
      seq: serializer.fromJson<int>(json['seq']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      attachments: serializer.fromJson<String>(json['attachments']),
      toolEvents: serializer.fromJson<String>(json['toolEvents']),
      segments: serializer.fromJson<String>(json['segments']),
      error: serializer.fromJson<String?>(json['error']),
      usage: serializer.fromJson<String?>(json['usage']),
      serverId: serializer.fromJson<int?>(json['serverId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'sessionId': serializer.toJson<String>(sessionId),
      'role': serializer.toJson<String>(role),
      'content': serializer.toJson<String>(content),
      'reasoning': serializer.toJson<String>(reasoning),
      'status': serializer.toJson<String>(status),
      'runId': serializer.toJson<String?>(runId),
      'seq': serializer.toJson<int>(seq),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'attachments': serializer.toJson<String>(attachments),
      'toolEvents': serializer.toJson<String>(toolEvents),
      'segments': serializer.toJson<String>(segments),
      'error': serializer.toJson<String?>(error),
      'usage': serializer.toJson<String?>(usage),
      'serverId': serializer.toJson<int?>(serverId),
    };
  }

  Message copyWith({
    int? id,
    String? sessionId,
    String? role,
    String? content,
    String? reasoning,
    String? status,
    Value<String?> runId = const Value.absent(),
    int? seq,
    int? createdAt,
    int? updatedAt,
    String? attachments,
    String? toolEvents,
    String? segments,
    Value<String?> error = const Value.absent(),
    Value<String?> usage = const Value.absent(),
    Value<int?> serverId = const Value.absent(),
  }) => Message(
    id: id ?? this.id,
    sessionId: sessionId ?? this.sessionId,
    role: role ?? this.role,
    content: content ?? this.content,
    reasoning: reasoning ?? this.reasoning,
    status: status ?? this.status,
    runId: runId.present ? runId.value : this.runId,
    seq: seq ?? this.seq,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    attachments: attachments ?? this.attachments,
    toolEvents: toolEvents ?? this.toolEvents,
    segments: segments ?? this.segments,
    error: error.present ? error.value : this.error,
    usage: usage.present ? usage.value : this.usage,
    serverId: serverId.present ? serverId.value : this.serverId,
  );
  Message copyWithCompanion(MessagesCompanion data) {
    return Message(
      id: data.id.present ? data.id.value : this.id,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      role: data.role.present ? data.role.value : this.role,
      content: data.content.present ? data.content.value : this.content,
      reasoning: data.reasoning.present ? data.reasoning.value : this.reasoning,
      status: data.status.present ? data.status.value : this.status,
      runId: data.runId.present ? data.runId.value : this.runId,
      seq: data.seq.present ? data.seq.value : this.seq,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      attachments: data.attachments.present
          ? data.attachments.value
          : this.attachments,
      toolEvents: data.toolEvents.present
          ? data.toolEvents.value
          : this.toolEvents,
      segments: data.segments.present ? data.segments.value : this.segments,
      error: data.error.present ? data.error.value : this.error,
      usage: data.usage.present ? data.usage.value : this.usage,
      serverId: data.serverId.present ? data.serverId.value : this.serverId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Message(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('role: $role, ')
          ..write('content: $content, ')
          ..write('reasoning: $reasoning, ')
          ..write('status: $status, ')
          ..write('runId: $runId, ')
          ..write('seq: $seq, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('attachments: $attachments, ')
          ..write('toolEvents: $toolEvents, ')
          ..write('segments: $segments, ')
          ..write('error: $error, ')
          ..write('usage: $usage, ')
          ..write('serverId: $serverId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    sessionId,
    role,
    content,
    reasoning,
    status,
    runId,
    seq,
    createdAt,
    updatedAt,
    attachments,
    toolEvents,
    segments,
    error,
    usage,
    serverId,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Message &&
          other.id == this.id &&
          other.sessionId == this.sessionId &&
          other.role == this.role &&
          other.content == this.content &&
          other.reasoning == this.reasoning &&
          other.status == this.status &&
          other.runId == this.runId &&
          other.seq == this.seq &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.attachments == this.attachments &&
          other.toolEvents == this.toolEvents &&
          other.segments == this.segments &&
          other.error == this.error &&
          other.usage == this.usage &&
          other.serverId == this.serverId);
}

class MessagesCompanion extends UpdateCompanion<Message> {
  final Value<int> id;
  final Value<String> sessionId;
  final Value<String> role;
  final Value<String> content;
  final Value<String> reasoning;
  final Value<String> status;
  final Value<String?> runId;
  final Value<int> seq;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<String> attachments;
  final Value<String> toolEvents;
  final Value<String> segments;
  final Value<String?> error;
  final Value<String?> usage;
  final Value<int?> serverId;
  const MessagesCompanion({
    this.id = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.role = const Value.absent(),
    this.content = const Value.absent(),
    this.reasoning = const Value.absent(),
    this.status = const Value.absent(),
    this.runId = const Value.absent(),
    this.seq = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.attachments = const Value.absent(),
    this.toolEvents = const Value.absent(),
    this.segments = const Value.absent(),
    this.error = const Value.absent(),
    this.usage = const Value.absent(),
    this.serverId = const Value.absent(),
  });
  MessagesCompanion.insert({
    this.id = const Value.absent(),
    required String sessionId,
    required String role,
    this.content = const Value.absent(),
    this.reasoning = const Value.absent(),
    required String status,
    this.runId = const Value.absent(),
    this.seq = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.attachments = const Value.absent(),
    this.toolEvents = const Value.absent(),
    this.segments = const Value.absent(),
    this.error = const Value.absent(),
    this.usage = const Value.absent(),
    this.serverId = const Value.absent(),
  }) : sessionId = Value(sessionId),
       role = Value(role),
       status = Value(status);
  static Insertable<Message> custom({
    Expression<int>? id,
    Expression<String>? sessionId,
    Expression<String>? role,
    Expression<String>? content,
    Expression<String>? reasoning,
    Expression<String>? status,
    Expression<String>? runId,
    Expression<int>? seq,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<String>? attachments,
    Expression<String>? toolEvents,
    Expression<String>? segments,
    Expression<String>? error,
    Expression<String>? usage,
    Expression<int>? serverId,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sessionId != null) 'session_id': sessionId,
      if (role != null) 'role': role,
      if (content != null) 'content': content,
      if (reasoning != null) 'reasoning': reasoning,
      if (status != null) 'status': status,
      if (runId != null) 'run_id': runId,
      if (seq != null) 'seq': seq,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (attachments != null) 'attachments': attachments,
      if (toolEvents != null) 'tool_events': toolEvents,
      if (segments != null) 'segments': segments,
      if (error != null) 'error': error,
      if (usage != null) 'usage': usage,
      if (serverId != null) 'server_id': serverId,
    });
  }

  MessagesCompanion copyWith({
    Value<int>? id,
    Value<String>? sessionId,
    Value<String>? role,
    Value<String>? content,
    Value<String>? reasoning,
    Value<String>? status,
    Value<String?>? runId,
    Value<int>? seq,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<String>? attachments,
    Value<String>? toolEvents,
    Value<String>? segments,
    Value<String?>? error,
    Value<String?>? usage,
    Value<int?>? serverId,
  }) {
    return MessagesCompanion(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      role: role ?? this.role,
      content: content ?? this.content,
      reasoning: reasoning ?? this.reasoning,
      status: status ?? this.status,
      runId: runId ?? this.runId,
      seq: seq ?? this.seq,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      attachments: attachments ?? this.attachments,
      toolEvents: toolEvents ?? this.toolEvents,
      segments: segments ?? this.segments,
      error: error ?? this.error,
      usage: usage ?? this.usage,
      serverId: serverId ?? this.serverId,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (role.present) {
      map['role'] = Variable<String>(role.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (reasoning.present) {
      map['reasoning'] = Variable<String>(reasoning.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (runId.present) {
      map['run_id'] = Variable<String>(runId.value);
    }
    if (seq.present) {
      map['seq'] = Variable<int>(seq.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (attachments.present) {
      map['attachments'] = Variable<String>(attachments.value);
    }
    if (toolEvents.present) {
      map['tool_events'] = Variable<String>(toolEvents.value);
    }
    if (segments.present) {
      map['segments'] = Variable<String>(segments.value);
    }
    if (error.present) {
      map['error'] = Variable<String>(error.value);
    }
    if (usage.present) {
      map['usage'] = Variable<String>(usage.value);
    }
    if (serverId.present) {
      map['server_id'] = Variable<int>(serverId.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MessagesCompanion(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('role: $role, ')
          ..write('content: $content, ')
          ..write('reasoning: $reasoning, ')
          ..write('status: $status, ')
          ..write('runId: $runId, ')
          ..write('seq: $seq, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('attachments: $attachments, ')
          ..write('toolEvents: $toolEvents, ')
          ..write('segments: $segments, ')
          ..write('error: $error, ')
          ..write('usage: $usage, ')
          ..write('serverId: $serverId')
          ..write(')'))
        .toString();
  }
}

class $RunsTable extends Runs with TableInfo<$RunsTable, Run> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RunsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _runIdMeta = const VerificationMeta('runId');
  @override
  late final GeneratedColumn<String> runId = GeneratedColumn<String>(
    'run_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sessionIdMeta = const VerificationMeta(
    'sessionId',
  );
  @override
  late final GeneratedColumn<String> sessionId = GeneratedColumn<String>(
    'session_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _userMessageIdMeta = const VerificationMeta(
    'userMessageId',
  );
  @override
  late final GeneratedColumn<int> userMessageId = GeneratedColumn<int>(
    'user_message_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _assistantMessageIdMeta =
      const VerificationMeta('assistantMessageId');
  @override
  late final GeneratedColumn<int> assistantMessageId = GeneratedColumn<int>(
    'assistant_message_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _outputMeta = const VerificationMeta('output');
  @override
  late final GeneratedColumn<String> output = GeneratedColumn<String>(
    'output',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _errorMeta = const VerificationMeta('error');
  @override
  late final GeneratedColumn<String> error = GeneratedColumn<String>(
    'error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastEventMeta = const VerificationMeta(
    'lastEvent',
  );
  @override
  late final GeneratedColumn<String> lastEvent = GeneratedColumn<String>(
    'last_event',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _notifiedMeta = const VerificationMeta(
    'notified',
  );
  @override
  late final GeneratedColumn<bool> notified = GeneratedColumn<bool>(
    'notified',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("notified" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _usageMeta = const VerificationMeta('usage');
  @override
  late final GeneratedColumn<String> usage = GeneratedColumn<String>(
    'usage',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    runId,
    sessionId,
    userMessageId,
    assistantMessageId,
    status,
    output,
    error,
    lastEvent,
    createdAt,
    updatedAt,
    notified,
    usage,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'runs';
  @override
  VerificationContext validateIntegrity(
    Insertable<Run> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('run_id')) {
      context.handle(
        _runIdMeta,
        runId.isAcceptableOrUnknown(data['run_id']!, _runIdMeta),
      );
    } else if (isInserting) {
      context.missing(_runIdMeta);
    }
    if (data.containsKey('session_id')) {
      context.handle(
        _sessionIdMeta,
        sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('user_message_id')) {
      context.handle(
        _userMessageIdMeta,
        userMessageId.isAcceptableOrUnknown(
          data['user_message_id']!,
          _userMessageIdMeta,
        ),
      );
    }
    if (data.containsKey('assistant_message_id')) {
      context.handle(
        _assistantMessageIdMeta,
        assistantMessageId.isAcceptableOrUnknown(
          data['assistant_message_id']!,
          _assistantMessageIdMeta,
        ),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('output')) {
      context.handle(
        _outputMeta,
        output.isAcceptableOrUnknown(data['output']!, _outputMeta),
      );
    }
    if (data.containsKey('error')) {
      context.handle(
        _errorMeta,
        error.isAcceptableOrUnknown(data['error']!, _errorMeta),
      );
    }
    if (data.containsKey('last_event')) {
      context.handle(
        _lastEventMeta,
        lastEvent.isAcceptableOrUnknown(data['last_event']!, _lastEventMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('notified')) {
      context.handle(
        _notifiedMeta,
        notified.isAcceptableOrUnknown(data['notified']!, _notifiedMeta),
      );
    }
    if (data.containsKey('usage')) {
      context.handle(
        _usageMeta,
        usage.isAcceptableOrUnknown(data['usage']!, _usageMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => const {};
  @override
  Run map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Run(
      runId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}run_id'],
      )!,
      sessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}session_id'],
      )!,
      userMessageId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}user_message_id'],
      ),
      assistantMessageId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}assistant_message_id'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      output: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}output'],
      ),
      error: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}error'],
      ),
      lastEvent: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_event'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      notified: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}notified'],
      )!,
      usage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}usage'],
      ),
    );
  }

  @override
  $RunsTable createAlias(String alias) {
    return $RunsTable(attachedDatabase, alias);
  }
}

class Run extends DataClass implements Insertable<Run> {
  final String runId;
  final String sessionId;
  final int? userMessageId;
  final int? assistantMessageId;
  final String status;
  final String? output;
  final String? error;
  final String? lastEvent;
  final int createdAt;
  final int updatedAt;
  final bool notified;
  final String? usage;
  const Run({
    required this.runId,
    required this.sessionId,
    this.userMessageId,
    this.assistantMessageId,
    required this.status,
    this.output,
    this.error,
    this.lastEvent,
    required this.createdAt,
    required this.updatedAt,
    required this.notified,
    this.usage,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['run_id'] = Variable<String>(runId);
    map['session_id'] = Variable<String>(sessionId);
    if (!nullToAbsent || userMessageId != null) {
      map['user_message_id'] = Variable<int>(userMessageId);
    }
    if (!nullToAbsent || assistantMessageId != null) {
      map['assistant_message_id'] = Variable<int>(assistantMessageId);
    }
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || output != null) {
      map['output'] = Variable<String>(output);
    }
    if (!nullToAbsent || error != null) {
      map['error'] = Variable<String>(error);
    }
    if (!nullToAbsent || lastEvent != null) {
      map['last_event'] = Variable<String>(lastEvent);
    }
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    map['notified'] = Variable<bool>(notified);
    if (!nullToAbsent || usage != null) {
      map['usage'] = Variable<String>(usage);
    }
    return map;
  }

  RunsCompanion toCompanion(bool nullToAbsent) {
    return RunsCompanion(
      runId: Value(runId),
      sessionId: Value(sessionId),
      userMessageId: userMessageId == null && nullToAbsent
          ? const Value.absent()
          : Value(userMessageId),
      assistantMessageId: assistantMessageId == null && nullToAbsent
          ? const Value.absent()
          : Value(assistantMessageId),
      status: Value(status),
      output: output == null && nullToAbsent
          ? const Value.absent()
          : Value(output),
      error: error == null && nullToAbsent
          ? const Value.absent()
          : Value(error),
      lastEvent: lastEvent == null && nullToAbsent
          ? const Value.absent()
          : Value(lastEvent),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      notified: Value(notified),
      usage: usage == null && nullToAbsent
          ? const Value.absent()
          : Value(usage),
    );
  }

  factory Run.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Run(
      runId: serializer.fromJson<String>(json['runId']),
      sessionId: serializer.fromJson<String>(json['sessionId']),
      userMessageId: serializer.fromJson<int?>(json['userMessageId']),
      assistantMessageId: serializer.fromJson<int?>(json['assistantMessageId']),
      status: serializer.fromJson<String>(json['status']),
      output: serializer.fromJson<String?>(json['output']),
      error: serializer.fromJson<String?>(json['error']),
      lastEvent: serializer.fromJson<String?>(json['lastEvent']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      notified: serializer.fromJson<bool>(json['notified']),
      usage: serializer.fromJson<String?>(json['usage']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'runId': serializer.toJson<String>(runId),
      'sessionId': serializer.toJson<String>(sessionId),
      'userMessageId': serializer.toJson<int?>(userMessageId),
      'assistantMessageId': serializer.toJson<int?>(assistantMessageId),
      'status': serializer.toJson<String>(status),
      'output': serializer.toJson<String?>(output),
      'error': serializer.toJson<String?>(error),
      'lastEvent': serializer.toJson<String?>(lastEvent),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'notified': serializer.toJson<bool>(notified),
      'usage': serializer.toJson<String?>(usage),
    };
  }

  Run copyWith({
    String? runId,
    String? sessionId,
    Value<int?> userMessageId = const Value.absent(),
    Value<int?> assistantMessageId = const Value.absent(),
    String? status,
    Value<String?> output = const Value.absent(),
    Value<String?> error = const Value.absent(),
    Value<String?> lastEvent = const Value.absent(),
    int? createdAt,
    int? updatedAt,
    bool? notified,
    Value<String?> usage = const Value.absent(),
  }) => Run(
    runId: runId ?? this.runId,
    sessionId: sessionId ?? this.sessionId,
    userMessageId: userMessageId.present
        ? userMessageId.value
        : this.userMessageId,
    assistantMessageId: assistantMessageId.present
        ? assistantMessageId.value
        : this.assistantMessageId,
    status: status ?? this.status,
    output: output.present ? output.value : this.output,
    error: error.present ? error.value : this.error,
    lastEvent: lastEvent.present ? lastEvent.value : this.lastEvent,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    notified: notified ?? this.notified,
    usage: usage.present ? usage.value : this.usage,
  );
  Run copyWithCompanion(RunsCompanion data) {
    return Run(
      runId: data.runId.present ? data.runId.value : this.runId,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      userMessageId: data.userMessageId.present
          ? data.userMessageId.value
          : this.userMessageId,
      assistantMessageId: data.assistantMessageId.present
          ? data.assistantMessageId.value
          : this.assistantMessageId,
      status: data.status.present ? data.status.value : this.status,
      output: data.output.present ? data.output.value : this.output,
      error: data.error.present ? data.error.value : this.error,
      lastEvent: data.lastEvent.present ? data.lastEvent.value : this.lastEvent,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      notified: data.notified.present ? data.notified.value : this.notified,
      usage: data.usage.present ? data.usage.value : this.usage,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Run(')
          ..write('runId: $runId, ')
          ..write('sessionId: $sessionId, ')
          ..write('userMessageId: $userMessageId, ')
          ..write('assistantMessageId: $assistantMessageId, ')
          ..write('status: $status, ')
          ..write('output: $output, ')
          ..write('error: $error, ')
          ..write('lastEvent: $lastEvent, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('notified: $notified, ')
          ..write('usage: $usage')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    runId,
    sessionId,
    userMessageId,
    assistantMessageId,
    status,
    output,
    error,
    lastEvent,
    createdAt,
    updatedAt,
    notified,
    usage,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Run &&
          other.runId == this.runId &&
          other.sessionId == this.sessionId &&
          other.userMessageId == this.userMessageId &&
          other.assistantMessageId == this.assistantMessageId &&
          other.status == this.status &&
          other.output == this.output &&
          other.error == this.error &&
          other.lastEvent == this.lastEvent &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.notified == this.notified &&
          other.usage == this.usage);
}

class RunsCompanion extends UpdateCompanion<Run> {
  final Value<String> runId;
  final Value<String> sessionId;
  final Value<int?> userMessageId;
  final Value<int?> assistantMessageId;
  final Value<String> status;
  final Value<String?> output;
  final Value<String?> error;
  final Value<String?> lastEvent;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<bool> notified;
  final Value<String?> usage;
  final Value<int> rowid;
  const RunsCompanion({
    this.runId = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.userMessageId = const Value.absent(),
    this.assistantMessageId = const Value.absent(),
    this.status = const Value.absent(),
    this.output = const Value.absent(),
    this.error = const Value.absent(),
    this.lastEvent = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.notified = const Value.absent(),
    this.usage = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RunsCompanion.insert({
    required String runId,
    required String sessionId,
    this.userMessageId = const Value.absent(),
    this.assistantMessageId = const Value.absent(),
    required String status,
    this.output = const Value.absent(),
    this.error = const Value.absent(),
    this.lastEvent = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.notified = const Value.absent(),
    this.usage = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : runId = Value(runId),
       sessionId = Value(sessionId),
       status = Value(status);
  static Insertable<Run> custom({
    Expression<String>? runId,
    Expression<String>? sessionId,
    Expression<int>? userMessageId,
    Expression<int>? assistantMessageId,
    Expression<String>? status,
    Expression<String>? output,
    Expression<String>? error,
    Expression<String>? lastEvent,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<bool>? notified,
    Expression<String>? usage,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (runId != null) 'run_id': runId,
      if (sessionId != null) 'session_id': sessionId,
      if (userMessageId != null) 'user_message_id': userMessageId,
      if (assistantMessageId != null)
        'assistant_message_id': assistantMessageId,
      if (status != null) 'status': status,
      if (output != null) 'output': output,
      if (error != null) 'error': error,
      if (lastEvent != null) 'last_event': lastEvent,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (notified != null) 'notified': notified,
      if (usage != null) 'usage': usage,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RunsCompanion copyWith({
    Value<String>? runId,
    Value<String>? sessionId,
    Value<int?>? userMessageId,
    Value<int?>? assistantMessageId,
    Value<String>? status,
    Value<String?>? output,
    Value<String?>? error,
    Value<String?>? lastEvent,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<bool>? notified,
    Value<String?>? usage,
    Value<int>? rowid,
  }) {
    return RunsCompanion(
      runId: runId ?? this.runId,
      sessionId: sessionId ?? this.sessionId,
      userMessageId: userMessageId ?? this.userMessageId,
      assistantMessageId: assistantMessageId ?? this.assistantMessageId,
      status: status ?? this.status,
      output: output ?? this.output,
      error: error ?? this.error,
      lastEvent: lastEvent ?? this.lastEvent,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      notified: notified ?? this.notified,
      usage: usage ?? this.usage,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (runId.present) {
      map['run_id'] = Variable<String>(runId.value);
    }
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (userMessageId.present) {
      map['user_message_id'] = Variable<int>(userMessageId.value);
    }
    if (assistantMessageId.present) {
      map['assistant_message_id'] = Variable<int>(assistantMessageId.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (output.present) {
      map['output'] = Variable<String>(output.value);
    }
    if (error.present) {
      map['error'] = Variable<String>(error.value);
    }
    if (lastEvent.present) {
      map['last_event'] = Variable<String>(lastEvent.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (notified.present) {
      map['notified'] = Variable<bool>(notified.value);
    }
    if (usage.present) {
      map['usage'] = Variable<String>(usage.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RunsCompanion(')
          ..write('runId: $runId, ')
          ..write('sessionId: $sessionId, ')
          ..write('userMessageId: $userMessageId, ')
          ..write('assistantMessageId: $assistantMessageId, ')
          ..write('status: $status, ')
          ..write('output: $output, ')
          ..write('error: $error, ')
          ..write('lastEvent: $lastEvent, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('notified: $notified, ')
          ..write('usage: $usage, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$HermesDatabase extends GeneratedDatabase {
  _$HermesDatabase(QueryExecutor e) : super(e);
  $HermesDatabaseManager get managers => $HermesDatabaseManager(this);
  late final $SessionsTable sessions = $SessionsTable(this);
  late final $MessagesTable messages = $MessagesTable(this);
  late final $RunsTable runs = $RunsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    sessions,
    messages,
    runs,
  ];
}

typedef $$SessionsTableCreateCompanionBuilder = SessionsCompanion Function({
  required String id,
  required String title,
  required int createdAt,
  required int updatedAt,
  Value<String> preview,
  Value<String?> activeRunId,
  Value<String?> activeRunState,
  Value<int> rowid,
});
typedef $$SessionsTableUpdateCompanionBuilder = SessionsCompanion Function({
  Value<String> id,
  Value<String> title,
  Value<int> createdAt,
  Value<int> updatedAt,
  Value<String> preview,
  Value<String?> activeRunId,
  Value<String?> activeRunState,
  Value<int> rowid,
});

class $$SessionsTableFilterComposer
    extends Composer<_$HermesDatabase, $SessionsTable> {
  $$SessionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get preview => $composableBuilder(
    column: $table.preview,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get activeRunId => $composableBuilder(
    column: $table.activeRunId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get activeRunState => $composableBuilder(
    column: $table.activeRunState,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SessionsTableOrderingComposer
    extends Composer<_$HermesDatabase, $SessionsTable> {
  $$SessionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get preview => $composableBuilder(
    column: $table.preview,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get activeRunId => $composableBuilder(
    column: $table.activeRunId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get activeRunState => $composableBuilder(
    column: $table.activeRunState,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SessionsTableAnnotationComposer
    extends Composer<_$HermesDatabase, $SessionsTable> {
  $$SessionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get preview =>
      $composableBuilder(column: $table.preview, builder: (column) => column);

  GeneratedColumn<String> get activeRunId => $composableBuilder(
    column: $table.activeRunId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get activeRunState => $composableBuilder(
    column: $table.activeRunState,
    builder: (column) => column,
  );
}

class $$SessionsTableTableManager
    extends
        RootTableManager<
          _$HermesDatabase,
          $SessionsTable,
          Session,
          $$SessionsTableFilterComposer,
          $$SessionsTableOrderingComposer,
          $$SessionsTableAnnotationComposer,
          $$SessionsTableCreateCompanionBuilder,
          $$SessionsTableUpdateCompanionBuilder,
          (Session, BaseReferences<_$HermesDatabase, $SessionsTable, Session>),
          Session,
          PrefetchHooks Function()
        > {
  $$SessionsTableTableManager(_$HermesDatabase db, $SessionsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SessionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SessionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SessionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<String> preview = const Value.absent(),
                Value<String?> activeRunId = const Value.absent(),
                Value<String?> activeRunState = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SessionsCompanion(
                id: id,
                title: title,
                createdAt: createdAt,
                updatedAt: updatedAt,
                preview: preview,
                activeRunId: activeRunId,
                activeRunState: activeRunState,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String title,
                required int createdAt,
                required int updatedAt,
                Value<String> preview = const Value.absent(),
                Value<String?> activeRunId = const Value.absent(),
                Value<String?> activeRunState = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SessionsCompanion.insert(
                id: id,
                title: title,
                createdAt: createdAt,
                updatedAt: updatedAt,
                preview: preview,
                activeRunId: activeRunId,
                activeRunState: activeRunState,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SessionsTable, Session>(table),
                  BaseReferences<_$HermesDatabase, $SessionsTable, Session>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SessionsTableProcessedTableManager =
    ProcessedTableManager<
      _$HermesDatabase,
      $SessionsTable,
      Session,
      $$SessionsTableFilterComposer,
      $$SessionsTableOrderingComposer,
      $$SessionsTableAnnotationComposer,
      $$SessionsTableCreateCompanionBuilder,
      $$SessionsTableUpdateCompanionBuilder,
      (Session, BaseReferences<_$HermesDatabase, $SessionsTable, Session>),
      Session,
      PrefetchHooks Function()
    >;
typedef $$MessagesTableCreateCompanionBuilder = MessagesCompanion Function({
  Value<int> id,
  required String sessionId,
  required String role,
  Value<String> content,
  Value<String> reasoning,
  required String status,
  Value<String?> runId,
  Value<int> seq,
  Value<int> createdAt,
  Value<int> updatedAt,
  Value<String> attachments,
  Value<String> toolEvents,
  Value<String> segments,
  Value<String?> error,
  Value<String?> usage,
  Value<int?> serverId,
});
typedef $$MessagesTableUpdateCompanionBuilder = MessagesCompanion Function({
  Value<int> id,
  Value<String> sessionId,
  Value<String> role,
  Value<String> content,
  Value<String> reasoning,
  Value<String> status,
  Value<String?> runId,
  Value<int> seq,
  Value<int> createdAt,
  Value<int> updatedAt,
  Value<String> attachments,
  Value<String> toolEvents,
  Value<String> segments,
  Value<String?> error,
  Value<String?> usage,
  Value<int?> serverId,
});

class $$MessagesTableFilterComposer
    extends Composer<_$HermesDatabase, $MessagesTable> {
  $$MessagesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sessionId => $composableBuilder(
    column: $table.sessionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reasoning => $composableBuilder(
    column: $table.reasoning,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get runId => $composableBuilder(
    column: $table.runId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get seq => $composableBuilder(
    column: $table.seq,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get attachments => $composableBuilder(
    column: $table.attachments,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get toolEvents => $composableBuilder(
    column: $table.toolEvents,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get segments => $composableBuilder(
    column: $table.segments,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get error => $composableBuilder(
    column: $table.error,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get usage => $composableBuilder(
    column: $table.usage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$MessagesTableOrderingComposer
    extends Composer<_$HermesDatabase, $MessagesTable> {
  $$MessagesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sessionId => $composableBuilder(
    column: $table.sessionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reasoning => $composableBuilder(
    column: $table.reasoning,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get runId => $composableBuilder(
    column: $table.runId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get seq => $composableBuilder(
    column: $table.seq,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get attachments => $composableBuilder(
    column: $table.attachments,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get toolEvents => $composableBuilder(
    column: $table.toolEvents,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get segments => $composableBuilder(
    column: $table.segments,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get error => $composableBuilder(
    column: $table.error,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get usage => $composableBuilder(
    column: $table.usage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MessagesTableAnnotationComposer
    extends Composer<_$HermesDatabase, $MessagesTable> {
  $$MessagesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get sessionId =>
      $composableBuilder(column: $table.sessionId, builder: (column) => column);

  GeneratedColumn<String> get role =>
      $composableBuilder(column: $table.role, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<String> get reasoning =>
      $composableBuilder(column: $table.reasoning, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get runId =>
      $composableBuilder(column: $table.runId, builder: (column) => column);

  GeneratedColumn<int> get seq =>
      $composableBuilder(column: $table.seq, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get attachments => $composableBuilder(
    column: $table.attachments,
    builder: (column) => column,
  );

  GeneratedColumn<String> get toolEvents => $composableBuilder(
    column: $table.toolEvents,
    builder: (column) => column,
  );

  GeneratedColumn<String> get segments =>
      $composableBuilder(column: $table.segments, builder: (column) => column);

  GeneratedColumn<String> get error =>
      $composableBuilder(column: $table.error, builder: (column) => column);

  GeneratedColumn<String> get usage =>
      $composableBuilder(column: $table.usage, builder: (column) => column);

  GeneratedColumn<int> get serverId =>
      $composableBuilder(column: $table.serverId, builder: (column) => column);
}

class $$MessagesTableTableManager
    extends
        RootTableManager<
          _$HermesDatabase,
          $MessagesTable,
          Message,
          $$MessagesTableFilterComposer,
          $$MessagesTableOrderingComposer,
          $$MessagesTableAnnotationComposer,
          $$MessagesTableCreateCompanionBuilder,
          $$MessagesTableUpdateCompanionBuilder,
          (Message, BaseReferences<_$HermesDatabase, $MessagesTable, Message>),
          Message,
          PrefetchHooks Function()
        > {
  $$MessagesTableTableManager(_$HermesDatabase db, $MessagesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MessagesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MessagesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MessagesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> sessionId = const Value.absent(),
                Value<String> role = const Value.absent(),
                Value<String> content = const Value.absent(),
                Value<String> reasoning = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> runId = const Value.absent(),
                Value<int> seq = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<String> attachments = const Value.absent(),
                Value<String> toolEvents = const Value.absent(),
                Value<String> segments = const Value.absent(),
                Value<String?> error = const Value.absent(),
                Value<String?> usage = const Value.absent(),
                Value<int?> serverId = const Value.absent(),
              }) => MessagesCompanion(
                id: id,
                sessionId: sessionId,
                role: role,
                content: content,
                reasoning: reasoning,
                status: status,
                runId: runId,
                seq: seq,
                createdAt: createdAt,
                updatedAt: updatedAt,
                attachments: attachments,
                toolEvents: toolEvents,
                segments: segments,
                error: error,
                usage: usage,
                serverId: serverId,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String sessionId,
                required String role,
                Value<String> content = const Value.absent(),
                Value<String> reasoning = const Value.absent(),
                required String status,
                Value<String?> runId = const Value.absent(),
                Value<int> seq = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<String> attachments = const Value.absent(),
                Value<String> toolEvents = const Value.absent(),
                Value<String> segments = const Value.absent(),
                Value<String?> error = const Value.absent(),
                Value<String?> usage = const Value.absent(),
                Value<int?> serverId = const Value.absent(),
              }) => MessagesCompanion.insert(
                id: id,
                sessionId: sessionId,
                role: role,
                content: content,
                reasoning: reasoning,
                status: status,
                runId: runId,
                seq: seq,
                createdAt: createdAt,
                updatedAt: updatedAt,
                attachments: attachments,
                toolEvents: toolEvents,
                segments: segments,
                error: error,
                usage: usage,
                serverId: serverId,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$MessagesTable, Message>(table),
                  BaseReferences<_$HermesDatabase, $MessagesTable, Message>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MessagesTableProcessedTableManager =
    ProcessedTableManager<
      _$HermesDatabase,
      $MessagesTable,
      Message,
      $$MessagesTableFilterComposer,
      $$MessagesTableOrderingComposer,
      $$MessagesTableAnnotationComposer,
      $$MessagesTableCreateCompanionBuilder,
      $$MessagesTableUpdateCompanionBuilder,
      (Message, BaseReferences<_$HermesDatabase, $MessagesTable, Message>),
      Message,
      PrefetchHooks Function()
    >;
typedef $$RunsTableCreateCompanionBuilder = RunsCompanion Function({
  required String runId,
  required String sessionId,
  Value<int?> userMessageId,
  Value<int?> assistantMessageId,
  required String status,
  Value<String?> output,
  Value<String?> error,
  Value<String?> lastEvent,
  Value<int> createdAt,
  Value<int> updatedAt,
  Value<bool> notified,
  Value<String?> usage,
  Value<int> rowid,
});
typedef $$RunsTableUpdateCompanionBuilder = RunsCompanion Function({
  Value<String> runId,
  Value<String> sessionId,
  Value<int?> userMessageId,
  Value<int?> assistantMessageId,
  Value<String> status,
  Value<String?> output,
  Value<String?> error,
  Value<String?> lastEvent,
  Value<int> createdAt,
  Value<int> updatedAt,
  Value<bool> notified,
  Value<String?> usage,
  Value<int> rowid,
});

class $$RunsTableFilterComposer extends Composer<_$HermesDatabase, $RunsTable> {
  $$RunsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get runId => $composableBuilder(
    column: $table.runId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sessionId => $composableBuilder(
    column: $table.sessionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get userMessageId => $composableBuilder(
    column: $table.userMessageId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get assistantMessageId => $composableBuilder(
    column: $table.assistantMessageId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get output => $composableBuilder(
    column: $table.output,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get error => $composableBuilder(
    column: $table.error,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastEvent => $composableBuilder(
    column: $table.lastEvent,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get notified => $composableBuilder(
    column: $table.notified,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get usage => $composableBuilder(
    column: $table.usage,
    builder: (column) => ColumnFilters(column),
  );
}

class $$RunsTableOrderingComposer
    extends Composer<_$HermesDatabase, $RunsTable> {
  $$RunsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get runId => $composableBuilder(
    column: $table.runId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sessionId => $composableBuilder(
    column: $table.sessionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get userMessageId => $composableBuilder(
    column: $table.userMessageId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get assistantMessageId => $composableBuilder(
    column: $table.assistantMessageId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get output => $composableBuilder(
    column: $table.output,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get error => $composableBuilder(
    column: $table.error,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastEvent => $composableBuilder(
    column: $table.lastEvent,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get notified => $composableBuilder(
    column: $table.notified,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get usage => $composableBuilder(
    column: $table.usage,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RunsTableAnnotationComposer
    extends Composer<_$HermesDatabase, $RunsTable> {
  $$RunsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get runId =>
      $composableBuilder(column: $table.runId, builder: (column) => column);

  GeneratedColumn<String> get sessionId =>
      $composableBuilder(column: $table.sessionId, builder: (column) => column);

  GeneratedColumn<int> get userMessageId => $composableBuilder(
    column: $table.userMessageId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get assistantMessageId => $composableBuilder(
    column: $table.assistantMessageId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get output =>
      $composableBuilder(column: $table.output, builder: (column) => column);

  GeneratedColumn<String> get error =>
      $composableBuilder(column: $table.error, builder: (column) => column);

  GeneratedColumn<String> get lastEvent =>
      $composableBuilder(column: $table.lastEvent, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<bool> get notified =>
      $composableBuilder(column: $table.notified, builder: (column) => column);

  GeneratedColumn<String> get usage =>
      $composableBuilder(column: $table.usage, builder: (column) => column);
}

class $$RunsTableTableManager
    extends
        RootTableManager<
          _$HermesDatabase,
          $RunsTable,
          Run,
          $$RunsTableFilterComposer,
          $$RunsTableOrderingComposer,
          $$RunsTableAnnotationComposer,
          $$RunsTableCreateCompanionBuilder,
          $$RunsTableUpdateCompanionBuilder,
          (Run, BaseReferences<_$HermesDatabase, $RunsTable, Run>),
          Run,
          PrefetchHooks Function()
        > {
  $$RunsTableTableManager(_$HermesDatabase db, $RunsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RunsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RunsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RunsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> runId = const Value.absent(),
                Value<String> sessionId = const Value.absent(),
                Value<int?> userMessageId = const Value.absent(),
                Value<int?> assistantMessageId = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> output = const Value.absent(),
                Value<String?> error = const Value.absent(),
                Value<String?> lastEvent = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<bool> notified = const Value.absent(),
                Value<String?> usage = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RunsCompanion(
                runId: runId,
                sessionId: sessionId,
                userMessageId: userMessageId,
                assistantMessageId: assistantMessageId,
                status: status,
                output: output,
                error: error,
                lastEvent: lastEvent,
                createdAt: createdAt,
                updatedAt: updatedAt,
                notified: notified,
                usage: usage,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String runId,
                required String sessionId,
                Value<int?> userMessageId = const Value.absent(),
                Value<int?> assistantMessageId = const Value.absent(),
                required String status,
                Value<String?> output = const Value.absent(),
                Value<String?> error = const Value.absent(),
                Value<String?> lastEvent = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<bool> notified = const Value.absent(),
                Value<String?> usage = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RunsCompanion.insert(
                runId: runId,
                sessionId: sessionId,
                userMessageId: userMessageId,
                assistantMessageId: assistantMessageId,
                status: status,
                output: output,
                error: error,
                lastEvent: lastEvent,
                createdAt: createdAt,
                updatedAt: updatedAt,
                notified: notified,
                usage: usage,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$RunsTable, Run>(table),
                  BaseReferences<_$HermesDatabase, $RunsTable, Run>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$RunsTableProcessedTableManager =
    ProcessedTableManager<
      _$HermesDatabase,
      $RunsTable,
      Run,
      $$RunsTableFilterComposer,
      $$RunsTableOrderingComposer,
      $$RunsTableAnnotationComposer,
      $$RunsTableCreateCompanionBuilder,
      $$RunsTableUpdateCompanionBuilder,
      (Run, BaseReferences<_$HermesDatabase, $RunsTable, Run>),
      Run,
      PrefetchHooks Function()
    >;

class $HermesDatabaseManager {
  final _$HermesDatabase _db;
  $HermesDatabaseManager(this._db);
  $$SessionsTableTableManager get sessions =>
      $$SessionsTableTableManager(_db, _db.sessions);
  $$MessagesTableTableManager get messages =>
      $$MessagesTableTableManager(_db, _db.messages);
  $$RunsTableTableManager get runs => $$RunsTableTableManager(_db, _db.runs);
}
