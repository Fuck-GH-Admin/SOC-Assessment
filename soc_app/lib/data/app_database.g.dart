// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $HistoryRecordsTable extends HistoryRecords
    with TableInfo<$HistoryRecordsTable, HistoryRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $HistoryRecordsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _paramsMeta = const VerificationMeta('params');
  @override
  late final GeneratedColumn<String> params = GeneratedColumn<String>(
    'params',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _resultMeta = const VerificationMeta('result');
  @override
  late final GeneratedColumn<String> result = GeneratedColumn<String>(
    'result',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _resilienceMeta = const VerificationMeta(
    'resilience',
  );
  @override
  late final GeneratedColumn<String> resilience = GeneratedColumn<String>(
    'resilience',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _labelMeta = const VerificationMeta('label');
  @override
  late final GeneratedColumn<String> label = GeneratedColumn<String>(
    'label',
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
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    params,
    result,
    resilience,
    label,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'history_records';
  @override
  VerificationContext validateIntegrity(
    Insertable<HistoryRecord> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('params')) {
      context.handle(
        _paramsMeta,
        params.isAcceptableOrUnknown(data['params']!, _paramsMeta),
      );
    } else if (isInserting) {
      context.missing(_paramsMeta);
    }
    if (data.containsKey('result')) {
      context.handle(
        _resultMeta,
        result.isAcceptableOrUnknown(data['result']!, _resultMeta),
      );
    } else if (isInserting) {
      context.missing(_resultMeta);
    }
    if (data.containsKey('resilience')) {
      context.handle(
        _resilienceMeta,
        resilience.isAcceptableOrUnknown(data['resilience']!, _resilienceMeta),
      );
    }
    if (data.containsKey('label')) {
      context.handle(
        _labelMeta,
        label.isAcceptableOrUnknown(data['label']!, _labelMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  HistoryRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return HistoryRecord(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      params: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}params'],
      )!,
      result: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}result'],
      )!,
      resilience: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}resilience'],
      ),
      label: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}label'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $HistoryRecordsTable createAlias(String alias) {
    return $HistoryRecordsTable(attachedDatabase, alias);
  }
}

