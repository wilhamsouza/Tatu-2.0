import 'package:drift/drift.dart';

import 'schema/app_database_schema.dart';

enum LocalConflictAlgorithm { replace }

class LocalSqlDatabase extends GeneratedDatabase {
  LocalSqlDatabase(super.executor);

  @override
  Iterable<TableInfo> get allTables => const <TableInfo>[];

  @override
  int get schemaVersion => AppDatabaseSchema.version;
}

class LocalDatabaseExecutor {
  const LocalDatabaseExecutor(this._database, {required this.path});

  final LocalSqlDatabase _database;
  final String path;

  Future<void> execute(String sql, [List<Object?>? arguments]) {
    return _database.customStatement(sql, arguments);
  }

  Future<List<Map<String, Object?>>> rawQuery(
    String sql, [
    List<Object?>? arguments,
  ]) async {
    final rows = await _database
        .customSelect(sql, variables: _variables(arguments))
        .get();
    return rows.map((row) => Map<String, Object?>.from(row.data)).toList();
  }

  Future<List<Map<String, Object?>>> query(
    String table, {
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? orderBy,
    int? limit,
  }) {
    final selectedColumns = columns == null || columns.isEmpty
        ? '*'
        : columns.join(', ');
    final buffer = StringBuffer('SELECT $selectedColumns FROM $table');
    if (where != null && where.trim().isNotEmpty) {
      buffer.write(' WHERE $where');
    }
    if (orderBy != null && orderBy.trim().isNotEmpty) {
      buffer.write(' ORDER BY $orderBy');
    }
    if (limit != null) {
      buffer.write(' LIMIT $limit');
    }
    return rawQuery(buffer.toString(), whereArgs);
  }

  Future<int> insert(
    String table,
    Map<String, Object?> values, {
    LocalConflictAlgorithm? conflictAlgorithm,
  }) async {
    final columns = values.keys.toList(growable: false);
    final placeholders = List<String>.filled(columns.length, '?').join(', ');
    final conflict = switch (conflictAlgorithm) {
      LocalConflictAlgorithm.replace => 'OR REPLACE ',
      null => '',
    };

    await execute(
      'INSERT ${conflict}INTO $table (${columns.join(', ')}) '
      'VALUES ($placeholders)',
      columns.map((column) => values[column]).toList(growable: false),
    );
    return 0;
  }

  Future<int> update(
    String table,
    Map<String, Object?> values, {
    String? where,
    List<Object?>? whereArgs,
  }) async {
    final columns = values.keys.toList(growable: false);
    final assignments = columns.map((column) => '$column = ?').join(', ');
    final arguments = <Object?>[
      ...columns.map((column) => values[column]),
      ...?whereArgs,
    ];
    final buffer = StringBuffer('UPDATE $table SET $assignments');
    if (where != null && where.trim().isNotEmpty) {
      buffer.write(' WHERE $where');
    }

    await execute(buffer.toString(), arguments);
    return 0;
  }

  Future<int> delete(
    String table, {
    String? where,
    List<Object?>? whereArgs,
  }) async {
    final buffer = StringBuffer('DELETE FROM $table');
    if (where != null && where.trim().isNotEmpty) {
      buffer.write(' WHERE $where');
    }

    await execute(buffer.toString(), whereArgs);
    return 0;
  }

  Future<T> transaction<T>(
    Future<T> Function(LocalDatabaseExecutor txn) action,
  ) {
    return _database.transaction(() => action(this));
  }

  Future<void> close() {
    return _database.close();
  }
}

List<Variable<Object>> _variables(List<Object?>? arguments) {
  if (arguments == null || arguments.isEmpty) {
    return const <Variable<Object>>[];
  }
  return arguments.map((value) => Variable<Object>(value)).toList();
}
