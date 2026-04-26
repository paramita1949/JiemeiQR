// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $ProductsTable extends Products with TableInfo<$ProductsTable, Product> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProductsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _codeMeta = const VerificationMeta('code');
  @override
  late final GeneratedColumn<String> code = GeneratedColumn<String>(
      'code', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'));
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _boxesPerBoardMeta =
      const VerificationMeta('boxesPerBoard');
  @override
  late final GeneratedColumn<int> boxesPerBoard = GeneratedColumn<int>(
      'boxes_per_board', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _piecesPerBoxMeta =
      const VerificationMeta('piecesPerBox');
  @override
  late final GeneratedColumn<int> piecesPerBox = GeneratedColumn<int>(
      'pieces_per_box', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns =>
      [id, code, name, boxesPerBoard, piecesPerBox, createdAt, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'products';
  @override
  VerificationContext validateIntegrity(Insertable<Product> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('code')) {
      context.handle(
          _codeMeta, code.isAcceptableOrUnknown(data['code']!, _codeMeta));
    } else if (isInserting) {
      context.missing(_codeMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('boxes_per_board')) {
      context.handle(
          _boxesPerBoardMeta,
          boxesPerBoard.isAcceptableOrUnknown(
              data['boxes_per_board']!, _boxesPerBoardMeta));
    } else if (isInserting) {
      context.missing(_boxesPerBoardMeta);
    }
    if (data.containsKey('pieces_per_box')) {
      context.handle(
          _piecesPerBoxMeta,
          piecesPerBox.isAcceptableOrUnknown(
              data['pieces_per_box']!, _piecesPerBoxMeta));
    } else if (isInserting) {
      context.missing(_piecesPerBoxMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Product map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Product(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      code: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}code'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      boxesPerBoard: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}boxes_per_board'])!,
      piecesPerBox: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}pieces_per_box'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at']),
    );
  }

  @override
  $ProductsTable createAlias(String alias) {
    return $ProductsTable(attachedDatabase, alias);
  }
}

class Product extends DataClass implements Insertable<Product> {
  final int id;
  final String code;
  final String name;
  final int boxesPerBoard;
  final int piecesPerBox;
  final DateTime createdAt;
  final DateTime? updatedAt;
  const Product(
      {required this.id,
      required this.code,
      required this.name,
      required this.boxesPerBoard,
      required this.piecesPerBox,
      required this.createdAt,
      this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['code'] = Variable<String>(code);
    map['name'] = Variable<String>(name);
    map['boxes_per_board'] = Variable<int>(boxesPerBoard);
    map['pieces_per_box'] = Variable<int>(piecesPerBox);
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<DateTime>(updatedAt);
    }
    return map;
  }

  ProductsCompanion toCompanion(bool nullToAbsent) {
    return ProductsCompanion(
      id: Value(id),
      code: Value(code),
      name: Value(name),
      boxesPerBoard: Value(boxesPerBoard),
      piecesPerBox: Value(piecesPerBox),
      createdAt: Value(createdAt),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
    );
  }

  factory Product.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Product(
      id: serializer.fromJson<int>(json['id']),
      code: serializer.fromJson<String>(json['code']),
      name: serializer.fromJson<String>(json['name']),
      boxesPerBoard: serializer.fromJson<int>(json['boxesPerBoard']),
      piecesPerBox: serializer.fromJson<int>(json['piecesPerBox']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime?>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'code': serializer.toJson<String>(code),
      'name': serializer.toJson<String>(name),
      'boxesPerBoard': serializer.toJson<int>(boxesPerBoard),
      'piecesPerBox': serializer.toJson<int>(piecesPerBox),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime?>(updatedAt),
    };
  }