class HistoryRecord extends DataClass implements Insertable<HistoryRecord> {
  final int id;
  final String params;
  final String result;
  final String? resilience;
  final String? label;
  final int createdAt;
  const HistoryRecord({
    required this.id,
    required this.params,
    required this.result,
    this.resilience,
    this.label,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['params'] = Variable<String>(params);
    map['result'] = Variable<String>(result);
    if (!nullToAbsent || resilience != null) {
      map['resilience'] = Variable<String>(resilience);
    }
    if (!nullToAbsent || label != null) {
      map['label'] = Variable<String>(label);
    }
    map['created_at'] = Variable<int>(createdAt);
    return map;
  }

  HistoryRecordsCompanion toCompanion(bool nullToAbsent) {
    return HistoryRecordsCompanion(
      id: Value(id),
      params: Value(params),
      result: Value(result),
      resilience: resilience == null && nullToAbsent
          ? const Value.absent()
          : Value(resilience),
      label: label == null && nullToAbsent
          ? const Value.absent()
          : Value(label),
      createdAt: Value(createdAt),
    );
  }

  factory HistoryRecord.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return HistoryRecord(
      id: serializer.fromJson<int>(json['id']),
      params: serializer.fromJson<String>(json['params']),
      result: serializer.fromJson<String>(json['result']),
      resilience: serializer.fromJson<String?>(json['resilience']),
      label: serializer.fromJson<String?>(json['label']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'params': serializer.toJson<String>(params),
      'result': serializer.toJson<String>(result),
      'resilience': serializer.toJson<String?>(resilience),
      'label': serializer.toJson<String?>(label),
      'createdAt': serializer.toJson<int>(createdAt),
    };
  }

  HistoryRecord copyWith({
    int? id,
    String? params,
    String? result,
    Value<String?> resilience = const Value.absent(),
    Value<String?> label = const Value.absent(),
    int? createdAt,
  }) => HistoryRecord(
    id: id ?? this.id,
    params: params ?? this.params,
    result: result ?? this.result,
    resilience: resilience.present ? resilience.value : this.resilience,
    label: label.present ? label.value : this.label,
    createdAt: createdAt ?? this.createdAt,
  );
  HistoryRecord copyWithCompanion(HistoryRecordsCompanion data) {
    return HistoryRecord(
      id: data.id.present ? data.id.value : this.id,
      params: data.params.present ? data.params.value : this.params,
      result: data.result.present ? data.result.value : this.result,
      resilience: data.resilience.present
          ? data.resilience.value
          : this.resilience,
      label: data.label.present ? data.label.value : this.label,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('HistoryRecord(')
          ..write('id: $id, ')
          ..write('params: $params, ')
          ..write('result: $result, ')
          ..write('resilience: $resilience, ')
          ..write('label: $label, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, params, result, resilience, label, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is HistoryRecord &&
          other.id == this.id &&
          other.params == this.params &&
          other.result == this.result &&
          other.resilience == this.resilience &&
          other.label == this.label &&
          other.createdAt == this.createdAt);
}

class HistoryRecordsCompanion extends UpdateCompanion<HistoryRecord> {
  final Value<int> id;
  final Value<String> params;
  final Value<String> result;
  final Value<String?> resilience;
  final Value<String?> label;
  final Value<int> createdAt;
  const HistoryRecordsCompanion({
    this.id = const Value.absent(),
    this.params = const Value.absent(),
    this.result = const Value.absent(),
    this.resilience = const Value.absent(),
    this.label = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  HistoryRecordsCompanion.insert({
    this.id = const Value.absent(),
    required String params,
    required String result,
    this.resilience = const Value.absent(),
    this.label = const Value.absent(),
    required int createdAt,
  }) : params = Value(params),
       result = Value(result),
       createdAt = Value(createdAt);
  static Insertable<HistoryRecord> custom({
    Expression<int>? id,
    Expression<String>? params,
    Expression<String>? result,
    Expression<String>? resilience,
    Expression<String>? label,
    Expression<int>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (params != null) 'params': params,
      if (result != null) 'result': result,
      if (resilience != null) 'resilience': resilience,
      if (label != null) 'label': label,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  HistoryRecordsCompanion copyWith({
    Value<int>? id,
    Value<String>? params,
    Value<String>? result,
    Value<String?>? resilience,
    Value<String?>? label,
    Value<int>? createdAt,
  }) {
    return HistoryRecordsCompanion(
      id: id ?? this.id,
      params: params ?? this.params,
      result: result ?? this.result,
      resilience: resilience ?? this.resilience,
      label: label ?? this.label,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (params.present) {
      map['params'] = Variable<String>(params.value);
    }
    if (result.present) {
      map['result'] = Variable<String>(result.value);
    }
    if (resilience.present) {
      map['resilience'] = Variable<String>(resilience.value);
    }
    if (label.present) {
      map['label'] = Variable<String>(label.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('HistoryRecordsCompanion(')
          ..write('id: $id, ')
          ..write('params: $params, ')
          ..write('result: $result, ')
          ..write('resilience: $resilience, ')
          ..write('label: $label, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $DraftsTable extends Drafts with TableInfo<$DraftsTable, Draft> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DraftsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _paramsMeta = const VerificationMeta('params');
  @override
  late final GeneratedColumn<String> params = GeneratedColumn<String>(
    'params',
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
  @override
  List<GeneratedColumn> get $columns => [id, params, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'drafts';
  @override
  VerificationContext validateIntegrity(
    Insertable<Draft> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('params')) {
      context.handle(
        _paramsMeta,
        params.isAcceptableOrUnknown(data['params']!, _paramsMeta),
      );
    } else if (isInserting) {
      context.missing(_paramsMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Draft map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Draft(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      params: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}params'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $DraftsTable createAlias(String alias) {
    return $DraftsTable(attachedDatabase, alias);
  }
}

class Draft extends DataClass implements Insertable<Draft> {
  final int id;
  final String params;
  final int createdAt;
  const Draft({
    required this.id,
    required this.params,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['params'] = Variable<String>(params);
    map['created_at'] = Variable<int>(createdAt);
    return map;
  }

  DraftsCompanion toCompanion(bool nullToAbsent) {
    return DraftsCompanion(
      id: Value(id),
      params: Value(params),
      createdAt: Value(createdAt),
    );
  }

  factory Draft.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Draft(
      id: serializer.fromJson<int>(json['id']),
      params: serializer.fromJson<String>(json['params']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'params': serializer.toJson<String>(params),
      'createdAt': serializer.toJson<int>(createdAt),
    };
  }

  Draft copyWith({int? id, String? params, int? createdAt}) => Draft(
    id: id ?? this.id,
    params: params ?? this.params,
    createdAt: createdAt ?? this.createdAt,
  );
  Draft copyWithCompanion(DraftsCompanion data) {
    return Draft(
      id: data.id.present ? data.id.value : this.id,
      params: data.params.present ? data.params.value : this.params,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Draft(')
          ..write('id: $id, ')
          ..write('params: $params, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, params, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Draft &&
          other.id == this.id &&
          other.params == this.params &&
          other.createdAt == this.createdAt);
}

class DraftsCompanion extends UpdateCompanion<Draft> {
  final Value<int> id;
  final Value<String> params;
  final Value<int> createdAt;
  const DraftsCompanion({
    this.id = const Value.absent(),
    this.params = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  DraftsCompanion.insert({
    this.id = const Value.absent(),
    required String params,
    required int createdAt,
  }) : params = Value(params),
       createdAt = Value(createdAt);
  static Insertable<Draft> custom({
    Expression<int>? id,
    Expression<String>? params,
    Expression<int>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (params != null) 'params': params,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  DraftsCompanion copyWith({
    Value<int>? id,
    Value<String>? params,
    Value<int>? createdAt,
  }) {
    return DraftsCompanion(
      id: id ?? this.id,
      params: params ?? this.params,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (params.present) {
      map['params'] = Variable<String>(params.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DraftsCompanion(')
          ..write('id: $id, ')
          ..write('params: $params, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $HistoryRecordsTable historyRecords = $HistoryRecordsTable(this);
  late final $DraftsTable drafts = $DraftsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [historyRecords, drafts];
}

typedef $$HistoryRecordsTableCreateCompanionBuilder =
    HistoryRecordsCompanion Function({
      Value<int> id,
      required String params,
      required String result,
      Value<String?> resilience,
      Value<String?> label,
      required int createdAt,
    });
typedef $$HistoryRecordsTableUpdateCompanionBuilder =
    HistoryRecordsCompanion Function({
      Value<int> id,
      Value<String> params,
      Value<String> result,
      Value<String?> resilience,
      Value<String?> label,
      Value<int> createdAt,
    });

class $$HistoryRecordsTableFilterComposer
    extends Composer<_$AppDatabase, $HistoryRecordsTable> {
  $$HistoryRecordsTableFilterComposer({
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

  ColumnFilters<String> get params => $composableBuilder(
    column: $table.params,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get result => $composableBuilder(
    column: $table.result,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get resilience => $composableBuilder(
    column: $table.resilience,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$HistoryRecordsTableOrderingComposer
    extends Composer<_$AppDatabase, $HistoryRecordsTable> {
  $$HistoryRecordsTableOrderingComposer({
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

  ColumnOrderings<String> get params => $composableBuilder(
    column: $table.params,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get result => $composableBuilder(
    column: $table.result,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get resilience => $composableBuilder(
    column: $table.resilience,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$HistoryRecordsTableAnnotationComposer
    extends Composer<_$AppDatabase, $HistoryRecordsTable> {
  $$HistoryRecordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get params =>
      $composableBuilder(column: $table.params, builder: (column) => column);

  GeneratedColumn<String> get result =>
      $composableBuilder(column: $table.result, builder: (column) => column);

  GeneratedColumn<String> get resilience => $composableBuilder(
    column: $table.resilience,
    builder: (column) => column,
  );

  GeneratedColumn<String> get label =>
      $composableBuilder(column: $table.label, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$HistoryRecordsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $HistoryRecordsTable,
          HistoryRecord,
          $$HistoryRecordsTableFilterComposer,
          $$HistoryRecordsTableOrderingComposer,
          $$HistoryRecordsTableAnnotationComposer,
          $$HistoryRecordsTableCreateCompanionBuilder,
          $$HistoryRecordsTableUpdateCompanionBuilder,
          (
            HistoryRecord,
            BaseReferences<_$AppDatabase, $HistoryRecordsTable, HistoryRecord>,
          ),
          HistoryRecord,
          PrefetchHooks Function()
        > {
  $$HistoryRecordsTableTableManager(
    _$AppDatabase db,
    $HistoryRecordsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$HistoryRecordsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$HistoryRecordsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$HistoryRecordsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> params = const Value.absent(),
                Value<String> result = const Value.absent(),
                Value<String?> resilience = const Value.absent(),
                Value<String?> label = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
              }) => HistoryRecordsCompanion(
                id: id,
                params: params,
                result: result,
                resilience: resilience,
                label: label,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String params,
                required String result,
                Value<String?> resilience = const Value.absent(),
                Value<String?> label = const Value.absent(),
                required int createdAt,
              }) => HistoryRecordsCompanion.insert(
                id: id,
                params: params,
                result: result,
                resilience: resilience,
                label: label,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$HistoryRecordsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $HistoryRecordsTable,
      HistoryRecord,
      $$HistoryRecordsTableFilterComposer,
      $$HistoryRecordsTableOrderingComposer,
      $$HistoryRecordsTableAnnotationComposer,
      $$HistoryRecordsTableCreateCompanionBuilder,
      $$HistoryRecordsTableUpdateCompanionBuilder,
      (
        HistoryRecord,
        BaseReferences<_$AppDatabase, $HistoryRecordsTable, HistoryRecord>,
      ),
      HistoryRecord,
      PrefetchHooks Function()
    >;
typedef $$DraftsTableCreateCompanionBuilder =
    DraftsCompanion Function({
      Value<int> id,
      required String params,
      required int createdAt,
    });
typedef $$DraftsTableUpdateCompanionBuilder =
    DraftsCompanion Function({
      Value<int> id,
      Value<String> params,
      Value<int> createdAt,
    });

class $$DraftsTableFilterComposer
    extends Composer<_$AppDatabase, $DraftsTable> {
  $$DraftsTableFilterComposer({
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

  ColumnFilters<String> get params => $composableBuilder(
    column: $table.params,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DraftsTableOrderingComposer
    extends Composer<_$AppDatabase, $DraftsTable> {
  $$DraftsTableOrderingComposer({
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

  ColumnOrderings<String> get params => $composableBuilder(
    column: $table.params,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DraftsTableAnnotationComposer
    extends Composer<_$AppDatabase, $DraftsTable> {
  $$DraftsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get params =>
      $composableBuilder(column: $table.params, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$DraftsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DraftsTable,
          Draft,
          $$DraftsTableFilterComposer,
          $$DraftsTableOrderingComposer,
          $$DraftsTableAnnotationComposer,
          $$DraftsTableCreateCompanionBuilder,
          $$DraftsTableUpdateCompanionBuilder,
          (Draft, BaseReferences<_$AppDatabase, $DraftsTable, Draft>),
          Draft,
          PrefetchHooks Function()
        > {
  $$DraftsTableTableManager(_$AppDatabase db, $DraftsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DraftsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DraftsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DraftsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> params = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
              }) =>
                  DraftsCompanion(id: id, params: params, createdAt: createdAt),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String params,
                required int createdAt,
              }) => DraftsCompanion.insert(
                id: id,
                params: params,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DraftsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DraftsTable,
      Draft,
      $$DraftsTableFilterComposer,
      $$DraftsTableOrderingComposer,
      $$DraftsTableAnnotationComposer,
      $$DraftsTableCreateCompanionBuilder,
      $$DraftsTableUpdateCompanionBuilder,
      (Draft, BaseReferences<_$AppDatabase, $DraftsTable, Draft>),
      Draft,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$HistoryRecordsTableTableManager get historyRecords =>
      $$HistoryRecordsTableTableManager(_db, _db.historyRecords);
  $$DraftsTableTableManager get drafts =>
      $$DraftsTableTableManager(_db, _db.drafts);
}