  Product copyWith(
          {int? id,
          String? code,
          String? name,
          int? boxesPerBoard,
          int? piecesPerBox,
          DateTime? createdAt,
          Value<DateTime?> updatedAt = const Value.absent()}) =>
      Product(
        id: id ?? this.id,
        code: code ?? this.code,
        name: name ?? this.name,
        boxesPerBoard: boxesPerBoard ?? this.boxesPerBoard,
        piecesPerBox: piecesPerBox ?? this.piecesPerBox,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
      );
  Product copyWithCompanion(ProductsCompanion data) {
    return Product(
      id: data.id.present ? data.id.value : this.id,
      code: data.code.present ? data.code.value : this.code,
      name: data.name.present ? data.name.value : this.name,
      boxesPerBoard: data.boxesPerBoard.present
          ? data.boxesPerBoard.value
          : this.boxesPerBoard,
      piecesPerBox: data.piecesPerBox.present
          ? data.piecesPerBox.value
          : this.piecesPerBox,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Product(')
          ..write('id: $id, ')
          ..write('code: $code, ')
          ..write('name: $name, ')
          ..write('boxesPerBoard: $boxesPerBoard, ')
          ..write('piecesPerBox: $piecesPerBox, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id, code, name, boxesPerBoard, piecesPerBox, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Product &&
          other.id == this.id &&
          other.code == this.code &&
          other.name == this.name &&
          other.boxesPerBoard == this.boxesPerBoard &&
          other.piecesPerBox == this.piecesPerBox &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class ProductsCompanion extends UpdateCompanion<Product> {
  final Value<int> id;
  final Value<String> code;
  final Value<String> name;
  final Value<int> boxesPerBoard;
  final Value<int> piecesPerBox;
  final Value<DateTime> createdAt;
  final Value<DateTime?> updatedAt;
  const ProductsCompanion({
    this.id = const Value.absent(),
    this.code = const Value.absent(),
    this.name = const Value.absent(),
    this.boxesPerBoard = const Value.absent(),
    this.piecesPerBox = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  ProductsCompanion.insert({
    this.id = const Value.absent(),
    required String code,
    required String name,
    required int boxesPerBoard,
    required int piecesPerBox,
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  })  : code = Value(code),
        name = Value(name),
        boxesPerBoard = Value(boxesPerBoard),
        piecesPerBox = Value(piecesPerBox);
  static Insertable<Product> custom({
    Expression<int>? id,
    Expression<String>? code,
    Expression<String>? name,
    Expression<int>? boxesPerBoard,
    Expression<int>? piecesPerBox,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (code != null) 'code': code,
      if (name != null) 'name': name,
      if (boxesPerBoard != null) 'boxes_per_board': boxesPerBoard,
      if (piecesPerBox != null) 'pieces_per_box': piecesPerBox,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  ProductsCompanion copyWith(
      {Value<int>? id,
      Value<String>? code,
      Value<String>? name,
      Value<int>? boxesPerBoard,
      Value<int>? piecesPerBox,
      Value<DateTime>? createdAt,
      Value<DateTime?>? updatedAt}) {
    return ProductsCompanion(
      id: id ?? this.id,
      code: code ?? this.code,
      name: name ?? this.name,
      boxesPerBoard: boxesPerBoard ?? this.boxesPerBoard,
      piecesPerBox: piecesPerBox ?? this.piecesPerBox,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (code.present) {
      map['code'] = Variable<String>(code.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (boxesPerBoard.present) {
      map['boxes_per_board'] = Variable<int>(boxesPerBoard.value);
    }
    if (piecesPerBox.present) {
      map['pieces_per_box'] = Variable<int>(piecesPerBox.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProductsCompanion(')
          ..write('id: $id, ')
          ..write('code: $code, ')
          ..write('name: $name, ')
          ..write('boxesPerBoard: $boxesPerBoard, ')
          ..write('piecesPerBox: $piecesPerBox, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $BatchesTable extends Batches with TableInfo<$BatchesTable, BatchRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BatchesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _productIdMeta =
      const VerificationMeta('productId');
  @override
  late final GeneratedColumn<int> productId = GeneratedColumn<int>(
      'product_id', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES products (id)'));
  static const VerificationMeta _actualBatchMeta =
      const VerificationMeta('actualBatch');
  @override
  late final GeneratedColumn<String> actualBatch = GeneratedColumn<String>(
      'actual_batch', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _dateBatchMeta =
      const VerificationMeta('dateBatch');
  @override
  late final GeneratedColumn<String> dateBatch = GeneratedColumn<String>(
      'date_batch', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _initialBoxesMeta =
      const VerificationMeta('initialBoxes');
  @override
  late final GeneratedColumn<int> initialBoxes = GeneratedColumn<int>(
      'initial_boxes', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _boxesPerBoardMeta =
      const VerificationMeta('boxesPerBoard');
  @override
  late final GeneratedColumn<int> boxesPerBoard = GeneratedColumn<int>(
      'boxes_per_board', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _stackingPatternMeta =
      const VerificationMeta('stackingPattern');
  @override
  late final GeneratedColumn<String> stackingPattern = GeneratedColumn<String>(
      'stacking_pattern', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _locationMeta =
      const VerificationMeta('location');
  @override
  late final GeneratedColumn<String> location = GeneratedColumn<String>(
      'location', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _hasShippedMeta =
      const VerificationMeta('hasShipped');
  @override
  late final GeneratedColumn<bool> hasShipped = GeneratedColumn<bool>(
      'has_shipped', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("has_shipped" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _tsRequiredMeta =
      const VerificationMeta('tsRequired');
  @override
  late final GeneratedColumn<bool> tsRequired = GeneratedColumn<bool>(
      'ts_required', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("ts_required" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _remarkMeta = const VerificationMeta('remark');
  @override
  late final GeneratedColumn<String> remark = GeneratedColumn<String>(
      'remark', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        productId,
        actualBatch,
        dateBatch,
        initialBoxes,
        boxesPerBoard,
        stackingPattern,
        location,
        hasShipped,
        tsRequired,
        remark,
        createdAt,
        updatedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'batches';
  @override
  VerificationContext validateIntegrity(Insertable<BatchRecord> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('product_id')) {
      context.handle(_productIdMeta,
          productId.isAcceptableOrUnknown(data['product_id']!, _productIdMeta));
    } else if (isInserting) {
      context.missing(_productIdMeta);
    }
    if (data.containsKey('actual_batch')) {
      context.handle(
          _actualBatchMeta,
          actualBatch.isAcceptableOrUnknown(
              data['actual_batch']!, _actualBatchMeta));
    } else if (isInserting) {
      context.missing(_actualBatchMeta);
    }
    if (data.containsKey('date_batch')) {
      context.handle(_dateBatchMeta,
          dateBatch.isAcceptableOrUnknown(data['date_batch']!, _dateBatchMeta));
    } else if (isInserting) {
      context.missing(_dateBatchMeta);
    }
    if (data.containsKey('initial_boxes')) {
      context.handle(
          _initialBoxesMeta,
          initialBoxes.isAcceptableOrUnknown(
              data['initial_boxes']!, _initialBoxesMeta));
    } else if (isInserting) {
      context.missing(_initialBoxesMeta);
    }
    if (data.containsKey('boxes_per_board')) {
      context.handle(
          _boxesPerBoardMeta,
          boxesPerBoard.isAcceptableOrUnknown(
              data['boxes_per_board']!, _boxesPerBoardMeta));
    } else if (isInserting) {
      context.missing(_boxesPerBoardMeta);
    }
    if (data.containsKey('stacking_pattern')) {
      context.handle(
          _stackingPatternMeta,
          stackingPattern.isAcceptableOrUnknown(
              data['stacking_pattern']!, _stackingPatternMeta));
    }
    if (data.containsKey('location')) {
      context.handle(_locationMeta,
          location.isAcceptableOrUnknown(data['location']!, _locationMeta));
    }
    if (data.containsKey('has_shipped')) {
      context.handle(
          _hasShippedMeta,
          hasShipped.isAcceptableOrUnknown(
              data['has_shipped']!, _hasShippedMeta));
    }
    if (data.containsKey('ts_required')) {
      context.handle(
          _tsRequiredMeta,
          tsRequired.isAcceptableOrUnknown(
              data['ts_required']!, _tsRequiredMeta));
    }
    if (data.containsKey('remark')) {
      context.handle(_remarkMeta,
          remark.isAcceptableOrUnknown(data['remark']!, _remarkMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  BatchRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BatchRecord(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      productId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}product_id'])!,
      actualBatch: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}actual_batch'])!,
      dateBatch: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}date_batch'])!,
      initialBoxes: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}initial_boxes'])!,
      boxesPerBoard: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}boxes_per_board'])!,
      stackingPattern: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}stacking_pattern']),
      location: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}location']),
      hasShipped: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}has_shipped'])!,
      tsRequired: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}ts_required'])!,
      remark: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}remark']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at']),
    );
  }

  @override
  $BatchesTable createAlias(String alias) {
    return $BatchesTable(attachedDatabase, alias);
  }
}

class BatchRecord extends DataClass implements Insertable<BatchRecord> {
  final int id;
  final int productId;
  final String actualBatch;
  final String dateBatch;
  final int initialBoxes;
  final int boxesPerBoard;
  final String? stackingPattern;
  final String? location;
  final bool hasShipped;
  final bool tsRequired;
  final String? remark;
  final DateTime createdAt;
  final DateTime? updatedAt;
  const BatchRecord(
      {required this.id,
      required this.productId,
      required this.actualBatch,
      required this.dateBatch,
      required this.initialBoxes,
      required this.boxesPerBoard,
      this.stackingPattern,
      this.location,
      required this.hasShipped,
      required this.tsRequired,
      this.remark,
      required this.createdAt,
      this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['product_id'] = Variable<int>(productId);
    map['actual_batch'] = Variable<String>(actualBatch);
    map['date_batch'] = Variable<String>(dateBatch);
    map['initial_boxes'] = Variable<int>(initialBoxes);
    map['boxes_per_board'] = Variable<int>(boxesPerBoard);
    if (!nullToAbsent || stackingPattern != null) {
      map['stacking_pattern'] = Variable<String>(stackingPattern);
    }
    if (!nullToAbsent || location != null) {
      map['location'] = Variable<String>(location);
    }
    map['has_shipped'] = Variable<bool>(hasShipped);
    map['ts_required'] = Variable<bool>(tsRequired);
    if (!nullToAbsent || remark != null) {
      map['remark'] = Variable<String>(remark);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<DateTime>(updatedAt);
    }
    return map;
  }

  BatchesCompanion toCompanion(bool nullToAbsent) {
    return BatchesCompanion(
      id: Value(id),
      productId: Value(productId),
      actualBatch: Value(actualBatch),
      dateBatch: Value(dateBatch),
      initialBoxes: Value(initialBoxes),
      boxesPerBoard: Value(boxesPerBoard),
      stackingPattern: stackingPattern == null && nullToAbsent
          ? const Value.absent()
          : Value(stackingPattern),
      location: location == null && nullToAbsent
          ? const Value.absent()
          : Value(location),
      hasShipped: Value(hasShipped),
      tsRequired: Value(tsRequired),
      remark:
          remark == null && nullToAbsent ? const Value.absent() : Value(remark),
      createdAt: Value(createdAt),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
    );
  }

  factory BatchRecord.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BatchRecord(
      id: serializer.fromJson<int>(json['id']),
      productId: serializer.fromJson<int>(json['productId']),
      actualBatch: serializer.fromJson<String>(json['actualBatch']),
      dateBatch: serializer.fromJson<String>(json['dateBatch']),
      initialBoxes: serializer.fromJson<int>(json['initialBoxes']),
      boxesPerBoard: serializer.fromJson<int>(json['boxesPerBoard']),
      stackingPattern: serializer.fromJson<String?>(json['stackingPattern']),
      location: serializer.fromJson<String?>(json['location']),
      hasShipped: serializer.fromJson<bool>(json['hasShipped']),
      tsRequired: serializer.fromJson<bool>(json['tsRequired']),
      remark: serializer.fromJson<String?>(json['remark']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime?>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'productId': serializer.toJson<int>(productId),
      'actualBatch': serializer.toJson<String>(actualBatch),
      'dateBatch': serializer.toJson<String>(dateBatch),
      'initialBoxes': serializer.toJson<int>(initialBoxes),
      'boxesPerBoard': serializer.toJson<int>(boxesPerBoard),
      'stackingPattern': serializer.toJson<String?>(stackingPattern),
      'location': serializer.toJson<String?>(location),
      'hasShipped': serializer.toJson<bool>(hasShipped),
      'tsRequired': serializer.toJson<bool>(tsRequired),
      'remark': serializer.toJson<String?>(remark),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime?>(updatedAt),
    };
  }

  BatchRecord copyWith(
          {int? id,
          int? productId,
          String? actualBatch,
          String? dateBatch,
          int? initialBoxes,
          int? boxesPerBoard,
          Value<String?> stackingPattern = const Value.absent(),
          Value<String?> location = const Value.absent(),
          bool? hasShipped,
          bool? tsRequired,
          Value<String?> remark = const Value.absent(),
          DateTime? createdAt,
          Value<DateTime?> updatedAt = const Value.absent()}) =>
      BatchRecord(
        id: id ?? this.id,
        productId: productId ?? this.productId,
        actualBatch: actualBatch ?? this.actualBatch,
        dateBatch: dateBatch ?? this.dateBatch,
        initialBoxes: initialBoxes ?? this.initialBoxes,
        boxesPerBoard: boxesPerBoard ?? this.boxesPerBoard,
        stackingPattern: stackingPattern.present
            ? stackingPattern.value
            : this.stackingPattern,
        location: location.present ? location.value : this.location,
        hasShipped: hasShipped ?? this.hasShipped,
        tsRequired: tsRequired ?? this.tsRequired,
        remark: remark.present ? remark.value : this.remark,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
      );
  BatchRecord copyWithCompanion(BatchesCompanion data) {
    return BatchRecord(
      id: data.id.present ? data.id.value : this.id,
      productId: data.productId.present ? data.productId.value : this.productId,
      actualBatch:
          data.actualBatch.present ? data.actualBatch.value : this.actualBatch,
      dateBatch: data.dateBatch.present ? data.dateBatch.value : this.dateBatch,
      initialBoxes: data.initialBoxes.present
          ? data.initialBoxes.value
          : this.initialBoxes,
      boxesPerBoard: data.boxesPerBoard.present
          ? data.boxesPerBoard.value
          : this.boxesPerBoard,
      stackingPattern: data.stackingPattern.present
          ? data.stackingPattern.value
          : this.stackingPattern,
      location: data.location.present ? data.location.value : this.location,
      hasShipped:
          data.hasShipped.present ? data.hasShipped.value : this.hasShipped,
      tsRequired:
          data.tsRequired.present ? data.tsRequired.value : this.tsRequired,
      remark: data.remark.present ? data.remark.value : this.remark,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BatchRecord(')
          ..write('id: $id, ')
          ..write('productId: $productId, ')
          ..write('actualBatch: $actualBatch, ')
          ..write('dateBatch: $dateBatch, ')
          ..write('initialBoxes: $initialBoxes, ')
          ..write('boxesPerBoard: $boxesPerBoard, ')
          ..write('stackingPattern: $stackingPattern, ')
          ..write('location: $location, ')
          ..write('hasShipped: $hasShipped, ')
          ..write('tsRequired: $tsRequired, ')
          ..write('remark: $remark, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      productId,
      actualBatch,
      dateBatch,
      initialBoxes,
      boxesPerBoard,
      stackingPattern,
      location,
      hasShipped,
      tsRequired,
      remark,
      createdAt,
      updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BatchRecord &&
          other.id == this.id &&
          other.productId == this.productId &&
          other.actualBatch == this.actualBatch &&
          other.dateBatch == this.dateBatch &&
          other.initialBoxes == this.initialBoxes &&
          other.boxesPerBoard == this.boxesPerBoard &&
          other.stackingPattern == this.stackingPattern &&
          other.location == this.location &&
          other.hasShipped == this.hasShipped &&
          other.tsRequired == this.tsRequired &&
          other.remark == this.remark &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class BatchesCompanion extends UpdateCompanion<BatchRecord> {
  final Value<int> id;
  final Value<int> productId;
  final Value<String> actualBatch;
  final Value<String> dateBatch;
  final Value<int> initialBoxes;
  final Value<int> boxesPerBoard;
  final Value<String?> stackingPattern;
  final Value<String?> location;
  final Value<bool> hasShipped;
  final Value<bool> tsRequired;
  final Value<String?> remark;
  final Value<DateTime> createdAt;
  final Value<DateTime?> updatedAt;
  const BatchesCompanion({
    this.id = const Value.absent(),
    this.productId = const Value.absent(),
    this.actualBatch = const Value.absent(),
    this.dateBatch = const Value.absent(),
    this.initialBoxes = const Value.absent(),
    this.boxesPerBoard = const Value.absent(),
    this.stackingPattern = const Value.absent(),
    this.location = const Value.absent(),
    this.hasShipped = const Value.absent(),
    this.tsRequired = const Value.absent(),
    this.remark = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  BatchesCompanion.insert({
    this.id = const Value.absent(),
    required int productId,
    required String actualBatch,
    required String dateBatch,
    required int initialBoxes,
    required int boxesPerBoard,
    this.stackingPattern = const Value.absent(),
    this.location = const Value.absent(),
    this.hasShipped = const Value.absent(),
    this.tsRequired = const Value.absent(),
    this.remark = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  })  : productId = Value(productId),
        actualBatch = Value(actualBatch),
        dateBatch = Value(dateBatch),
        initialBoxes = Value(initialBoxes),
        boxesPerBoard = Value(boxesPerBoard);
  static Insertable<BatchRecord> custom({
    Expression<int>? id,
    Expression<int>? productId,
    Expression<String>? actualBatch,
    Expression<String>? dateBatch,
    Expression<int>? initialBoxes,
    Expression<int>? boxesPerBoard,
    Expression<String>? stackingPattern,
    Expression<String>? location,
    Expression<bool>? hasShipped,
    Expression<bool>? tsRequired,
    Expression<String>? remark,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (productId != null) 'product_id': productId,
      if (actualBatch != null) 'actual_batch': actualBatch,
      if (dateBatch != null) 'date_batch': dateBatch,
      if (initialBoxes != null) 'initial_boxes': initialBoxes,
      if (boxesPerBoard != null) 'boxes_per_board': boxesPerBoard,
      if (stackingPattern != null) 'stacking_pattern': stackingPattern,
      if (location != null) 'location': location,
      if (hasShipped != null) 'has_shipped': hasShipped,
      if (tsRequired != null) 'ts_required': tsRequired,
      if (remark != null) 'remark': remark,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  BatchesCompanion copyWith(
      {Value<int>? id,
      Value<int>? productId,
      Value<String>? actualBatch,
      Value<String>? dateBatch,
      Value<int>? initialBoxes,
      Value<int>? boxesPerBoard,
      Value<String?>? stackingPattern,
      Value<String?>? location,
      Value<bool>? hasShipped,
      Value<bool>? tsRequired,
      Value<String?>? remark,
      Value<DateTime>? createdAt,
      Value<DateTime?>? updatedAt}) {
    return BatchesCompanion(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      actualBatch: actualBatch ?? this.actualBatch,
      dateBatch: dateBatch ?? this.dateBatch,
      initialBoxes: initialBoxes ?? this.initialBoxes,
      boxesPerBoard: boxesPerBoard ?? this.boxesPerBoard,
      stackingPattern: stackingPattern ?? this.stackingPattern,
      location: location ?? this.location,
      hasShipped: hasShipped ?? this.hasShipped,
      tsRequired: tsRequired ?? this.tsRequired,
      remark: remark ?? this.remark,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (productId.present) {
      map['product_id'] = Variable<int>(productId.value);
    }
    if (actualBatch.present) {
      map['actual_batch'] = Variable<String>(actualBatch.value);
    }
    if (dateBatch.present) {
      map['date_batch'] = Variable<String>(dateBatch.value);
    }
    if (initialBoxes.present) {
      map['initial_boxes'] = Variable<int>(initialBoxes.value);
    }
    if (boxesPerBoard.present) {
      map['boxes_per_board'] = Variable<int>(boxesPerBoard.value);
    }
    if (stackingPattern.present) {
      map['stacking_pattern'] = Variable<String>(stackingPattern.value);
    }
    if (location.present) {
      map['location'] = Variable<String>(location.value);
    }
    if (hasShipped.present) {
      map['has_shipped'] = Variable<bool>(hasShipped.value);
    }
    if (tsRequired.present) {
      map['ts_required'] = Variable<bool>(tsRequired.value);
    }
    if (remark.present) {
      map['remark'] = Variable<String>(remark.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BatchesCompanion(')
          ..write('id: $id, ')
          ..write('productId: $productId, ')
          ..write('actualBatch: $actualBatch, ')
          ..write('dateBatch: $dateBatch, ')
          ..write('initialBoxes: $initialBoxes, ')
          ..write('boxesPerBoard: $boxesPerBoard, ')
          ..write('stackingPattern: $stackingPattern, ')
          ..write('location: $location, ')
          ..write('hasShipped: $hasShipped, ')
          ..write('tsRequired: $tsRequired, ')
          ..write('remark: $remark, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $OrdersTable extends Orders with TableInfo<$OrdersTable, Order> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OrdersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _waybillNoMeta =
      const VerificationMeta('waybillNo');
  @override
  late final GeneratedColumn<String> waybillNo = GeneratedColumn<String>(
      'waybill_no', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _merchantNameMeta =
      const VerificationMeta('merchantName');
  @override
  late final GeneratedColumn<String> merchantName = GeneratedColumn<String>(
      'merchant_name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _orderDateMeta =
      const VerificationMeta('orderDate');
  @override
  late final GeneratedColumn<DateTime> orderDate = GeneratedColumn<DateTime>(
      'order_date', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  late final GeneratedColumnWithTypeConverter<OrderStatus, int> status =
      GeneratedColumn<int>('status', aliasedName, false,
              type: DriftSqlType.int,
              requiredDuringInsert: false,
              defaultValue: Constant(OrderStatus.pending.index))
          .withConverter<OrderStatus>($OrdersTable.$converterstatus);
  static const VerificationMeta _remarkMeta = const VerificationMeta('remark');
  @override
  late final GeneratedColumn<String> remark = GeneratedColumn<String>(
      'remark', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        waybillNo,
        merchantName,
        orderDate,
        status,
        remark,
        createdAt,
        updatedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'orders';
  @override
  VerificationContext validateIntegrity(Insertable<Order> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('waybill_no')) {
      context.handle(_waybillNoMeta,
          waybillNo.isAcceptableOrUnknown(data['waybill_no']!, _waybillNoMeta));
    } else if (isInserting) {
      context.missing(_waybillNoMeta);
    }
    if (data.containsKey('merchant_name')) {
      context.handle(
          _merchantNameMeta,
          merchantName.isAcceptableOrUnknown(
              data['merchant_name']!, _merchantNameMeta));
    } else if (isInserting) {
      context.missing(_merchantNameMeta);
    }
    if (data.containsKey('order_date')) {
      context.handle(_orderDateMeta,
          orderDate.isAcceptableOrUnknown(data['order_date']!, _orderDateMeta));
    } else if (isInserting) {
      context.missing(_orderDateMeta);
    }
    if (data.containsKey('remark')) {
      context.handle(_remarkMeta,
          remark.isAcceptableOrUnknown(data['remark']!, _remarkMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Order map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Order(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      waybillNo: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}waybill_no'])!,
      merchantName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}merchant_name'])!,
      orderDate: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}order_date'])!,
      status: $OrdersTable.$converterstatus.fromSql(attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}status'])!),
      remark: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}remark']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at']),
    );
  }

  @override
  $OrdersTable createAlias(String alias) {
    return $OrdersTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<OrderStatus, int, int> $converterstatus =
      const EnumIndexConverter<OrderStatus>(OrderStatus.values);
}

class Order extends DataClass implements Insertable<Order> {
  final int id;
  final String waybillNo;
  final String merchantName;
  final DateTime orderDate;
  final OrderStatus status;
  final String? remark;
  final DateTime createdAt;
  final DateTime? updatedAt;
  const Order(
      {required this.id,
      required this.waybillNo,
      required this.merchantName,
      required this.orderDate,
      required this.status,
      this.remark,
      required this.createdAt,
      this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['waybill_no'] = Variable<String>(waybillNo);
    map['merchant_name'] = Variable<String>(merchantName);
    map['order_date'] = Variable<DateTime>(orderDate);
    {
      map['status'] =
          Variable<int>($OrdersTable.$converterstatus.toSql(status));
    }
    if (!nullToAbsent || remark != null) {
      map['remark'] = Variable<String>(remark);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<DateTime>(updatedAt);
    }
    return map;
  }

  OrdersCompanion toCompanion(bool nullToAbsent) {
    return OrdersCompanion(
      id: Value(id),
      waybillNo: Value(waybillNo),
      merchantName: Value(merchantName),
      orderDate: Value(orderDate),
      status: Value(status),
      remark:
          remark == null && nullToAbsent ? const Value.absent() : Value(remark),
      createdAt: Value(createdAt),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
    );
  }

  factory Order.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Order(
      id: serializer.fromJson<int>(json['id']),
      waybillNo: serializer.fromJson<String>(json['waybillNo']),
      merchantName: serializer.fromJson<String>(json['merchantName']),
      orderDate: serializer.fromJson<DateTime>(json['orderDate']),
      status: $OrdersTable.$converterstatus
          .fromJson(serializer.fromJson<int>(json['status'])),
      remark: serializer.fromJson<String?>(json['remark']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime?>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'waybillNo': serializer.toJson<String>(waybillNo),
      'merchantName': serializer.toJson<String>(merchantName),
      'orderDate': serializer.toJson<DateTime>(orderDate),
      'status':
          serializer.toJson<int>($OrdersTable.$converterstatus.toJson(status)),
      'remark': serializer.toJson<String?>(remark),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime?>(updatedAt),
    };
  }

  Order copyWith(
          {int? id,
          String? waybillNo,
          String? merchantName,
          DateTime? orderDate,
          OrderStatus? status,
          Value<String?> remark = const Value.absent(),
          DateTime? createdAt,
          Value<DateTime?> updatedAt = const Value.absent()}) =>
      Order(
        id: id ?? this.id,
        waybillNo: waybillNo ?? this.waybillNo,
        merchantName: merchantName ?? this.merchantName,
        orderDate: orderDate ?? this.orderDate,
        status: status ?? this.status,
        remark: remark.present ? remark.value : this.remark,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
      );
  Order copyWithCompanion(OrdersCompanion data) {
    return Order(
      id: data.id.present ? data.id.value : this.id,
      waybillNo: data.waybillNo.present ? data.waybillNo.value : this.waybillNo,
      merchantName: data.merchantName.present
          ? data.merchantName.value
          : this.merchantName,
      orderDate: data.orderDate.present ? data.orderDate.value : this.orderDate,
      status: data.status.present ? data.status.value : this.status,
      remark: data.remark.present ? data.remark.value : this.remark,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Order(')
          ..write('id: $id, ')
          ..write('waybillNo: $waybillNo, ')
          ..write('merchantName: $merchantName, ')
          ..write('orderDate: $orderDate, ')
          ..write('status: $status, ')
          ..write('remark: $remark, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, waybillNo, merchantName, orderDate,
      status, remark, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Order &&
          other.id == this.id &&
          other.waybillNo == this.waybillNo &&
          other.merchantName == this.merchantName &&
          other.orderDate == this.orderDate &&
          other.status == this.status &&
          other.remark == this.remark &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class OrdersCompanion extends UpdateCompanion<Order> {
  final Value<int> id;
  final Value<String> waybillNo;
  final Value<String> merchantName;
  final Value<DateTime> orderDate;
  final Value<OrderStatus> status;
  final Value<String?> remark;
  final Value<DateTime> createdAt;
  final Value<DateTime?> updatedAt;
  const OrdersCompanion({
    this.id = const Value.absent(),
    this.waybillNo = const Value.absent(),
    this.merchantName = const Value.absent(),
    this.orderDate = const Value.absent(),
    this.status = const Value.absent(),
    this.remark = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  OrdersCompanion.insert({
    this.id = const Value.absent(),
    required String waybillNo,
    required String merchantName,
    required DateTime orderDate,
    this.status = const Value.absent(),
    this.remark = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  })  : waybillNo = Value(waybillNo),
        merchantName = Value(merchantName),
        orderDate = Value(orderDate);
  static Insertable<Order> custom({
    Expression<int>? id,
    Expression<String>? waybillNo,
    Expression<String>? merchantName,
    Expression<DateTime>? orderDate,
    Expression<int>? status,
    Expression<String>? remark,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (waybillNo != null) 'waybill_no': waybillNo,
      if (merchantName != null) 'merchant_name': merchantName,
      if (orderDate != null) 'order_date': orderDate,
      if (status != null) 'status': status,
      if (remark != null) 'remark': remark,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  OrdersCompanion copyWith(
      {Value<int>? id,
      Value<String>? waybillNo,
      Value<String>? merchantName,
      Value<DateTime>? orderDate,
      Value<OrderStatus>? status,
      Value<String?>? remark,
      Value<DateTime>? createdAt,
      Value<DateTime?>? updatedAt}) {
    return OrdersCompanion(
      id: id ?? this.id,
      waybillNo: waybillNo ?? this.waybillNo,
      merchantName: merchantName ?? this.merchantName,
      orderDate: orderDate ?? this.orderDate,
      status: status ?? this.status,
      remark: remark ?? this.remark,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (waybillNo.present) {
      map['waybill_no'] = Variable<String>(waybillNo.value);
    }
    if (merchantName.present) {
      map['merchant_name'] = Variable<String>(merchantName.value);
    }
    if (orderDate.present) {
      map['order_date'] = Variable<DateTime>(orderDate.value);
    }
    if (status.present) {
      map['status'] =
          Variable<int>($OrdersTable.$converterstatus.toSql(status.value));
    }
    if (remark.present) {
      map['remark'] = Variable<String>(remark.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OrdersCompanion(')
          ..write('id: $id, ')
          ..write('waybillNo: $waybillNo, ')
          ..write('merchantName: $merchantName, ')
          ..write('orderDate: $orderDate, ')
          ..write('status: $status, ')
          ..write('remark: $remark, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $OrderItemsTable extends OrderItems
    with TableInfo<$OrderItemsTable, OrderItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OrderItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _orderIdMeta =
      const VerificationMeta('orderId');
  @override
  late final GeneratedColumn<int> orderId = GeneratedColumn<int>(
      'order_id', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES orders (id)'));
  static const VerificationMeta _productIdMeta =
      const VerificationMeta('productId');
  @override
  late final GeneratedColumn<int> productId = GeneratedColumn<int>(
      'product_id', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES products (id)'));
  static const VerificationMeta _batchIdMeta =
      const VerificationMeta('batchId');
  @override
  late final GeneratedColumn<int> batchId = GeneratedColumn<int>(
      'batch_id', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES batches (id)'));
  static const VerificationMeta _boxesMeta = const VerificationMeta('boxes');
  @override
  late final GeneratedColumn<int> boxes = GeneratedColumn<int>(
      'boxes', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _boxesPerBoardMeta =
      const VerificationMeta('boxesPerBoard');
  @override
  late final GeneratedColumn<int> boxesPerBoard = GeneratedColumn<int>(
      'boxes_per_board', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _piecesPerBoxMeta =
      const VerificationMeta('piecesPerBox');
  @override
  late final GeneratedColumn<int> piecesPerBox = GeneratedColumn<int>(
      'pieces_per_box', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        orderId,
        productId,
        batchId,
        boxes,
        boxesPerBoard,
        piecesPerBox,
        createdAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'order_items';
  @override
  VerificationContext validateIntegrity(Insertable<OrderItem> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('order_id')) {
      context.handle(_orderIdMeta,
          orderId.isAcceptableOrUnknown(data['order_id']!, _orderIdMeta));
    } else if (isInserting) {
      context.missing(_orderIdMeta);
    }
    if (data.containsKey('product_id')) {
      context.handle(_productIdMeta,
          productId.isAcceptableOrUnknown(data['product_id']!, _productIdMeta));
    } else if (isInserting) {
      context.missing(_productIdMeta);
    }
    if (data.containsKey('batch_id')) {
      context.handle(_batchIdMeta,
          batchId.isAcceptableOrUnknown(data['batch_id']!, _batchIdMeta));
    } else if (isInserting) {
      context.missing(_batchIdMeta);
    }
    if (data.containsKey('boxes')) {
      context.handle(
          _boxesMeta, boxes.isAcceptableOrUnknown(data['boxes']!, _boxesMeta));
    } else if (isInserting) {
      context.missing(_boxesMeta);
    }
    if (data.containsKey('boxes_per_board')) {
      context.handle(
          _boxesPerBoardMeta,
          boxesPerBoard.isAcceptableOrUnknown(
              data['boxes_per_board']!, _boxesPerBoardMeta));
    } else if (isInserting) {
      context.missing(_boxesPerBoardMeta);
    }
    if (data.containsKey('pieces_per_box')) {
      context.handle(
          _piecesPerBoxMeta,
          piecesPerBox.isAcceptableOrUnknown(
              data['pieces_per_box']!, _piecesPerBoxMeta));
    } else if (isInserting) {
      context.missing(_piecesPerBoxMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  OrderItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OrderItem(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      orderId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}order_id'])!,
      productId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}product_id'])!,
      batchId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}batch_id'])!,
      boxes: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}boxes'])!,
      boxesPerBoard: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}boxes_per_board'])!,
      piecesPerBox: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}pieces_per_box'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $OrderItemsTable createAlias(String alias) {
    return $OrderItemsTable(attachedDatabase, alias);
  }
}

class OrderItem extends DataClass implements Insertable<OrderItem> {
  final int id;
  final int orderId;
  final int productId;
  final int batchId;
  final int boxes;
  final int boxesPerBoard;
  final int piecesPerBox;
  final DateTime createdAt;
  const OrderItem(
      {required this.id,
      required this.orderId,
      required this.productId,
      required this.batchId,
      required this.boxes,
      required this.boxesPerBoard,
      required this.piecesPerBox,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['order_id'] = Variable<int>(orderId);
    map['product_id'] = Variable<int>(productId);
    map['batch_id'] = Variable<int>(batchId);
    map['boxes'] = Variable<int>(boxes);
    map['boxes_per_board'] = Variable<int>(boxesPerBoard);
    map['pieces_per_box'] = Variable<int>(piecesPerBox);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  OrderItemsCompanion toCompanion(bool nullToAbsent) {
    return OrderItemsCompanion(
      id: Value(id),
      orderId: Value(orderId),
      productId: Value(productId),
      batchId: Value(batchId),
      boxes: Value(boxes),
      boxesPerBoard: Value(boxesPerBoard),
      piecesPerBox: Value(piecesPerBox),
      createdAt: Value(createdAt),
    );
  }

  factory OrderItem.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OrderItem(
      id: serializer.fromJson<int>(json['id']),
      orderId: serializer.fromJson<int>(json['orderId']),
      productId: serializer.fromJson<int>(json['productId']),
      batchId: serializer.fromJson<int>(json['batchId']),
      boxes: serializer.fromJson<int>(json['boxes']),
      boxesPerBoard: serializer.fromJson<int>(json['boxesPerBoard']),
      piecesPerBox: serializer.fromJson<int>(json['piecesPerBox']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'orderId': serializer.toJson<int>(orderId),
      'productId': serializer.toJson<int>(productId),
      'batchId': serializer.toJson<int>(batchId),
      'boxes': serializer.toJson<int>(boxes),
      'boxesPerBoard': serializer.toJson<int>(boxesPerBoard),
      'piecesPerBox': serializer.toJson<int>(piecesPerBox),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  OrderItem copyWith(
          {int? id,
          int? orderId,
          int? productId,
          int? batchId,
          int? boxes,
          int? boxesPerBoard,
          int? piecesPerBox,
          DateTime? createdAt}) =>
      OrderItem(
        id: id ?? this.id,
        orderId: orderId ?? this.orderId,
        productId: productId ?? this.productId,
        batchId: batchId ?? this.batchId,
        boxes: boxes ?? this.boxes,
        boxesPerBoard: boxesPerBoard ?? this.boxesPerBoard,
        piecesPerBox: piecesPerBox ?? this.piecesPerBox,
        createdAt: createdAt ?? this.createdAt,
      );
  OrderItem copyWithCompanion(OrderItemsCompanion data) {
    return OrderItem(
      id: data.id.present ? data.id.value : this.id,
      orderId: data.orderId.present ? data.orderId.value : this.orderId,
      productId: data.productId.present ? data.productId.value : this.productId,
      batchId: data.batchId.present ? data.batchId.value : this.batchId,
      boxes: data.boxes.present ? data.boxes.value : this.boxes,
      boxesPerBoard: data.boxesPerBoard.present
          ? data.boxesPerBoard.value
          : this.boxesPerBoard,
      piecesPerBox: data.piecesPerBox.present
          ? data.piecesPerBox.value
          : this.piecesPerBox,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OrderItem(')
          ..write('id: $id, ')
          ..write('orderId: $orderId, ')
          ..write('productId: $productId, ')
          ..write('batchId: $batchId, ')
          ..write('boxes: $boxes, ')
          ..write('boxesPerBoard: $boxesPerBoard, ')
          ..write('piecesPerBox: $piecesPerBox, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, orderId, productId, batchId, boxes,
      boxesPerBoard, piecesPerBox, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OrderItem &&
          other.id == this.id &&
          other.orderId == this.orderId &&
          other.productId == this.productId &&
          other.batchId == this.batchId &&
          other.boxes == this.boxes &&
          other.boxesPerBoard == this.boxesPerBoard &&
          other.piecesPerBox == this.piecesPerBox &&
          other.createdAt == this.createdAt);
}

class OrderItemsCompanion extends UpdateCompanion<OrderItem> {
  final Value<int> id;
  final Value<int> orderId;
  final Value<int> productId;
  final Value<int> batchId;
  final Value<int> boxes;
  final Value<int> boxesPerBoard;
  final Value<int> piecesPerBox;
  final Value<DateTime> createdAt;
  const OrderItemsCompanion({
    this.id = const Value.absent(),
    this.orderId = const Value.absent(),
    this.productId = const Value.absent(),
    this.batchId = const Value.absent(),
    this.boxes = const Value.absent(),
    this.boxesPerBoard = const Value.absent(),
    this.piecesPerBox = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  OrderItemsCompanion.insert({
    this.id = const Value.absent(),
    required int orderId,
    required int productId,
    required int batchId,
    required int boxes,
    required int boxesPerBoard,
    required int piecesPerBox,
    this.createdAt = const Value.absent(),
  })  : orderId = Value(orderId),
        productId = Value(productId),
        batchId = Value(batchId),
        boxes = Value(boxes),
        boxesPerBoard = Value(boxesPerBoard),
        piecesPerBox = Value(piecesPerBox);
  static Insertable<OrderItem> custom({
    Expression<int>? id,
    Expression<int>? orderId,
    Expression<int>? productId,
    Expression<int>? batchId,
    Expression<int>? boxes,
    Expression<int>? boxesPerBoard,
    Expression<int>? piecesPerBox,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (orderId != null) 'order_id': orderId,
      if (productId != null) 'product_id': productId,
      if (batchId != null) 'batch_id': batchId,
      if (boxes != null) 'boxes': boxes,
      if (boxesPerBoard != null) 'boxes_per_board': boxesPerBoard,
      if (piecesPerBox != null) 'pieces_per_box': piecesPerBox,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  OrderItemsCompanion copyWith(
      {Value<int>? id,
      Value<int>? orderId,
      Value<int>? productId,
      Value<int>? batchId,
      Value<int>? boxes,
      Value<int>? boxesPerBoard,
      Value<int>? piecesPerBox,
      Value<DateTime>? createdAt}) {
    return OrderItemsCompanion(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      productId: productId ?? this.productId,
      batchId: batchId ?? this.batchId,
      boxes: boxes ?? this.boxes,
      boxesPerBoard: boxesPerBoard ?? this.boxesPerBoard,
      piecesPerBox: piecesPerBox ?? this.piecesPerBox,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (orderId.present) {
      map['order_id'] = Variable<int>(orderId.value);
    }
    if (productId.present) {
      map['product_id'] = Variable<int>(productId.value);
    }
    if (batchId.present) {
      map['batch_id'] = Variable<int>(batchId.value);
    }
    if (boxes.present) {
      map['boxes'] = Variable<int>(boxes.value);
    }
    if (boxesPerBoard.present) {
      map['boxes_per_board'] = Variable<int>(boxesPerBoard.value);
    }
    if (piecesPerBox.present) {
      map['pieces_per_box'] = Variable<int>(piecesPerBox.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OrderItemsCompanion(')
          ..write('id: $id, ')
          ..write('orderId: $orderId, ')
          ..write('productId: $productId, ')
          ..write('batchId: $batchId, ')
          ..write('boxes: $boxes, ')
          ..write('boxesPerBoard: $boxesPerBoard, ')
          ..write('piecesPerBox: $piecesPerBox, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $StockMovementsTable extends StockMovements
    with TableInfo<$StockMovementsTable, StockMovement> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StockMovementsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _batchIdMeta =
      const VerificationMeta('batchId');
  @override
  late final GeneratedColumn<int> batchId = GeneratedColumn<int>(
      'batch_id', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES batches (id)'));
  static const VerificationMeta _orderIdMeta =
      const VerificationMeta('orderId');
  @override
  late final GeneratedColumn<int> orderId = GeneratedColumn<int>(
      'order_id', aliasedName, true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES orders (id)'));
  static const VerificationMeta _movementDateMeta =
      const VerificationMeta('movementDate');
  @override
  late final GeneratedColumn<DateTime> movementDate = GeneratedColumn<DateTime>(
      'movement_date', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  late final GeneratedColumnWithTypeConverter<StockMovementType, int> type =
      GeneratedColumn<int>('type', aliasedName, false,
              type: DriftSqlType.int, requiredDuringInsert: true)
          .withConverter<StockMovementType>(
              $StockMovementsTable.$convertertype);
  static const VerificationMeta _boxesMeta = const VerificationMeta('boxes');
  @override
  late final GeneratedColumn<int> boxes = GeneratedColumn<int>(
      'boxes', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _remarkMeta = const VerificationMeta('remark');
  @override
  late final GeneratedColumn<String> remark = GeneratedColumn<String>(
      'remark', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns =>
      [id, batchId, orderId, movementDate, type, boxes, remark, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'stock_movements';
  @override
  VerificationContext validateIntegrity(Insertable<StockMovement> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('batch_id')) {
      context.handle(_batchIdMeta,
          batchId.isAcceptableOrUnknown(data['batch_id']!, _batchIdMeta));
    } else if (isInserting) {
      context.missing(_batchIdMeta);
    }
    if (data.containsKey('order_id')) {
      context.handle(_orderIdMeta,
          orderId.isAcceptableOrUnknown(data['order_id']!, _orderIdMeta));
    }
    if (data.containsKey('movement_date')) {
      context.handle(
          _movementDateMeta,
          movementDate.isAcceptableOrUnknown(
              data['movement_date']!, _movementDateMeta));
    } else if (isInserting) {
      context.missing(_movementDateMeta);
    }
    if (data.containsKey('boxes')) {
      context.handle(
          _boxesMeta, boxes.isAcceptableOrUnknown(data['boxes']!, _boxesMeta));
    } else if (isInserting) {
      context.missing(_boxesMeta);
    }
    if (data.containsKey('remark')) {
      context.handle(_remarkMeta,
          remark.isAcceptableOrUnknown(data['remark']!, _remarkMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  StockMovement map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StockMovement(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      batchId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}batch_id'])!,
      orderId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}order_id']),
      movementDate: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}movement_date'])!,
      type: $StockMovementsTable.$convertertype.fromSql(attachedDatabase
          .typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}type'])!),
      boxes: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}boxes'])!,
      remark: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}remark']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $StockMovementsTable createAlias(String alias) {
    return $StockMovementsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<StockMovementType, int, int> $convertertype =
      const EnumIndexConverter<StockMovementType>(StockMovementType.values);
}

class StockMovement extends DataClass implements Insertable<StockMovement> {
  final int id;
  final int batchId;
  final int? orderId;
  final DateTime movementDate;
  final StockMovementType type;
  final int boxes;
  final String? remark;
  final DateTime createdAt;
  const StockMovement(
      {required this.id,
      required this.batchId,
      this.orderId,
      required this.movementDate,
      required this.type,
      required this.boxes,
      this.remark,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['batch_id'] = Variable<int>(batchId);
    if (!nullToAbsent || orderId != null) {
      map['order_id'] = Variable<int>(orderId);
    }
    map['movement_date'] = Variable<DateTime>(movementDate);
    {
      map['type'] =
          Variable<int>($StockMovementsTable.$convertertype.toSql(type));
    }
    map['boxes'] = Variable<int>(boxes);
    if (!nullToAbsent || remark != null) {
      map['remark'] = Variable<String>(remark);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  StockMovementsCompanion toCompanion(bool nullToAbsent) {
    return StockMovementsCompanion(
      id: Value(id),
      batchId: Value(batchId),
      orderId: orderId == null && nullToAbsent
          ? const Value.absent()
          : Value(orderId),
      movementDate: Value(movementDate),
      type: Value(type),
      boxes: Value(boxes),
      remark:
          remark == null && nullToAbsent ? const Value.absent() : Value(remark),
      createdAt: Value(createdAt),
    );
  }

  factory StockMovement.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StockMovement(
      id: serializer.fromJson<int>(json['id']),
      batchId: serializer.fromJson<int>(json['batchId']),
      orderId: serializer.fromJson<int?>(json['orderId']),
      movementDate: serializer.fromJson<DateTime>(json['movementDate']),
      type: $StockMovementsTable.$convertertype
          .fromJson(serializer.fromJson<int>(json['type'])),
      boxes: serializer.fromJson<int>(json['boxes']),
      remark: serializer.fromJson<String?>(json['remark']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'batchId': serializer.toJson<int>(batchId),
      'orderId': serializer.toJson<int?>(orderId),
      'movementDate': serializer.toJson<DateTime>(movementDate),
      'type': serializer
          .toJson<int>($StockMovementsTable.$convertertype.toJson(type)),
      'boxes': serializer.toJson<int>(boxes),
      'remark': serializer.toJson<String?>(remark),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  StockMovement copyWith(
          {int? id,
          int? batchId,
          Value<int?> orderId = const Value.absent(),
          DateTime? movementDate,
          StockMovementType? type,
          int? boxes,
          Value<String?> remark = const Value.absent(),
          DateTime? createdAt}) =>
      StockMovement(
        id: id ?? this.id,
        batchId: batchId ?? this.batchId,
        orderId: orderId.present ? orderId.value : this.orderId,
        movementDate: movementDate ?? this.movementDate,
        type: type ?? this.type,
        boxes: boxes ?? this.boxes,
        remark: remark.present ? remark.value : this.remark,
        createdAt: createdAt ?? this.createdAt,
      );
  StockMovement copyWithCompanion(StockMovementsCompanion data) {
    return StockMovement(
      id: data.id.present ? data.id.value : this.id,
      batchId: data.batchId.present ? data.batchId.value : this.batchId,
      orderId: data.orderId.present ? data.orderId.value : this.orderId,
      movementDate: data.movementDate.present
          ? data.movementDate.value
          : this.movementDate,
      type: data.type.present ? data.type.value : this.type,
      boxes: data.boxes.present ? data.boxes.value : this.boxes,
      remark: data.remark.present ? data.remark.value : this.remark,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StockMovement(')
          ..write('id: $id, ')
          ..write('batchId: $batchId, ')
          ..write('orderId: $orderId, ')
          ..write('movementDate: $movementDate, ')
          ..write('type: $type, ')
          ..write('boxes: $boxes, ')
          ..write('remark: $remark, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id, batchId, orderId, movementDate, type, boxes, remark, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StockMovement &&
          other.id == this.id &&
          other.batchId == this.batchId &&
          other.orderId == this.orderId &&
          other.movementDate == this.movementDate &&
          other.type == this.type &&
          other.boxes == this.boxes &&
          other.remark == this.remark &&
          other.createdAt == this.createdAt);
}

class StockMovementsCompanion extends UpdateCompanion<StockMovement> {
  final Value<int> id;
  final Value<int> batchId;
  final Value<int?> orderId;
  final Value<DateTime> movementDate;
  final Value<StockMovementType> type;
  final Value<int> boxes;
  final Value<String?> remark;
  final Value<DateTime> createdAt;
  const StockMovementsCompanion({
    this.id = const Value.absent(),
    this.batchId = const Value.absent(),
    this.orderId = const Value.absent(),
    this.movementDate = const Value.absent(),
    this.type = const Value.absent(),
    this.boxes = const Value.absent(),
    this.remark = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  StockMovementsCompanion.insert({
    this.id = const Value.absent(),
    required int batchId,
    this.orderId = const Value.absent(),
    required DateTime movementDate,
    required StockMovementType type,
    required int boxes,
    this.remark = const Value.absent(),
    this.createdAt = const Value.absent(),
  })  : batchId = Value(batchId),
        movementDate = Value(movementDate),
        type = Value(type),
        boxes = Value(boxes);
  static Insertable<StockMovement> custom({
    Expression<int>? id,
    Expression<int>? batchId,
    Expression<int>? orderId,
    Expression<DateTime>? movementDate,
    Expression<int>? type,
    Expression<int>? boxes,
    Expression<String>? remark,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (batchId != null) 'batch_id': batchId,
      if (orderId != null) 'order_id': orderId,
      if (movementDate != null) 'movement_date': movementDate,
      if (type != null) 'type': type,
      if (boxes != null) 'boxes': boxes,
      if (remark != null) 'remark': remark,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  StockMovementsCompanion copyWith(
      {Value<int>? id,
      Value<int>? batchId,
      Value<int?>? orderId,
      Value<DateTime>? movementDate,
      Value<StockMovementType>? type,
      Value<int>? boxes,
      Value<String?>? remark,
      Value<DateTime>? createdAt}) {
    return StockMovementsCompanion(
      id: id ?? this.id,
      batchId: batchId ?? this.batchId,
      orderId: orderId ?? this.orderId,
      movementDate: movementDate ?? this.movementDate,
      type: type ?? this.type,
      boxes: boxes ?? this.boxes,
      remark: remark ?? this.remark,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (batchId.present) {
      map['batch_id'] = Variable<int>(batchId.value);
    }
    if (orderId.present) {
      map['order_id'] = Variable<int>(orderId.value);
    }
    if (movementDate.present) {
      map['movement_date'] = Variable<DateTime>(movementDate.value);
    }
    if (type.present) {
      map['type'] =
          Variable<int>($StockMovementsTable.$convertertype.toSql(type.value));
    }
    if (boxes.present) {
      map['boxes'] = Variable<int>(boxes.value);
    }
    if (remark.present) {
      map['remark'] = Variable<String>(remark.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StockMovementsCompanion(')
          ..write('id: $id, ')
          ..write('batchId: $batchId, ')
          ..write('orderId: $orderId, ')
          ..write('movementDate: $movementDate, ')
          ..write('type: $type, ')
          ..write('boxes: $boxes, ')
          ..write('remark: $remark, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $ProductsTable products = $ProductsTable(this);
  late final $BatchesTable batches = $BatchesTable(this);
  late final $OrdersTable orders = $OrdersTable(this);
  late final $OrderItemsTable orderItems = $OrderItemsTable(this);
  late final $StockMovementsTable stockMovements = $StockMovementsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities =>
      [products, batches, orders, orderItems, stockMovements];
}

typedef $$ProductsTableCreateCompanionBuilder = ProductsCompanion Function({
  Value<int> id,
  required String code,
  required String name,
  required int boxesPerBoard,
  required int piecesPerBox,
  Value<DateTime> createdAt,
  Value<DateTime?> updatedAt,
});
typedef $$ProductsTableUpdateCompanionBuilder = ProductsCompanion Function({
  Value<int> id,
  Value<String> code,
  Value<String> name,
  Value<int> boxesPerBoard,
  Value<int> piecesPerBox,
  Value<DateTime> createdAt,
  Value<DateTime?> updatedAt,
});

final class $$ProductsTableReferences
    extends BaseReferences<_$AppDatabase, $ProductsTable, Product> {
  $$ProductsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$BatchesTable, List<BatchRecord>>
      _batchesRefsTable(_$AppDatabase db) =>
          MultiTypedResultKey.fromTable(db.batches,
              aliasName:
                  $_aliasNameGenerator(db.products.id, db.batches.productId));

  $$BatchesTableProcessedTableManager get batchesRefs {
    final manager = $$BatchesTableTableManager($_db, $_db.batches)
        .filter((f) => f.productId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_batchesRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<$OrderItemsTable, List<OrderItem>>
      _orderItemsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
          db.orderItems,
          aliasName:
              $_aliasNameGenerator(db.products.id, db.orderItems.productId));

  $$OrderItemsTableProcessedTableManager get orderItemsRefs {
    final manager = $$OrderItemsTableTableManager($_db, $_db.orderItems)
        .filter((f) => f.productId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_orderItemsRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$ProductsTableFilterComposer
    extends Composer<_$AppDatabase, $ProductsTable> {
  $$ProductsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get code => $composableBuilder(
      column: $table.code, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get boxesPerBoard => $composableBuilder(
      column: $table.boxesPerBoard, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get piecesPerBox => $composableBuilder(
      column: $table.piecesPerBox, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  Expression<bool> batchesRefs(
      Expression<bool> Function($$BatchesTableFilterComposer f) f) {
    final $$BatchesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.batches,
        getReferencedColumn: (t) => t.productId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$BatchesTableFilterComposer(
              $db: $db,
              $table: $db.batches,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<bool> orderItemsRefs(
      Expression<bool> Function($$OrderItemsTableFilterComposer f) f) {
    final $$OrderItemsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.orderItems,
        getReferencedColumn: (t) => t.productId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$OrderItemsTableFilterComposer(
              $db: $db,
              $table: $db.orderItems,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$ProductsTableOrderingComposer
    extends Composer<_$AppDatabase, $ProductsTable> {
  $$ProductsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get code => $composableBuilder(
      column: $table.code, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get boxesPerBoard => $composableBuilder(
      column: $table.boxesPerBoard,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get piecesPerBox => $composableBuilder(
      column: $table.piecesPerBox,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$ProductsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ProductsTable> {
  $$ProductsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get code =>
      $composableBuilder(column: $table.code, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get boxesPerBoard => $composableBuilder(
      column: $table.boxesPerBoard, builder: (column) => column);

  GeneratedColumn<int> get piecesPerBox => $composableBuilder(
      column: $table.piecesPerBox, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> batchesRefs<T extends Object>(
      Expression<T> Function($$BatchesTableAnnotationComposer a) f) {
    final $$BatchesTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.batches,
        getReferencedColumn: (t) => t.productId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$BatchesTableAnnotationComposer(
              $db: $db,
              $table: $db.batches,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<T> orderItemsRefs<T extends Object>(
      Expression<T> Function($$OrderItemsTableAnnotationComposer a) f) {
    final $$OrderItemsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.orderItems,
        getReferencedColumn: (t) => t.productId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$OrderItemsTableAnnotationComposer(
              $db: $db,
              $table: $db.orderItems,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$ProductsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ProductsTable,
    Product,
    $$ProductsTableFilterComposer,
    $$ProductsTableOrderingComposer,
    $$ProductsTableAnnotationComposer,
    $$ProductsTableCreateCompanionBuilder,
    $$ProductsTableUpdateCompanionBuilder,
    (Product, $$ProductsTableReferences),
    Product,
    PrefetchHooks Function({bool batchesRefs, bool orderItemsRefs})> {
  $$ProductsTableTableManager(_$AppDatabase db, $ProductsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProductsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProductsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ProductsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> code = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<int> boxesPerBoard = const Value.absent(),
            Value<int> piecesPerBox = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime?> updatedAt = const Value.absent(),
          }) =>
              ProductsCompanion(
            id: id,
            code: code,
            name: name,
            boxesPerBoard: boxesPerBoard,
            piecesPerBox: piecesPerBox,
            createdAt: createdAt,
            updatedAt: updatedAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String code,
            required String name,
            required int boxesPerBoard,
            required int piecesPerBox,
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime?> updatedAt = const Value.absent(),
          }) =>
              ProductsCompanion.insert(
            id: id,
            code: code,
            name: name,
            boxesPerBoard: boxesPerBoard,
            piecesPerBox: piecesPerBox,
            createdAt: createdAt,
            updatedAt: updatedAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) =>
                  (e.readTable(table), $$ProductsTableReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: (
              {batchesRefs = false, orderItemsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (batchesRefs) db.batches,
                if (orderItemsRefs) db.orderItems
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (batchesRefs)
                    await $_getPrefetchedData<Product, $ProductsTable,
                            BatchRecord>(
                        currentTable: table,
                        referencedTable:
                            $$ProductsTableReferences._batchesRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$ProductsTableReferences(db, table, p0)
                                .batchesRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems
                                .where((e) => e.productId == item.id),
                        typedResults: items),
                  if (orderItemsRefs)
                    await $_getPrefetchedData<Product, $ProductsTable,
                            OrderItem>(
                        currentTable: table,
                        referencedTable:
                            $$ProductsTableReferences._orderItemsRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$ProductsTableReferences(db, table, p0)
                                .orderItemsRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems
                                .where((e) => e.productId == item.id),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$ProductsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $ProductsTable,
    Product,
    $$ProductsTableFilterComposer,
    $$ProductsTableOrderingComposer,
    $$ProductsTableAnnotationComposer,
    $$ProductsTableCreateCompanionBuilder,
    $$ProductsTableUpdateCompanionBuilder,
    (Product, $$ProductsTableReferences),
    Product,
    PrefetchHooks Function({bool batchesRefs, bool orderItemsRefs})>;
typedef $$BatchesTableCreateCompanionBuilder = BatchesCompanion Function({
  Value<int> id,
  required int productId,
  required String actualBatch,
  required String dateBatch,
  required int initialBoxes,
  required int boxesPerBoard,
  Value<String?> stackingPattern,
  Value<String?> location,
  Value<bool> hasShipped,
  Value<bool> tsRequired,
  Value<String?> remark,
  Value<DateTime> createdAt,
  Value<DateTime?> updatedAt,
});
typedef $$BatchesTableUpdateCompanionBuilder = BatchesCompanion Function({
  Value<int> id,
  Value<int> productId,
  Value<String> actualBatch,
  Value<String> dateBatch,
  Value<int> initialBoxes,
  Value<int> boxesPerBoard,
  Value<String?> stackingPattern,
  Value<String?> location,
  Value<bool> hasShipped,
  Value<bool> tsRequired,
  Value<String?> remark,
  Value<DateTime> createdAt,
  Value<DateTime?> updatedAt,
});

final class $$BatchesTableReferences
    extends BaseReferences<_$AppDatabase, $BatchesTable, BatchRecord> {
  $$BatchesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ProductsTable _productIdTable(_$AppDatabase db) => db.products
      .createAlias($_aliasNameGenerator(db.batches.productId, db.products.id));

  $$ProductsTableProcessedTableManager get productId {
    final $_column = $_itemColumn<int>('product_id')!;

    final manager = $$ProductsTableTableManager($_db, $_db.products)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_productIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }

  static MultiTypedResultKey<$OrderItemsTable, List<OrderItem>>
      _orderItemsRefsTable(_$AppDatabase db) =>
          MultiTypedResultKey.fromTable(db.orderItems,
              aliasName:
                  $_aliasNameGenerator(db.batches.id, db.orderItems.batchId));

  $$OrderItemsTableProcessedTableManager get orderItemsRefs {
    final manager = $$OrderItemsTableTableManager($_db, $_db.orderItems)
        .filter((f) => f.batchId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_orderItemsRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<$StockMovementsTable, List<StockMovement>>
      _stockMovementsRefsTable(_$AppDatabase db) =>
          MultiTypedResultKey.fromTable(db.stockMovements,
              aliasName: $_aliasNameGenerator(
                  db.batches.id, db.stockMovements.batchId));

  $$StockMovementsTableProcessedTableManager get stockMovementsRefs {
    final manager = $$StockMovementsTableTableManager($_db, $_db.stockMovements)
        .filter((f) => f.batchId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_stockMovementsRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$BatchesTableFilterComposer
    extends Composer<_$AppDatabase, $BatchesTable> {
  $$BatchesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get actualBatch => $composableBuilder(
      column: $table.actualBatch, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get dateBatch => $composableBuilder(
      column: $table.dateBatch, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get initialBoxes => $composableBuilder(
      column: $table.initialBoxes, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get boxesPerBoard => $composableBuilder(
      column: $table.boxesPerBoard, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get stackingPattern => $composableBuilder(
      column: $table.stackingPattern,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get location => $composableBuilder(
      column: $table.location, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get hasShipped => $composableBuilder(
      column: $table.hasShipped, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get tsRequired => $composableBuilder(
      column: $table.tsRequired, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get remark => $composableBuilder(
      column: $table.remark, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  $$ProductsTableFilterComposer get productId {
    final $$ProductsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.productId,
        referencedTable: $db.products,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ProductsTableFilterComposer(
              $db: $db,
              $table: $db.products,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  Expression<bool> orderItemsRefs(
      Expression<bool> Function($$OrderItemsTableFilterComposer f) f) {
    final $$OrderItemsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.orderItems,
        getReferencedColumn: (t) => t.batchId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$OrderItemsTableFilterComposer(
              $db: $db,
              $table: $db.orderItems,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<bool> stockMovementsRefs(
      Expression<bool> Function($$StockMovementsTableFilterComposer f) f) {
    final $$StockMovementsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.stockMovements,
        getReferencedColumn: (t) => t.batchId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$StockMovementsTableFilterComposer(
              $db: $db,
              $table: $db.stockMovements,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$BatchesTableOrderingComposer
    extends Composer<_$AppDatabase, $BatchesTable> {
  $$BatchesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get actualBatch => $composableBuilder(
      column: $table.actualBatch, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get dateBatch => $composableBuilder(
      column: $table.dateBatch, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get initialBoxes => $composableBuilder(
      column: $table.initialBoxes,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get boxesPerBoard => $composableBuilder(
      column: $table.boxesPerBoard,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get stackingPattern => $composableBuilder(
      column: $table.stackingPattern,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get location => $composableBuilder(
      column: $table.location, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get hasShipped => $composableBuilder(
      column: $table.hasShipped, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get tsRequired => $composableBuilder(
      column: $table.tsRequired, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get remark => $composableBuilder(
      column: $table.remark, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  $$ProductsTableOrderingComposer get productId {
    final $$ProductsTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.productId,
        referencedTable: $db.products,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ProductsTableOrderingComposer(
              $db: $db,
              $table: $db.products,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$BatchesTableAnnotationComposer
    extends Composer<_$AppDatabase, $BatchesTable> {
  $$BatchesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get actualBatch => $composableBuilder(
      column: $table.actualBatch, builder: (column) => column);

  GeneratedColumn<String> get dateBatch =>
      $composableBuilder(column: $table.dateBatch, builder: (column) => column);

  GeneratedColumn<int> get initialBoxes => $composableBuilder(
      column: $table.initialBoxes, builder: (column) => column);

  GeneratedColumn<int> get boxesPerBoard => $composableBuilder(
      column: $table.boxesPerBoard, builder: (column) => column);

  GeneratedColumn<String> get stackingPattern => $composableBuilder(
      column: $table.stackingPattern, builder: (column) => column);

  GeneratedColumn<String> get location =>
      $composableBuilder(column: $table.location, builder: (column) => column);

  GeneratedColumn<bool> get hasShipped => $composableBuilder(
      column: $table.hasShipped, builder: (column) => column);

  GeneratedColumn<bool> get tsRequired => $composableBuilder(
      column: $table.tsRequired, builder: (column) => column);

  GeneratedColumn<String> get remark =>
      $composableBuilder(column: $table.remark, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$ProductsTableAnnotationComposer get productId {
    final $$ProductsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.productId,
        referencedTable: $db.products,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ProductsTableAnnotationComposer(
              $db: $db,
              $table: $db.products,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  Expression<T> orderItemsRefs<T extends Object>(
      Expression<T> Function($$OrderItemsTableAnnotationComposer a) f) {
    final $$OrderItemsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.orderItems,
        getReferencedColumn: (t) => t.batchId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$OrderItemsTableAnnotationComposer(
              $db: $db,
              $table: $db.orderItems,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<T> stockMovementsRefs<T extends Object>(
      Expression<T> Function($$StockMovementsTableAnnotationComposer a) f) {
    final $$StockMovementsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.stockMovements,
        getReferencedColumn: (t) => t.batchId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$StockMovementsTableAnnotationComposer(
              $db: $db,
              $table: $db.stockMovements,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$BatchesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $BatchesTable,
    BatchRecord,
    $$BatchesTableFilterComposer,
    $$BatchesTableOrderingComposer,
    $$BatchesTableAnnotationComposer,
    $$BatchesTableCreateCompanionBuilder,
    $$BatchesTableUpdateCompanionBuilder,
    (BatchRecord, $$BatchesTableReferences),
    BatchRecord,
    PrefetchHooks Function(
        {bool productId, bool orderItemsRefs, bool stockMovementsRefs})> {
  $$BatchesTableTableManager(_$AppDatabase db, $BatchesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BatchesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BatchesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BatchesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int> productId = const Value.absent(),
            Value<String> actualBatch = const Value.absent(),
            Value<String> dateBatch = const Value.absent(),
            Value<int> initialBoxes = const Value.absent(),
            Value<int> boxesPerBoard = const Value.absent(),
            Value<String?> stackingPattern = const Value.absent(),
            Value<String?> location = const Value.absent(),
            Value<bool> hasShipped = const Value.absent(),
            Value<bool> tsRequired = const Value.absent(),
            Value<String?> remark = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime?> updatedAt = const Value.absent(),
          }) =>
              BatchesCompanion(
            id: id,
            productId: productId,
            actualBatch: actualBatch,
            dateBatch: dateBatch,
            initialBoxes: initialBoxes,
            boxesPerBoard: boxesPerBoard,
            stackingPattern: stackingPattern,
            location: location,
            hasShipped: hasShipped,
            tsRequired: tsRequired,
            remark: remark,
            createdAt: createdAt,
            updatedAt: updatedAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required int productId,
            required String actualBatch,
            required String dateBatch,
            required int initialBoxes,
            required int boxesPerBoard,
            Value<String?> stackingPattern = const Value.absent(),
            Value<String?> location = const Value.absent(),
            Value<bool> hasShipped = const Value.absent(),
            Value<bool> tsRequired = const Value.absent(),
            Value<String?> remark = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime?> updatedAt = const Value.absent(),
          }) =>
              BatchesCompanion.insert(
            id: id,
            productId: productId,
            actualBatch: actualBatch,
            dateBatch: dateBatch,
            initialBoxes: initialBoxes,
            boxesPerBoard: boxesPerBoard,
            stackingPattern: stackingPattern,
            location: location,
            hasShipped: hasShipped,
            tsRequired: tsRequired,
            remark: remark,
            createdAt: createdAt,
            updatedAt: updatedAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) =>
                  (e.readTable(table), $$BatchesTableReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: (
              {productId = false,
              orderItemsRefs = false,
              stockMovementsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (orderItemsRefs) db.orderItems,
                if (stockMovementsRefs) db.stockMovements
              ],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (productId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.productId,
                    referencedTable:
                        $$BatchesTableReferences._productIdTable(db),
                    referencedColumn:
                        $$BatchesTableReferences._productIdTable(db).id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (orderItemsRefs)
                    await $_getPrefetchedData<BatchRecord, $BatchesTable,
                            OrderItem>(
                        currentTable: table,
                        referencedTable:
                            $$BatchesTableReferences._orderItemsRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$BatchesTableReferences(db, table, p0)
                                .orderItemsRefs,
                        referencedItemsForCurrentItem: (item,
                                referencedItems) =>
                            referencedItems.where((e) => e.batchId == item.id),
                        typedResults: items),
                  if (stockMovementsRefs)
                    await $_getPrefetchedData<BatchRecord, $BatchesTable,
                            StockMovement>(
                        currentTable: table,
                        referencedTable: $$BatchesTableReferences
                            ._stockMovementsRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$BatchesTableReferences(db, table, p0)
                                .stockMovementsRefs,
                        referencedItemsForCurrentItem: (item,
                                referencedItems) =>
                            referencedItems.where((e) => e.batchId == item.id),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$BatchesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $BatchesTable,
    BatchRecord,
    $$BatchesTableFilterComposer,
    $$BatchesTableOrderingComposer,
    $$BatchesTableAnnotationComposer,
    $$BatchesTableCreateCompanionBuilder,
    $$BatchesTableUpdateCompanionBuilder,
    (BatchRecord, $$BatchesTableReferences),
    BatchRecord,
    PrefetchHooks Function(
        {bool productId, bool orderItemsRefs, bool stockMovementsRefs})>;
typedef $$OrdersTableCreateCompanionBuilder = OrdersCompanion Function({
  Value<int> id,
  required String waybillNo,
  required String merchantName,
  required DateTime orderDate,
  Value<OrderStatus> status,
  Value<String?> remark,
  Value<DateTime> createdAt,
  Value<DateTime?> updatedAt,
});
typedef $$OrdersTableUpdateCompanionBuilder = OrdersCompanion Function({
  Value<int> id,
  Value<String> waybillNo,
  Value<String> merchantName,
  Value<DateTime> orderDate,
  Value<OrderStatus> status,
  Value<String?> remark,
  Value<DateTime> createdAt,
  Value<DateTime?> updatedAt,
});

final class $$OrdersTableReferences
    extends BaseReferences<_$AppDatabase, $OrdersTable, Order> {
  $$OrdersTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$OrderItemsTable, List<OrderItem>>
      _orderItemsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
          db.orderItems,
          aliasName: $_aliasNameGenerator(db.orders.id, db.orderItems.orderId));

  $$OrderItemsTableProcessedTableManager get orderItemsRefs {
    final manager = $$OrderItemsTableTableManager($_db, $_db.orderItems)
        .filter((f) => f.orderId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_orderItemsRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<$StockMovementsTable, List<StockMovement>>
      _stockMovementsRefsTable(_$AppDatabase db) =>
          MultiTypedResultKey.fromTable(db.stockMovements,
              aliasName: $_aliasNameGenerator(
                  db.orders.id, db.stockMovements.orderId));

  $$StockMovementsTableProcessedTableManager get stockMovementsRefs {
    final manager = $$StockMovementsTableTableManager($_db, $_db.stockMovements)
        .filter((f) => f.orderId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_stockMovementsRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$OrdersTableFilterComposer
    extends Composer<_$AppDatabase, $OrdersTable> {
  $$OrdersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get waybillNo => $composableBuilder(
      column: $table.waybillNo, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get merchantName => $composableBuilder(
      column: $table.merchantName, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get orderDate => $composableBuilder(
      column: $table.orderDate, builder: (column) => ColumnFilters(column));

  ColumnWithTypeConverterFilters<OrderStatus, OrderStatus, int> get status =>
      $composableBuilder(
          column: $table.status,
          builder: (column) => ColumnWithTypeConverterFilters(column));

  ColumnFilters<String> get remark => $composableBuilder(
      column: $table.remark, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  Expression<bool> orderItemsRefs(
      Expression<bool> Function($$OrderItemsTableFilterComposer f) f) {
    final $$OrderItemsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.orderItems,
        getReferencedColumn: (t) => t.orderId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$OrderItemsTableFilterComposer(
              $db: $db,
              $table: $db.orderItems,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<bool> stockMovementsRefs(
      Expression<bool> Function($$StockMovementsTableFilterComposer f) f) {
    final $$StockMovementsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.stockMovements,
        getReferencedColumn: (t) => t.orderId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$StockMovementsTableFilterComposer(
              $db: $db,
              $table: $db.stockMovements,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$OrdersTableOrderingComposer
    extends Composer<_$AppDatabase, $OrdersTable> {
  $$OrdersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get waybillNo => $composableBuilder(
      column: $table.waybillNo, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get merchantName => $composableBuilder(
      column: $table.merchantName,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get orderDate => $composableBuilder(
      column: $table.orderDate, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get remark => $composableBuilder(
      column: $table.remark, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$OrdersTableAnnotationComposer
    extends Composer<_$AppDatabase, $OrdersTable> {
  $$OrdersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get waybillNo =>
      $composableBuilder(column: $table.waybillNo, builder: (column) => column);

  GeneratedColumn<String> get merchantName => $composableBuilder(
      column: $table.merchantName, builder: (column) => column);

  GeneratedColumn<DateTime> get orderDate =>
      $composableBuilder(column: $table.orderDate, builder: (column) => column);

  GeneratedColumnWithTypeConverter<OrderStatus, int> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get remark =>
      $composableBuilder(column: $table.remark, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> orderItemsRefs<T extends Object>(
      Expression<T> Function($$OrderItemsTableAnnotationComposer a) f) {
    final $$OrderItemsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.orderItems,
        getReferencedColumn: (t) => t.orderId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$OrderItemsTableAnnotationComposer(
              $db: $db,
              $table: $db.orderItems,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<T> stockMovementsRefs<T extends Object>(
      Expression<T> Function($$StockMovementsTableAnnotationComposer a) f) {
    final $$StockMovementsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.stockMovements,
        getReferencedColumn: (t) => t.orderId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$StockMovementsTableAnnotationComposer(
              $db: $db,
              $table: $db.stockMovements,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$OrdersTableTableManager extends RootTableManager<
    _$AppDatabase,
    $OrdersTable,
    Order,
    $$OrdersTableFilterComposer,
    $$OrdersTableOrderingComposer,
    $$OrdersTableAnnotationComposer,
    $$OrdersTableCreateCompanionBuilder,
    $$OrdersTableUpdateCompanionBuilder,
    (Order, $$OrdersTableReferences),
    Order,
    PrefetchHooks Function({bool orderItemsRefs, bool stockMovementsRefs})> {
  $$OrdersTableTableManager(_$AppDatabase db, $OrdersTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OrdersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OrdersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OrdersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> waybillNo = const Value.absent(),
            Value<String> merchantName = const Value.absent(),
            Value<DateTime> orderDate = const Value.absent(),
            Value<OrderStatus> status = const Value.absent(),
            Value<String?> remark = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime?> updatedAt = const Value.absent(),
          }) =>
              OrdersCompanion(
            id: id,
            waybillNo: waybillNo,
            merchantName: merchantName,
            orderDate: orderDate,
            status: status,
            remark: remark,
            createdAt: createdAt,
            updatedAt: updatedAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String waybillNo,
            required String merchantName,
            required DateTime orderDate,
            Value<OrderStatus> status = const Value.absent(),
            Value<String?> remark = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime?> updatedAt = const Value.absent(),
          }) =>
              OrdersCompanion.insert(
            id: id,
            waybillNo: waybillNo,
            merchantName: merchantName,
            orderDate: orderDate,
            status: status,
            remark: remark,
            createdAt: createdAt,
            updatedAt: updatedAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) =>
                  (e.readTable(table), $$OrdersTableReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: (
              {orderItemsRefs = false, stockMovementsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (orderItemsRefs) db.orderItems,
                if (stockMovementsRefs) db.stockMovements
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (orderItemsRefs)
                    await $_getPrefetchedData<Order, $OrdersTable, OrderItem>(
                        currentTable: table,
                        referencedTable:
                            $$OrdersTableReferences._orderItemsRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$OrdersTableReferences(db, table, p0)
                                .orderItemsRefs,
                        referencedItemsForCurrentItem: (item,
                                referencedItems) =>
                            referencedItems.where((e) => e.orderId == item.id),
                        typedResults: items),
                  if (stockMovementsRefs)
                    await $_getPrefetchedData<Order, $OrdersTable,
                            StockMovement>(
                        currentTable: table,
                        referencedTable: $$OrdersTableReferences
                            ._stockMovementsRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$OrdersTableReferences(db, table, p0)
                                .stockMovementsRefs,
                        referencedItemsForCurrentItem: (item,
                                referencedItems) =>
                            referencedItems.where((e) => e.orderId == item.id),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$OrdersTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $OrdersTable,
    Order,
    $$OrdersTableFilterComposer,
    $$OrdersTableOrderingComposer,
    $$OrdersTableAnnotationComposer,
    $$OrdersTableCreateCompanionBuilder,
    $$OrdersTableUpdateCompanionBuilder,
    (Order, $$OrdersTableReferences),
    Order,
    PrefetchHooks Function({bool orderItemsRefs, bool stockMovementsRefs})>;
typedef $$OrderItemsTableCreateCompanionBuilder = OrderItemsCompanion Function({
  Value<int> id,
  required int orderId,
  required int productId,
  required int batchId,
  required int boxes,
  required int boxesPerBoard,
  required int piecesPerBox,
  Value<DateTime> createdAt,
});
typedef $$OrderItemsTableUpdateCompanionBuilder = OrderItemsCompanion Function({
  Value<int> id,
  Value<int> orderId,
  Value<int> productId,
  Value<int> batchId,
  Value<int> boxes,
  Value<int> boxesPerBoard,
  Value<int> piecesPerBox,
  Value<DateTime> createdAt,
});

final class $$OrderItemsTableReferences
    extends BaseReferences<_$AppDatabase, $OrderItemsTable, OrderItem> {
  $$OrderItemsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $OrdersTable _orderIdTable(_$AppDatabase db) => db.orders
      .createAlias($_aliasNameGenerator(db.orderItems.orderId, db.orders.id));

  $$OrdersTableProcessedTableManager get orderId {
    final $_column = $_itemColumn<int>('order_id')!;

    final manager = $$OrdersTableTableManager($_db, $_db.orders)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_orderIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }

  static $ProductsTable _productIdTable(_$AppDatabase db) =>
      db.products.createAlias(
          $_aliasNameGenerator(db.orderItems.productId, db.products.id));

  $$ProductsTableProcessedTableManager get productId {
    final $_column = $_itemColumn<int>('product_id')!;

    final manager = $$ProductsTableTableManager($_db, $_db.products)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_productIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }

  static $BatchesTable _batchIdTable(_$AppDatabase db) => db.batches
      .createAlias($_aliasNameGenerator(db.orderItems.batchId, db.batches.id));

  $$BatchesTableProcessedTableManager get batchId {
    final $_column = $_itemColumn<int>('batch_id')!;

    final manager = $$BatchesTableTableManager($_db, $_db.batches)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_batchIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$OrderItemsTableFilterComposer
    extends Composer<_$AppDatabase, $OrderItemsTable> {
  $$OrderItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get boxes => $composableBuilder(
      column: $table.boxes, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get boxesPerBoard => $composableBuilder(
      column: $table.boxesPerBoard, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get piecesPerBox => $composableBuilder(
      column: $table.piecesPerBox, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  $$OrdersTableFilterComposer get orderId {
    final $$OrdersTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.orderId,
        referencedTable: $db.orders,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$OrdersTableFilterComposer(
              $db: $db,
              $table: $db.orders,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$ProductsTableFilterComposer get productId {
    final $$ProductsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.productId,
        referencedTable: $db.products,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ProductsTableFilterComposer(
              $db: $db,
              $table: $db.products,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$BatchesTableFilterComposer get batchId {
    final $$BatchesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.batchId,
        referencedTable: $db.batches,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$BatchesTableFilterComposer(
              $db: $db,
              $table: $db.batches,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$OrderItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $OrderItemsTable> {
  $$OrderItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get boxes => $composableBuilder(
      column: $table.boxes, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get boxesPerBoard => $composableBuilder(
      column: $table.boxesPerBoard,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get piecesPerBox => $composableBuilder(
      column: $table.piecesPerBox,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  $$OrdersTableOrderingComposer get orderId {
    final $$OrdersTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.orderId,
        referencedTable: $db.orders,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$OrdersTableOrderingComposer(
              $db: $db,
              $table: $db.orders,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$ProductsTableOrderingComposer get productId {
    final $$ProductsTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.productId,
        referencedTable: $db.products,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ProductsTableOrderingComposer(
              $db: $db,
              $table: $db.products,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$BatchesTableOrderingComposer get batchId {
    final $$BatchesTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.batchId,
        referencedTable: $db.batches,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$BatchesTableOrderingComposer(
              $db: $db,
              $table: $db.batches,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$OrderItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $OrderItemsTable> {
  $$OrderItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get boxes =>
      $composableBuilder(column: $table.boxes, builder: (column) => column);

  GeneratedColumn<int> get boxesPerBoard => $composableBuilder(
      column: $table.boxesPerBoard, builder: (column) => column);

  GeneratedColumn<int> get piecesPerBox => $composableBuilder(
      column: $table.piecesPerBox, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$OrdersTableAnnotationComposer get orderId {
    final $$OrdersTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.orderId,
        referencedTable: $db.orders,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$OrdersTableAnnotationComposer(
              $db: $db,
              $table: $db.orders,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$ProductsTableAnnotationComposer get productId {
    final $$ProductsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.productId,
        referencedTable: $db.products,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ProductsTableAnnotationComposer(
              $db: $db,
              $table: $db.products,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$BatchesTableAnnotationComposer get batchId {
    final $$BatchesTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.batchId,
        referencedTable: $db.batches,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$BatchesTableAnnotationComposer(
              $db: $db,
              $table: $db.batches,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$OrderItemsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $OrderItemsTable,
    OrderItem,
    $$OrderItemsTableFilterComposer,
    $$OrderItemsTableOrderingComposer,
    $$OrderItemsTableAnnotationComposer,
    $$OrderItemsTableCreateCompanionBuilder,
    $$OrderItemsTableUpdateCompanionBuilder,
    (OrderItem, $$OrderItemsTableReferences),
    OrderItem,
    PrefetchHooks Function({bool orderId, bool productId, bool batchId})> {
  $$OrderItemsTableTableManager(_$AppDatabase db, $OrderItemsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OrderItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OrderItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OrderItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int> orderId = const Value.absent(),
            Value<int> productId = const Value.absent(),
            Value<int> batchId = const Value.absent(),
            Value<int> boxes = const Value.absent(),
            Value<int> boxesPerBoard = const Value.absent(),
            Value<int> piecesPerBox = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
          }) =>
              OrderItemsCompanion(
            id: id,
            orderId: orderId,
            productId: productId,
            batchId: batchId,
            boxes: boxes,
            boxesPerBoard: boxesPerBoard,
            piecesPerBox: piecesPerBox,
            createdAt: createdAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required int orderId,
            required int productId,
            required int batchId,
            required int boxes,
            required int boxesPerBoard,
            required int piecesPerBox,
            Value<DateTime> createdAt = const Value.absent(),
          }) =>
              OrderItemsCompanion.insert(
            id: id,
            orderId: orderId,
            productId: productId,
            batchId: batchId,
            boxes: boxes,
            boxesPerBoard: boxesPerBoard,
            piecesPerBox: piecesPerBox,
            createdAt: createdAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$OrderItemsTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: (
              {orderId = false, productId = false, batchId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (orderId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.orderId,
                    referencedTable:
                        $$OrderItemsTableReferences._orderIdTable(db),
                    referencedColumn:
                        $$OrderItemsTableReferences._orderIdTable(db).id,
                  ) as T;
                }
                if (productId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.productId,
                    referencedTable:
                        $$OrderItemsTableReferences._productIdTable(db),
                    referencedColumn:
                        $$OrderItemsTableReferences._productIdTable(db).id,
                  ) as T;
                }
                if (batchId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.batchId,
                    referencedTable:
                        $$OrderItemsTableReferences._batchIdTable(db),
                    referencedColumn:
                        $$OrderItemsTableReferences._batchIdTable(db).id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$OrderItemsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $OrderItemsTable,
    OrderItem,
    $$OrderItemsTableFilterComposer,
    $$OrderItemsTableOrderingComposer,
    $$OrderItemsTableAnnotationComposer,
    $$OrderItemsTableCreateCompanionBuilder,
    $$OrderItemsTableUpdateCompanionBuilder,
    (OrderItem, $$OrderItemsTableReferences),
    OrderItem,
    PrefetchHooks Function({bool orderId, bool productId, bool batchId})>;
typedef $$StockMovementsTableCreateCompanionBuilder = StockMovementsCompanion
    Function({
  Value<int> id,
  required int batchId,
  Value<int?> orderId,
  required DateTime movementDate,
  required StockMovementType type,
  required int boxes,
  Value<String?> remark,
  Value<DateTime> createdAt,
});
typedef $$StockMovementsTableUpdateCompanionBuilder = StockMovementsCompanion
    Function({
  Value<int> id,
  Value<int> batchId,
  Value<int?> orderId,
  Value<DateTime> movementDate,
  Value<StockMovementType> type,
  Value<int> boxes,
  Value<String?> remark,
  Value<DateTime> createdAt,
});

final class $$StockMovementsTableReferences
    extends BaseReferences<_$AppDatabase, $StockMovementsTable, StockMovement> {
  $$StockMovementsTableReferences(
      super.$_db, super.$_table, super.$_typedResult);

  static $BatchesTable _batchIdTable(_$AppDatabase db) =>
      db.batches.createAlias(
          $_aliasNameGenerator(db.stockMovements.batchId, db.batches.id));

  $$BatchesTableProcessedTableManager get batchId {
    final $_column = $_itemColumn<int>('batch_id')!;

    final manager = $$BatchesTableTableManager($_db, $_db.batches)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_batchIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }

  static $OrdersTable _orderIdTable(_$AppDatabase db) => db.orders.createAlias(
      $_aliasNameGenerator(db.stockMovements.orderId, db.orders.id));

  $$OrdersTableProcessedTableManager? get orderId {
    final $_column = $_itemColumn<int>('order_id');
    if ($_column == null) return null;
    final manager = $$OrdersTableTableManager($_db, $_db.orders)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_orderIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$StockMovementsTableFilterComposer
    extends Composer<_$AppDatabase, $StockMovementsTable> {
  $$StockMovementsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get movementDate => $composableBuilder(
      column: $table.movementDate, builder: (column) => ColumnFilters(column));

  ColumnWithTypeConverterFilters<StockMovementType, StockMovementType, int>
      get type => $composableBuilder(
          column: $table.type,
          builder: (column) => ColumnWithTypeConverterFilters(column));

  ColumnFilters<int> get boxes => $composableBuilder(
      column: $table.boxes, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get remark => $composableBuilder(
      column: $table.remark, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  $$BatchesTableFilterComposer get batchId {
    final $$BatchesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.batchId,
        referencedTable: $db.batches,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$BatchesTableFilterComposer(
              $db: $db,
              $table: $db.batches,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$OrdersTableFilterComposer get orderId {
    final $$OrdersTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.orderId,
        referencedTable: $db.orders,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$OrdersTableFilterComposer(
              $db: $db,
              $table: $db.orders,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$StockMovementsTableOrderingComposer
    extends Composer<_$AppDatabase, $StockMovementsTable> {
  $$StockMovementsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get movementDate => $composableBuilder(
      column: $table.movementDate,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get boxes => $composableBuilder(
      column: $table.boxes, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get remark => $composableBuilder(
      column: $table.remark, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  $$BatchesTableOrderingComposer get batchId {
    final $$BatchesTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.batchId,
        referencedTable: $db.batches,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$BatchesTableOrderingComposer(
              $db: $db,
              $table: $db.batches,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$OrdersTableOrderingComposer get orderId {
    final $$OrdersTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.orderId,
        referencedTable: $db.orders,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$OrdersTableOrderingComposer(
              $db: $db,
              $table: $db.orders,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$StockMovementsTableAnnotationComposer
    extends Composer<_$AppDatabase, $StockMovementsTable> {
  $$StockMovementsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get movementDate => $composableBuilder(
      column: $table.movementDate, builder: (column) => column);

  GeneratedColumnWithTypeConverter<StockMovementType, int> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<int> get boxes =>
      $composableBuilder(column: $table.boxes, builder: (column) => column);

  GeneratedColumn<String> get remark =>
      $composableBuilder(column: $table.remark, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$BatchesTableAnnotationComposer get batchId {
    final $$BatchesTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.batchId,
        referencedTable: $db.batches,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$BatchesTableAnnotationComposer(
              $db: $db,
              $table: $db.batches,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$OrdersTableAnnotationComposer get orderId {
    final $$OrdersTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.orderId,
        referencedTable: $db.orders,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$OrdersTableAnnotationComposer(
              $db: $db,
              $table: $db.orders,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$StockMovementsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $StockMovementsTable,
    StockMovement,
    $$StockMovementsTableFilterComposer,
    $$StockMovementsTableOrderingComposer,
    $$StockMovementsTableAnnotationComposer,
    $$StockMovementsTableCreateCompanionBuilder,
    $$StockMovementsTableUpdateCompanionBuilder,
    (StockMovement, $$StockMovementsTableReferences),
    StockMovement,
    PrefetchHooks Function({bool batchId, bool orderId})> {
  $$StockMovementsTableTableManager(
      _$AppDatabase db, $StockMovementsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$StockMovementsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$StockMovementsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$StockMovementsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int> batchId = const Value.absent(),
            Value<int?> orderId = const Value.absent(),
            Value<DateTime> movementDate = const Value.absent(),
            Value<StockMovementType> type = const Value.absent(),
            Value<int> boxes = const Value.absent(),
            Value<String?> remark = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
          }) =>
              StockMovementsCompanion(
            id: id,
            batchId: batchId,
            orderId: orderId,
            movementDate: movementDate,
            type: type,
            boxes: boxes,
            remark: remark,
            createdAt: createdAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required int batchId,
            Value<int?> orderId = const Value.absent(),
            required DateTime movementDate,
            required StockMovementType type,
            required int boxes,
            Value<String?> remark = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
          }) =>
              StockMovementsCompanion.insert(
            id: id,
            batchId: batchId,
            orderId: orderId,
            movementDate: movementDate,
            type: type,
            boxes: boxes,
            remark: remark,
            createdAt: createdAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$StockMovementsTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({batchId = false, orderId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (batchId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.batchId,
                    referencedTable:
                        $$StockMovementsTableReferences._batchIdTable(db),
                    referencedColumn:
                        $$StockMovementsTableReferences._batchIdTable(db).id,
                  ) as T;
                }
                if (orderId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.orderId,
                    referencedTable:
                        $$StockMovementsTableReferences._orderIdTable(db),
                    referencedColumn:
                        $$StockMovementsTableReferences._orderIdTable(db).id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$StockMovementsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $StockMovementsTable,
    StockMovement,
    $$StockMovementsTableFilterComposer,
    $$StockMovementsTableOrderingComposer,
    $$StockMovementsTableAnnotationComposer,
    $$StockMovementsTableCreateCompanionBuilder,
    $$StockMovementsTableUpdateCompanionBuilder,
    (StockMovement, $$StockMovementsTableReferences),
    StockMovement,
    PrefetchHooks Function({bool batchId, bool orderId})>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$ProductsTableTableManager get products =>
      $$ProductsTableTableManager(_db, _db.products);
  $$BatchesTableTableManager get batches =>
      $$BatchesTableTableManager(_db, _db.batches);
  $$OrdersTableTableManager get orders =>
      $$OrdersTableTableManager(_db, _db.orders);
  $$OrderItemsTableTableManager get orderItems =>
      $$OrderItemsTableTableManager(_db, _db.orderItems);
  $$StockMovementsTableTableManager get stockMovements =>
      $$StockMovementsTableTableManager(_db, _db.stockMovements);
}
