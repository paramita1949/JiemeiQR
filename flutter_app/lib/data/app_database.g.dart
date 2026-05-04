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
  static const VerificationMeta _isExceptionMeta =
      const VerificationMeta('isException');
  @override
  late final GeneratedColumn<bool> isException = GeneratedColumn<bool>(
      'is_exception', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("is_exception" IN (0, 1))'),
      defaultValue: const Constant(false));
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
        isException,
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
    if (data.containsKey('is_exception')) {
      context.handle(
          _isExceptionMeta,
          isException.isAcceptableOrUnknown(
              data['is_exception']!, _isExceptionMeta));
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
      isException: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_exception'])!,
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
  final bool isException;
  final DateTime createdAt;
  const OrderItem(
      {required this.id,
      required this.orderId,
      required this.productId,
      required this.batchId,
      required this.boxes,
      required this.boxesPerBoard,
      required this.piecesPerBox,
      required this.isException,
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
    map['is_exception'] = Variable<bool>(isException);
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
      isException: Value(isException),
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
      isException: serializer.fromJson<bool>(json['isException']),
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
      'isException': serializer.toJson<bool>(isException),
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
          bool? isException,
          DateTime? createdAt}) =>
      OrderItem(
        id: id ?? this.id,
        orderId: orderId ?? this.orderId,
        productId: productId ?? this.productId,
        batchId: batchId ?? this.batchId,
        boxes: boxes ?? this.boxes,
        boxesPerBoard: boxesPerBoard ?? this.boxesPerBoard,
        piecesPerBox: piecesPerBox ?? this.piecesPerBox,
        isException: isException ?? this.isException,
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
      isException:
          data.isException.present ? data.isException.value : this.isException,
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
          ..write('isException: $isException, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, orderId, productId, batchId, boxes,
      boxesPerBoard, piecesPerBox, isException, createdAt);
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
          other.isException == this.isException &&
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
  final Value<bool> isException;
  final Value<DateTime> createdAt;
  const OrderItemsCompanion({
    this.id = const Value.absent(),
    this.orderId = const Value.absent(),
    this.productId = const Value.absent(),
    this.batchId = const Value.absent(),
    this.boxes = const Value.absent(),
    this.boxesPerBoard = const Value.absent(),
    this.piecesPerBox = const Value.absent(),
    this.isException = const Value.absent(),
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
    this.isException = const Value.absent(),
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
    Expression<bool>? isException,
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
      if (isException != null) 'is_exception': isException,
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
      Value<bool>? isException,
      Value<DateTime>? createdAt}) {
    return OrderItemsCompanion(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      productId: productId ?? this.productId,
      batchId: batchId ?? this.batchId,
      boxes: boxes ?? this.boxes,
      boxesPerBoard: boxesPerBoard ?? this.boxesPerBoard,
      piecesPerBox: piecesPerBox ?? this.piecesPerBox,
      isException: isException ?? this.isException,
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
    if (isException.present) {
      map['is_exception'] = Variable<bool>(isException.value);
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
          ..write('isException: $isException, ')
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

class $AttendanceRulesTable extends AttendanceRules
    with TableInfo<$AttendanceRulesTable, AttendanceRule> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AttendanceRulesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _workStartTimeMeta =
      const VerificationMeta('workStartTime');
  @override
  late final GeneratedColumn<String> workStartTime = GeneratedColumn<String>(
      'work_start_time', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('08:00'));
  static const VerificationMeta _workEndTimeMeta =
      const VerificationMeta('workEndTime');
  @override
  late final GeneratedColumn<String> workEndTime = GeneratedColumn<String>(
      'work_end_time', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('17:00'));
  static const VerificationMeta _lateGraceMinutesMeta =
      const VerificationMeta('lateGraceMinutes');
  @override
  late final GeneratedColumn<int> lateGraceMinutes = GeneratedColumn<int>(
      'late_grace_minutes', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _weekendTypeMeta =
      const VerificationMeta('weekendType');
  @override
  late final GeneratedColumn<String> weekendType = GeneratedColumn<String>(
      'weekend_type', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('double'));
  static const VerificationMeta _overtimeRoundingMinutesMeta =
      const VerificationMeta('overtimeRoundingMinutes');
  @override
  late final GeneratedColumn<int> overtimeRoundingMinutes =
      GeneratedColumn<int>('overtime_rounding_minutes', aliasedName, false,
          type: DriftSqlType.int,
          requiredDuringInsert: false,
          defaultValue: const Constant(30));
  static const VerificationMeta _officeLatMeta =
      const VerificationMeta('officeLat');
  @override
  late final GeneratedColumn<double> officeLat = GeneratedColumn<double>(
      'office_lat', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _officeLngMeta =
      const VerificationMeta('officeLng');
  @override
  late final GeneratedColumn<double> officeLng = GeneratedColumn<double>(
      'office_lng', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _officeRadiusMetersMeta =
      const VerificationMeta('officeRadiusMeters');
  @override
  late final GeneratedColumn<int> officeRadiusMeters = GeneratedColumn<int>(
      'office_radius_meters', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(300));
  static const VerificationMeta _geofenceEnabledMeta =
      const VerificationMeta('geofenceEnabled');
  @override
  late final GeneratedColumn<bool> geofenceEnabled = GeneratedColumn<bool>(
      'geofence_enabled', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("geofence_enabled" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _checkinReminderEnabledMeta =
      const VerificationMeta('checkinReminderEnabled');
  @override
  late final GeneratedColumn<bool> checkinReminderEnabled =
      GeneratedColumn<bool>('checkin_reminder_enabled', aliasedName, false,
          type: DriftSqlType.bool,
          requiredDuringInsert: false,
          defaultConstraints: GeneratedColumn.constraintIsAlways(
              'CHECK ("checkin_reminder_enabled" IN (0, 1))'),
          defaultValue: const Constant(true));
  static const VerificationMeta _checkoutReminderEnabledMeta =
      const VerificationMeta('checkoutReminderEnabled');
  @override
  late final GeneratedColumn<bool> checkoutReminderEnabled =
      GeneratedColumn<bool>('checkout_reminder_enabled', aliasedName, false,
          type: DriftSqlType.bool,
          requiredDuringInsert: false,
          defaultConstraints: GeneratedColumn.constraintIsAlways(
              'CHECK ("checkout_reminder_enabled" IN (0, 1))'),
          defaultValue: const Constant(false));
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        workStartTime,
        workEndTime,
        lateGraceMinutes,
        weekendType,
        overtimeRoundingMinutes,
        officeLat,
        officeLng,
        officeRadiusMeters,
        geofenceEnabled,
        checkinReminderEnabled,
        checkoutReminderEnabled,
        updatedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'attendance_rules';
  @override
  VerificationContext validateIntegrity(Insertable<AttendanceRule> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('work_start_time')) {
      context.handle(
          _workStartTimeMeta,
          workStartTime.isAcceptableOrUnknown(
              data['work_start_time']!, _workStartTimeMeta));
    }
    if (data.containsKey('work_end_time')) {
      context.handle(
          _workEndTimeMeta,
          workEndTime.isAcceptableOrUnknown(
              data['work_end_time']!, _workEndTimeMeta));
    }
    if (data.containsKey('late_grace_minutes')) {
      context.handle(
          _lateGraceMinutesMeta,
          lateGraceMinutes.isAcceptableOrUnknown(
              data['late_grace_minutes']!, _lateGraceMinutesMeta));
    }
    if (data.containsKey('weekend_type')) {
      context.handle(
          _weekendTypeMeta,
          weekendType.isAcceptableOrUnknown(
              data['weekend_type']!, _weekendTypeMeta));
    }
    if (data.containsKey('overtime_rounding_minutes')) {
      context.handle(
          _overtimeRoundingMinutesMeta,
          overtimeRoundingMinutes.isAcceptableOrUnknown(
              data['overtime_rounding_minutes']!,
              _overtimeRoundingMinutesMeta));
    }
    if (data.containsKey('office_lat')) {
      context.handle(_officeLatMeta,
          officeLat.isAcceptableOrUnknown(data['office_lat']!, _officeLatMeta));
    }
    if (data.containsKey('office_lng')) {
      context.handle(_officeLngMeta,
          officeLng.isAcceptableOrUnknown(data['office_lng']!, _officeLngMeta));
    }
    if (data.containsKey('office_radius_meters')) {
      context.handle(
          _officeRadiusMetersMeta,
          officeRadiusMeters.isAcceptableOrUnknown(
              data['office_radius_meters']!, _officeRadiusMetersMeta));
    }
    if (data.containsKey('geofence_enabled')) {
      context.handle(
          _geofenceEnabledMeta,
          geofenceEnabled.isAcceptableOrUnknown(
              data['geofence_enabled']!, _geofenceEnabledMeta));
    }
    if (data.containsKey('checkin_reminder_enabled')) {
      context.handle(
          _checkinReminderEnabledMeta,
          checkinReminderEnabled.isAcceptableOrUnknown(
              data['checkin_reminder_enabled']!, _checkinReminderEnabledMeta));
    }
    if (data.containsKey('checkout_reminder_enabled')) {
      context.handle(
          _checkoutReminderEnabledMeta,
          checkoutReminderEnabled.isAcceptableOrUnknown(
              data['checkout_reminder_enabled']!,
              _checkoutReminderEnabledMeta));
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
  AttendanceRule map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AttendanceRule(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      workStartTime: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}work_start_time'])!,
      workEndTime: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}work_end_time'])!,
      lateGraceMinutes: attachedDatabase.typeMapping.read(
          DriftSqlType.int, data['${effectivePrefix}late_grace_minutes'])!,
      weekendType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}weekend_type'])!,
      overtimeRoundingMinutes: attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}overtime_rounding_minutes'])!,
      officeLat: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}office_lat']),
      officeLng: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}office_lng']),
      officeRadiusMeters: attachedDatabase.typeMapping.read(
          DriftSqlType.int, data['${effectivePrefix}office_radius_meters'])!,
      geofenceEnabled: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}geofence_enabled'])!,
      checkinReminderEnabled: attachedDatabase.typeMapping.read(
          DriftSqlType.bool,
          data['${effectivePrefix}checkin_reminder_enabled'])!,
      checkoutReminderEnabled: attachedDatabase.typeMapping.read(
          DriftSqlType.bool,
          data['${effectivePrefix}checkout_reminder_enabled'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $AttendanceRulesTable createAlias(String alias) {
    return $AttendanceRulesTable(attachedDatabase, alias);
  }
}

class AttendanceRule extends DataClass implements Insertable<AttendanceRule> {
  final int id;
  final String workStartTime;
  final String workEndTime;
  final int lateGraceMinutes;
  final String weekendType;
  final int overtimeRoundingMinutes;
  final double? officeLat;
  final double? officeLng;
  final int officeRadiusMeters;
  final bool geofenceEnabled;
  final bool checkinReminderEnabled;
  final bool checkoutReminderEnabled;
  final DateTime updatedAt;
  const AttendanceRule(
      {required this.id,
      required this.workStartTime,
      required this.workEndTime,
      required this.lateGraceMinutes,
      required this.weekendType,
      required this.overtimeRoundingMinutes,
      this.officeLat,
      this.officeLng,
      required this.officeRadiusMeters,
      required this.geofenceEnabled,
      required this.checkinReminderEnabled,
      required this.checkoutReminderEnabled,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['work_start_time'] = Variable<String>(workStartTime);
    map['work_end_time'] = Variable<String>(workEndTime);
    map['late_grace_minutes'] = Variable<int>(lateGraceMinutes);
    map['weekend_type'] = Variable<String>(weekendType);
    map['overtime_rounding_minutes'] = Variable<int>(overtimeRoundingMinutes);
    if (!nullToAbsent || officeLat != null) {
      map['office_lat'] = Variable<double>(officeLat);
    }
    if (!nullToAbsent || officeLng != null) {
      map['office_lng'] = Variable<double>(officeLng);
    }
    map['office_radius_meters'] = Variable<int>(officeRadiusMeters);
    map['geofence_enabled'] = Variable<bool>(geofenceEnabled);
    map['checkin_reminder_enabled'] = Variable<bool>(checkinReminderEnabled);
    map['checkout_reminder_enabled'] = Variable<bool>(checkoutReminderEnabled);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  AttendanceRulesCompanion toCompanion(bool nullToAbsent) {
    return AttendanceRulesCompanion(
      id: Value(id),
      workStartTime: Value(workStartTime),
      workEndTime: Value(workEndTime),
      lateGraceMinutes: Value(lateGraceMinutes),
      weekendType: Value(weekendType),
      overtimeRoundingMinutes: Value(overtimeRoundingMinutes),
      officeLat: officeLat == null && nullToAbsent
          ? const Value.absent()
          : Value(officeLat),
      officeLng: officeLng == null && nullToAbsent
          ? const Value.absent()
          : Value(officeLng),
      officeRadiusMeters: Value(officeRadiusMeters),
      geofenceEnabled: Value(geofenceEnabled),
      checkinReminderEnabled: Value(checkinReminderEnabled),
      checkoutReminderEnabled: Value(checkoutReminderEnabled),
      updatedAt: Value(updatedAt),
    );
  }

  factory AttendanceRule.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AttendanceRule(
      id: serializer.fromJson<int>(json['id']),
      workStartTime: serializer.fromJson<String>(json['workStartTime']),
      workEndTime: serializer.fromJson<String>(json['workEndTime']),
      lateGraceMinutes: serializer.fromJson<int>(json['lateGraceMinutes']),
      weekendType: serializer.fromJson<String>(json['weekendType']),
      overtimeRoundingMinutes:
          serializer.fromJson<int>(json['overtimeRoundingMinutes']),
      officeLat: serializer.fromJson<double?>(json['officeLat']),
      officeLng: serializer.fromJson<double?>(json['officeLng']),
      officeRadiusMeters: serializer.fromJson<int>(json['officeRadiusMeters']),
      geofenceEnabled: serializer.fromJson<bool>(json['geofenceEnabled']),
      checkinReminderEnabled:
          serializer.fromJson<bool>(json['checkinReminderEnabled']),
      checkoutReminderEnabled:
          serializer.fromJson<bool>(json['checkoutReminderEnabled']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'workStartTime': serializer.toJson<String>(workStartTime),
      'workEndTime': serializer.toJson<String>(workEndTime),
      'lateGraceMinutes': serializer.toJson<int>(lateGraceMinutes),
      'weekendType': serializer.toJson<String>(weekendType),
      'overtimeRoundingMinutes':
          serializer.toJson<int>(overtimeRoundingMinutes),
      'officeLat': serializer.toJson<double?>(officeLat),
      'officeLng': serializer.toJson<double?>(officeLng),
      'officeRadiusMeters': serializer.toJson<int>(officeRadiusMeters),
      'geofenceEnabled': serializer.toJson<bool>(geofenceEnabled),
      'checkinReminderEnabled': serializer.toJson<bool>(checkinReminderEnabled),
      'checkoutReminderEnabled':
          serializer.toJson<bool>(checkoutReminderEnabled),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  AttendanceRule copyWith(
          {int? id,
          String? workStartTime,
          String? workEndTime,
          int? lateGraceMinutes,
          String? weekendType,
          int? overtimeRoundingMinutes,
          Value<double?> officeLat = const Value.absent(),
          Value<double?> officeLng = const Value.absent(),
          int? officeRadiusMeters,
          bool? geofenceEnabled,
          bool? checkinReminderEnabled,
          bool? checkoutReminderEnabled,
          DateTime? updatedAt}) =>
      AttendanceRule(
        id: id ?? this.id,
        workStartTime: workStartTime ?? this.workStartTime,
        workEndTime: workEndTime ?? this.workEndTime,
        lateGraceMinutes: lateGraceMinutes ?? this.lateGraceMinutes,
        weekendType: weekendType ?? this.weekendType,
        overtimeRoundingMinutes:
            overtimeRoundingMinutes ?? this.overtimeRoundingMinutes,
        officeLat: officeLat.present ? officeLat.value : this.officeLat,
        officeLng: officeLng.present ? officeLng.value : this.officeLng,
        officeRadiusMeters: officeRadiusMeters ?? this.officeRadiusMeters,
        geofenceEnabled: geofenceEnabled ?? this.geofenceEnabled,
        checkinReminderEnabled:
            checkinReminderEnabled ?? this.checkinReminderEnabled,
        checkoutReminderEnabled:
            checkoutReminderEnabled ?? this.checkoutReminderEnabled,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  AttendanceRule copyWithCompanion(AttendanceRulesCompanion data) {
    return AttendanceRule(
      id: data.id.present ? data.id.value : this.id,
      workStartTime: data.workStartTime.present
          ? data.workStartTime.value
          : this.workStartTime,
      workEndTime:
          data.workEndTime.present ? data.workEndTime.value : this.workEndTime,
      lateGraceMinutes: data.lateGraceMinutes.present
          ? data.lateGraceMinutes.value
          : this.lateGraceMinutes,
      weekendType:
          data.weekendType.present ? data.weekendType.value : this.weekendType,
      overtimeRoundingMinutes: data.overtimeRoundingMinutes.present
          ? data.overtimeRoundingMinutes.value
          : this.overtimeRoundingMinutes,
      officeLat: data.officeLat.present ? data.officeLat.value : this.officeLat,
      officeLng: data.officeLng.present ? data.officeLng.value : this.officeLng,
      officeRadiusMeters: data.officeRadiusMeters.present
          ? data.officeRadiusMeters.value
          : this.officeRadiusMeters,
      geofenceEnabled: data.geofenceEnabled.present
          ? data.geofenceEnabled.value
          : this.geofenceEnabled,
      checkinReminderEnabled: data.checkinReminderEnabled.present
          ? data.checkinReminderEnabled.value
          : this.checkinReminderEnabled,
      checkoutReminderEnabled: data.checkoutReminderEnabled.present
          ? data.checkoutReminderEnabled.value
          : this.checkoutReminderEnabled,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AttendanceRule(')
          ..write('id: $id, ')
          ..write('workStartTime: $workStartTime, ')
          ..write('workEndTime: $workEndTime, ')
          ..write('lateGraceMinutes: $lateGraceMinutes, ')
          ..write('weekendType: $weekendType, ')
          ..write('overtimeRoundingMinutes: $overtimeRoundingMinutes, ')
          ..write('officeLat: $officeLat, ')
          ..write('officeLng: $officeLng, ')
          ..write('officeRadiusMeters: $officeRadiusMeters, ')
          ..write('geofenceEnabled: $geofenceEnabled, ')
          ..write('checkinReminderEnabled: $checkinReminderEnabled, ')
          ..write('checkoutReminderEnabled: $checkoutReminderEnabled, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      workStartTime,
      workEndTime,
      lateGraceMinutes,
      weekendType,
      overtimeRoundingMinutes,
      officeLat,
      officeLng,
      officeRadiusMeters,
      geofenceEnabled,
      checkinReminderEnabled,
      checkoutReminderEnabled,
      updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AttendanceRule &&
          other.id == this.id &&
          other.workStartTime == this.workStartTime &&
          other.workEndTime == this.workEndTime &&
          other.lateGraceMinutes == this.lateGraceMinutes &&
          other.weekendType == this.weekendType &&
          other.overtimeRoundingMinutes == this.overtimeRoundingMinutes &&
          other.officeLat == this.officeLat &&
          other.officeLng == this.officeLng &&
          other.officeRadiusMeters == this.officeRadiusMeters &&
          other.geofenceEnabled == this.geofenceEnabled &&
          other.checkinReminderEnabled == this.checkinReminderEnabled &&
          other.checkoutReminderEnabled == this.checkoutReminderEnabled &&
          other.updatedAt == this.updatedAt);
}

class AttendanceRulesCompanion extends UpdateCompanion<AttendanceRule> {
  final Value<int> id;
  final Value<String> workStartTime;
  final Value<String> workEndTime;
  final Value<int> lateGraceMinutes;
  final Value<String> weekendType;
  final Value<int> overtimeRoundingMinutes;
  final Value<double?> officeLat;
  final Value<double?> officeLng;
  final Value<int> officeRadiusMeters;
  final Value<bool> geofenceEnabled;
  final Value<bool> checkinReminderEnabled;
  final Value<bool> checkoutReminderEnabled;
  final Value<DateTime> updatedAt;
  const AttendanceRulesCompanion({
    this.id = const Value.absent(),
    this.workStartTime = const Value.absent(),
    this.workEndTime = const Value.absent(),
    this.lateGraceMinutes = const Value.absent(),
    this.weekendType = const Value.absent(),
    this.overtimeRoundingMinutes = const Value.absent(),
    this.officeLat = const Value.absent(),
    this.officeLng = const Value.absent(),
    this.officeRadiusMeters = const Value.absent(),
    this.geofenceEnabled = const Value.absent(),
    this.checkinReminderEnabled = const Value.absent(),
    this.checkoutReminderEnabled = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  AttendanceRulesCompanion.insert({
    this.id = const Value.absent(),
    this.workStartTime = const Value.absent(),
    this.workEndTime = const Value.absent(),
    this.lateGraceMinutes = const Value.absent(),
    this.weekendType = const Value.absent(),
    this.overtimeRoundingMinutes = const Value.absent(),
    this.officeLat = const Value.absent(),
    this.officeLng = const Value.absent(),
    this.officeRadiusMeters = const Value.absent(),
    this.geofenceEnabled = const Value.absent(),
    this.checkinReminderEnabled = const Value.absent(),
    this.checkoutReminderEnabled = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  static Insertable<AttendanceRule> custom({
    Expression<int>? id,
    Expression<String>? workStartTime,
    Expression<String>? workEndTime,
    Expression<int>? lateGraceMinutes,
    Expression<String>? weekendType,
    Expression<int>? overtimeRoundingMinutes,
    Expression<double>? officeLat,
    Expression<double>? officeLng,
    Expression<int>? officeRadiusMeters,
    Expression<bool>? geofenceEnabled,
    Expression<bool>? checkinReminderEnabled,
    Expression<bool>? checkoutReminderEnabled,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (workStartTime != null) 'work_start_time': workStartTime,
      if (workEndTime != null) 'work_end_time': workEndTime,
      if (lateGraceMinutes != null) 'late_grace_minutes': lateGraceMinutes,
      if (weekendType != null) 'weekend_type': weekendType,
      if (overtimeRoundingMinutes != null)
        'overtime_rounding_minutes': overtimeRoundingMinutes,
      if (officeLat != null) 'office_lat': officeLat,
      if (officeLng != null) 'office_lng': officeLng,
      if (officeRadiusMeters != null)
        'office_radius_meters': officeRadiusMeters,
      if (geofenceEnabled != null) 'geofence_enabled': geofenceEnabled,
      if (checkinReminderEnabled != null)
        'checkin_reminder_enabled': checkinReminderEnabled,
      if (checkoutReminderEnabled != null)
        'checkout_reminder_enabled': checkoutReminderEnabled,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  AttendanceRulesCompanion copyWith(
      {Value<int>? id,
      Value<String>? workStartTime,
      Value<String>? workEndTime,
      Value<int>? lateGraceMinutes,
      Value<String>? weekendType,
      Value<int>? overtimeRoundingMinutes,
      Value<double?>? officeLat,
      Value<double?>? officeLng,
      Value<int>? officeRadiusMeters,
      Value<bool>? geofenceEnabled,
      Value<bool>? checkinReminderEnabled,
      Value<bool>? checkoutReminderEnabled,
      Value<DateTime>? updatedAt}) {
    return AttendanceRulesCompanion(
      id: id ?? this.id,
      workStartTime: workStartTime ?? this.workStartTime,
      workEndTime: workEndTime ?? this.workEndTime,
      lateGraceMinutes: lateGraceMinutes ?? this.lateGraceMinutes,
      weekendType: weekendType ?? this.weekendType,
      overtimeRoundingMinutes:
          overtimeRoundingMinutes ?? this.overtimeRoundingMinutes,
      officeLat: officeLat ?? this.officeLat,
      officeLng: officeLng ?? this.officeLng,
      officeRadiusMeters: officeRadiusMeters ?? this.officeRadiusMeters,
      geofenceEnabled: geofenceEnabled ?? this.geofenceEnabled,
      checkinReminderEnabled:
          checkinReminderEnabled ?? this.checkinReminderEnabled,
      checkoutReminderEnabled:
          checkoutReminderEnabled ?? this.checkoutReminderEnabled,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (workStartTime.present) {
      map['work_start_time'] = Variable<String>(workStartTime.value);
    }
    if (workEndTime.present) {
      map['work_end_time'] = Variable<String>(workEndTime.value);
    }
    if (lateGraceMinutes.present) {
      map['late_grace_minutes'] = Variable<int>(lateGraceMinutes.value);
    }
    if (weekendType.present) {
      map['weekend_type'] = Variable<String>(weekendType.value);
    }
    if (overtimeRoundingMinutes.present) {
      map['overtime_rounding_minutes'] =
          Variable<int>(overtimeRoundingMinutes.value);
    }
    if (officeLat.present) {
      map['office_lat'] = Variable<double>(officeLat.value);
    }
    if (officeLng.present) {
      map['office_lng'] = Variable<double>(officeLng.value);
    }
    if (officeRadiusMeters.present) {
      map['office_radius_meters'] = Variable<int>(officeRadiusMeters.value);
    }
    if (geofenceEnabled.present) {
      map['geofence_enabled'] = Variable<bool>(geofenceEnabled.value);
    }
    if (checkinReminderEnabled.present) {
      map['checkin_reminder_enabled'] =
          Variable<bool>(checkinReminderEnabled.value);
    }
    if (checkoutReminderEnabled.present) {
      map['checkout_reminder_enabled'] =
          Variable<bool>(checkoutReminderEnabled.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AttendanceRulesCompanion(')
          ..write('id: $id, ')
          ..write('workStartTime: $workStartTime, ')
          ..write('workEndTime: $workEndTime, ')
          ..write('lateGraceMinutes: $lateGraceMinutes, ')
          ..write('weekendType: $weekendType, ')
          ..write('overtimeRoundingMinutes: $overtimeRoundingMinutes, ')
          ..write('officeLat: $officeLat, ')
          ..write('officeLng: $officeLng, ')
          ..write('officeRadiusMeters: $officeRadiusMeters, ')
          ..write('geofenceEnabled: $geofenceEnabled, ')
          ..write('checkinReminderEnabled: $checkinReminderEnabled, ')
          ..write('checkoutReminderEnabled: $checkoutReminderEnabled, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $AttendanceRecordsTable extends AttendanceRecords
    with TableInfo<$AttendanceRecordsTable, AttendanceRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AttendanceRecordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _dayMeta = const VerificationMeta('day');
  @override
  late final GeneratedColumn<DateTime> day = GeneratedColumn<DateTime>(
      'day', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _checkInAtMeta =
      const VerificationMeta('checkInAt');
  @override
  late final GeneratedColumn<DateTime> checkInAt = GeneratedColumn<DateTime>(
      'check_in_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _checkOutAtMeta =
      const VerificationMeta('checkOutAt');
  @override
  late final GeneratedColumn<DateTime> checkOutAt = GeneratedColumn<DateTime>(
      'check_out_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _isWorkdayMeta =
      const VerificationMeta('isWorkday');
  @override
  late final GeneratedColumn<bool> isWorkday = GeneratedColumn<bool>(
      'is_workday', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_workday" IN (0, 1))'),
      defaultValue: const Constant(true));
  static const VerificationMeta _isLateMeta = const VerificationMeta('isLate');
  @override
  late final GeneratedColumn<bool> isLate = GeneratedColumn<bool>(
      'is_late', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_late" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _isEarlyLeaveMeta =
      const VerificationMeta('isEarlyLeave');
  @override
  late final GeneratedColumn<bool> isEarlyLeave = GeneratedColumn<bool>(
      'is_early_leave', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("is_early_leave" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _isAbsentMeta =
      const VerificationMeta('isAbsent');
  @override
  late final GeneratedColumn<bool> isAbsent = GeneratedColumn<bool>(
      'is_absent', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_absent" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _isLeaveMeta =
      const VerificationMeta('isLeave');
  @override
  late final GeneratedColumn<bool> isLeave = GeneratedColumn<bool>(
      'is_leave', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_leave" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _isExceptionMeta =
      const VerificationMeta('isException');
  @override
  late final GeneratedColumn<bool> isException = GeneratedColumn<bool>(
      'is_exception', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("is_exception" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _needsPatchMeta =
      const VerificationMeta('needsPatch');
  @override
  late final GeneratedColumn<bool> needsPatch = GeneratedColumn<bool>(
      'needs_patch', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("needs_patch" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _patchedMeta =
      const VerificationMeta('patched');
  @override
  late final GeneratedColumn<bool> patched = GeneratedColumn<bool>(
      'patched', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("patched" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _overtimeMinutesRawMeta =
      const VerificationMeta('overtimeMinutesRaw');
  @override
  late final GeneratedColumn<int> overtimeMinutesRaw = GeneratedColumn<int>(
      'overtime_minutes_raw', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _leaveMinutesMeta =
      const VerificationMeta('leaveMinutes');
  @override
  late final GeneratedColumn<int> leaveMinutes = GeneratedColumn<int>(
      'leave_minutes', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _overtimeHoursRoundedMeta =
      const VerificationMeta('overtimeHoursRounded');
  @override
  late final GeneratedColumn<double> overtimeHoursRounded =
      GeneratedColumn<double>('overtime_hours_rounded', aliasedName, false,
          type: DriftSqlType.double,
          requiredDuringInsert: false,
          defaultValue: const Constant(0.0));
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
      'source', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('manual'));
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
      'note', aliasedName, true,
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
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        day,
        checkInAt,
        checkOutAt,
        isWorkday,
        isLate,
        isEarlyLeave,
        isAbsent,
        isLeave,
        isException,
        needsPatch,
        patched,
        overtimeMinutesRaw,
        leaveMinutes,
        overtimeHoursRounded,
        source,
        note,
        createdAt,
        updatedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'attendance_records';
  @override
  VerificationContext validateIntegrity(Insertable<AttendanceRecord> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('day')) {
      context.handle(
          _dayMeta, day.isAcceptableOrUnknown(data['day']!, _dayMeta));
    } else if (isInserting) {
      context.missing(_dayMeta);
    }
    if (data.containsKey('check_in_at')) {
      context.handle(
          _checkInAtMeta,
          checkInAt.isAcceptableOrUnknown(
              data['check_in_at']!, _checkInAtMeta));
    }
    if (data.containsKey('check_out_at')) {
      context.handle(
          _checkOutAtMeta,
          checkOutAt.isAcceptableOrUnknown(
              data['check_out_at']!, _checkOutAtMeta));
    }
    if (data.containsKey('is_workday')) {
      context.handle(_isWorkdayMeta,
          isWorkday.isAcceptableOrUnknown(data['is_workday']!, _isWorkdayMeta));
    }
    if (data.containsKey('is_late')) {
      context.handle(_isLateMeta,
          isLate.isAcceptableOrUnknown(data['is_late']!, _isLateMeta));
    }
    if (data.containsKey('is_early_leave')) {
      context.handle(
          _isEarlyLeaveMeta,
          isEarlyLeave.isAcceptableOrUnknown(
              data['is_early_leave']!, _isEarlyLeaveMeta));
    }
    if (data.containsKey('is_absent')) {
      context.handle(_isAbsentMeta,
          isAbsent.isAcceptableOrUnknown(data['is_absent']!, _isAbsentMeta));
    }
    if (data.containsKey('is_leave')) {
      context.handle(_isLeaveMeta,
          isLeave.isAcceptableOrUnknown(data['is_leave']!, _isLeaveMeta));
    }
    if (data.containsKey('is_exception')) {
      context.handle(
          _isExceptionMeta,
          isException.isAcceptableOrUnknown(
              data['is_exception']!, _isExceptionMeta));
    }
    if (data.containsKey('needs_patch')) {
      context.handle(
          _needsPatchMeta,
          needsPatch.isAcceptableOrUnknown(
              data['needs_patch']!, _needsPatchMeta));
    }
    if (data.containsKey('patched')) {
      context.handle(_patchedMeta,
          patched.isAcceptableOrUnknown(data['patched']!, _patchedMeta));
    }
    if (data.containsKey('overtime_minutes_raw')) {
      context.handle(
          _overtimeMinutesRawMeta,
          overtimeMinutesRaw.isAcceptableOrUnknown(
              data['overtime_minutes_raw']!, _overtimeMinutesRawMeta));
    }
    if (data.containsKey('leave_minutes')) {
      context.handle(
          _leaveMinutesMeta,
          leaveMinutes.isAcceptableOrUnknown(
              data['leave_minutes']!, _leaveMinutesMeta));
    }
    if (data.containsKey('overtime_hours_rounded')) {
      context.handle(
          _overtimeHoursRoundedMeta,
          overtimeHoursRounded.isAcceptableOrUnknown(
              data['overtime_hours_rounded']!, _overtimeHoursRoundedMeta));
    }
    if (data.containsKey('source')) {
      context.handle(_sourceMeta,
          source.isAcceptableOrUnknown(data['source']!, _sourceMeta));
    }
    if (data.containsKey('note')) {
      context.handle(
          _noteMeta, note.isAcceptableOrUnknown(data['note']!, _noteMeta));
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
  AttendanceRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AttendanceRecord(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      day: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}day'])!,
      checkInAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}check_in_at']),
      checkOutAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}check_out_at']),
      isWorkday: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_workday'])!,
      isLate: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_late'])!,
      isEarlyLeave: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_early_leave'])!,
      isAbsent: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_absent'])!,
      isLeave: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_leave'])!,
      isException: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_exception'])!,
      needsPatch: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}needs_patch'])!,
      patched: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}patched'])!,
      overtimeMinutesRaw: attachedDatabase.typeMapping.read(
          DriftSqlType.int, data['${effectivePrefix}overtime_minutes_raw'])!,
      leaveMinutes: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}leave_minutes'])!,
      overtimeHoursRounded: attachedDatabase.typeMapping.read(
          DriftSqlType.double,
          data['${effectivePrefix}overtime_hours_rounded'])!,
      source: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}source'])!,
      note: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}note']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $AttendanceRecordsTable createAlias(String alias) {
    return $AttendanceRecordsTable(attachedDatabase, alias);
  }
}

class AttendanceRecord extends DataClass
    implements Insertable<AttendanceRecord> {
  final int id;
  final DateTime day;
  final DateTime? checkInAt;
  final DateTime? checkOutAt;
  final bool isWorkday;
  final bool isLate;
  final bool isEarlyLeave;
  final bool isAbsent;
  final bool isLeave;
  final bool isException;
  final bool needsPatch;
  final bool patched;
  final int overtimeMinutesRaw;
  final int leaveMinutes;
  final double overtimeHoursRounded;
  final String source;
  final String? note;
  final DateTime createdAt;
  final DateTime updatedAt;
  const AttendanceRecord(
      {required this.id,
      required this.day,
      this.checkInAt,
      this.checkOutAt,
      required this.isWorkday,
      required this.isLate,
      required this.isEarlyLeave,
      required this.isAbsent,
      required this.isLeave,
      required this.isException,
      required this.needsPatch,
      required this.patched,
      required this.overtimeMinutesRaw,
      required this.leaveMinutes,
      required this.overtimeHoursRounded,
      required this.source,
      this.note,
      required this.createdAt,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['day'] = Variable<DateTime>(day);
    if (!nullToAbsent || checkInAt != null) {
      map['check_in_at'] = Variable<DateTime>(checkInAt);
    }
    if (!nullToAbsent || checkOutAt != null) {
      map['check_out_at'] = Variable<DateTime>(checkOutAt);
    }
    map['is_workday'] = Variable<bool>(isWorkday);
    map['is_late'] = Variable<bool>(isLate);
    map['is_early_leave'] = Variable<bool>(isEarlyLeave);
    map['is_absent'] = Variable<bool>(isAbsent);
    map['is_leave'] = Variable<bool>(isLeave);
    map['is_exception'] = Variable<bool>(isException);
    map['needs_patch'] = Variable<bool>(needsPatch);
    map['patched'] = Variable<bool>(patched);
    map['overtime_minutes_raw'] = Variable<int>(overtimeMinutesRaw);
    map['leave_minutes'] = Variable<int>(leaveMinutes);
    map['overtime_hours_rounded'] = Variable<double>(overtimeHoursRounded);
    map['source'] = Variable<String>(source);
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  AttendanceRecordsCompanion toCompanion(bool nullToAbsent) {
    return AttendanceRecordsCompanion(
      id: Value(id),
      day: Value(day),
      checkInAt: checkInAt == null && nullToAbsent
          ? const Value.absent()
          : Value(checkInAt),
      checkOutAt: checkOutAt == null && nullToAbsent
          ? const Value.absent()
          : Value(checkOutAt),
      isWorkday: Value(isWorkday),
      isLate: Value(isLate),
      isEarlyLeave: Value(isEarlyLeave),
      isAbsent: Value(isAbsent),
      isLeave: Value(isLeave),
      isException: Value(isException),
      needsPatch: Value(needsPatch),
      patched: Value(patched),
      overtimeMinutesRaw: Value(overtimeMinutesRaw),
      leaveMinutes: Value(leaveMinutes),
      overtimeHoursRounded: Value(overtimeHoursRounded),
      source: Value(source),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory AttendanceRecord.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AttendanceRecord(
      id: serializer.fromJson<int>(json['id']),
      day: serializer.fromJson<DateTime>(json['day']),
      checkInAt: serializer.fromJson<DateTime?>(json['checkInAt']),
      checkOutAt: serializer.fromJson<DateTime?>(json['checkOutAt']),
      isWorkday: serializer.fromJson<bool>(json['isWorkday']),
      isLate: serializer.fromJson<bool>(json['isLate']),
      isEarlyLeave: serializer.fromJson<bool>(json['isEarlyLeave']),
      isAbsent: serializer.fromJson<bool>(json['isAbsent']),
      isLeave: serializer.fromJson<bool>(json['isLeave']),
      isException: serializer.fromJson<bool>(json['isException']),
      needsPatch: serializer.fromJson<bool>(json['needsPatch']),
      patched: serializer.fromJson<bool>(json['patched']),
      overtimeMinutesRaw: serializer.fromJson<int>(json['overtimeMinutesRaw']),
      leaveMinutes: serializer.fromJson<int>(json['leaveMinutes']),
      overtimeHoursRounded:
          serializer.fromJson<double>(json['overtimeHoursRounded']),
      source: serializer.fromJson<String>(json['source']),
      note: serializer.fromJson<String?>(json['note']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'day': serializer.toJson<DateTime>(day),
      'checkInAt': serializer.toJson<DateTime?>(checkInAt),
      'checkOutAt': serializer.toJson<DateTime?>(checkOutAt),
      'isWorkday': serializer.toJson<bool>(isWorkday),
      'isLate': serializer.toJson<bool>(isLate),
      'isEarlyLeave': serializer.toJson<bool>(isEarlyLeave),
      'isAbsent': serializer.toJson<bool>(isAbsent),
      'isLeave': serializer.toJson<bool>(isLeave),
      'isException': serializer.toJson<bool>(isException),
      'needsPatch': serializer.toJson<bool>(needsPatch),
      'patched': serializer.toJson<bool>(patched),
      'overtimeMinutesRaw': serializer.toJson<int>(overtimeMinutesRaw),
      'leaveMinutes': serializer.toJson<int>(leaveMinutes),
      'overtimeHoursRounded': serializer.toJson<double>(overtimeHoursRounded),
      'source': serializer.toJson<String>(source),
      'note': serializer.toJson<String?>(note),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  AttendanceRecord copyWith(
          {int? id,
          DateTime? day,
          Value<DateTime?> checkInAt = const Value.absent(),
          Value<DateTime?> checkOutAt = const Value.absent(),
          bool? isWorkday,
          bool? isLate,
          bool? isEarlyLeave,
          bool? isAbsent,
          bool? isLeave,
          bool? isException,
          bool? needsPatch,
          bool? patched,
          int? overtimeMinutesRaw,
          int? leaveMinutes,
          double? overtimeHoursRounded,
          String? source,
          Value<String?> note = const Value.absent(),
          DateTime? createdAt,
          DateTime? updatedAt}) =>
      AttendanceRecord(
        id: id ?? this.id,
        day: day ?? this.day,
        checkInAt: checkInAt.present ? checkInAt.value : this.checkInAt,
        checkOutAt: checkOutAt.present ? checkOutAt.value : this.checkOutAt,
        isWorkday: isWorkday ?? this.isWorkday,
        isLate: isLate ?? this.isLate,
        isEarlyLeave: isEarlyLeave ?? this.isEarlyLeave,
        isAbsent: isAbsent ?? this.isAbsent,
        isLeave: isLeave ?? this.isLeave,
        isException: isException ?? this.isException,
        needsPatch: needsPatch ?? this.needsPatch,
        patched: patched ?? this.patched,
        overtimeMinutesRaw: overtimeMinutesRaw ?? this.overtimeMinutesRaw,
        leaveMinutes: leaveMinutes ?? this.leaveMinutes,
        overtimeHoursRounded: overtimeHoursRounded ?? this.overtimeHoursRounded,
        source: source ?? this.source,
        note: note.present ? note.value : this.note,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  AttendanceRecord copyWithCompanion(AttendanceRecordsCompanion data) {
    return AttendanceRecord(
      id: data.id.present ? data.id.value : this.id,
      day: data.day.present ? data.day.value : this.day,
      checkInAt: data.checkInAt.present ? data.checkInAt.value : this.checkInAt,
      checkOutAt:
          data.checkOutAt.present ? data.checkOutAt.value : this.checkOutAt,
      isWorkday: data.isWorkday.present ? data.isWorkday.value : this.isWorkday,
      isLate: data.isLate.present ? data.isLate.value : this.isLate,
      isEarlyLeave: data.isEarlyLeave.present
          ? data.isEarlyLeave.value
          : this.isEarlyLeave,
      isAbsent: data.isAbsent.present ? data.isAbsent.value : this.isAbsent,
      isLeave: data.isLeave.present ? data.isLeave.value : this.isLeave,
      isException:
          data.isException.present ? data.isException.value : this.isException,
      needsPatch:
          data.needsPatch.present ? data.needsPatch.value : this.needsPatch,
      patched: data.patched.present ? data.patched.value : this.patched,
      overtimeMinutesRaw: data.overtimeMinutesRaw.present
          ? data.overtimeMinutesRaw.value
          : this.overtimeMinutesRaw,
      leaveMinutes: data.leaveMinutes.present
          ? data.leaveMinutes.value
          : this.leaveMinutes,
      overtimeHoursRounded: data.overtimeHoursRounded.present
          ? data.overtimeHoursRounded.value
          : this.overtimeHoursRounded,
      source: data.source.present ? data.source.value : this.source,
      note: data.note.present ? data.note.value : this.note,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AttendanceRecord(')
          ..write('id: $id, ')
          ..write('day: $day, ')
          ..write('checkInAt: $checkInAt, ')
          ..write('checkOutAt: $checkOutAt, ')
          ..write('isWorkday: $isWorkday, ')
          ..write('isLate: $isLate, ')
          ..write('isEarlyLeave: $isEarlyLeave, ')
          ..write('isAbsent: $isAbsent, ')
          ..write('isLeave: $isLeave, ')
          ..write('isException: $isException, ')
          ..write('needsPatch: $needsPatch, ')
          ..write('patched: $patched, ')
          ..write('overtimeMinutesRaw: $overtimeMinutesRaw, ')
          ..write('leaveMinutes: $leaveMinutes, ')
          ..write('overtimeHoursRounded: $overtimeHoursRounded, ')
          ..write('source: $source, ')
          ..write('note: $note, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      day,
      checkInAt,
      checkOutAt,
      isWorkday,
      isLate,
      isEarlyLeave,
      isAbsent,
      isLeave,
      isException,
      needsPatch,
      patched,
      overtimeMinutesRaw,
      leaveMinutes,
      overtimeHoursRounded,
      source,
      note,
      createdAt,
      updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AttendanceRecord &&
          other.id == this.id &&
          other.day == this.day &&
          other.checkInAt == this.checkInAt &&
          other.checkOutAt == this.checkOutAt &&
          other.isWorkday == this.isWorkday &&
          other.isLate == this.isLate &&
          other.isEarlyLeave == this.isEarlyLeave &&
          other.isAbsent == this.isAbsent &&
          other.isLeave == this.isLeave &&
          other.isException == this.isException &&
          other.needsPatch == this.needsPatch &&
          other.patched == this.patched &&
          other.overtimeMinutesRaw == this.overtimeMinutesRaw &&
          other.leaveMinutes == this.leaveMinutes &&
          other.overtimeHoursRounded == this.overtimeHoursRounded &&
          other.source == this.source &&
          other.note == this.note &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class AttendanceRecordsCompanion extends UpdateCompanion<AttendanceRecord> {
  final Value<int> id;
  final Value<DateTime> day;
  final Value<DateTime?> checkInAt;
  final Value<DateTime?> checkOutAt;
  final Value<bool> isWorkday;
  final Value<bool> isLate;
  final Value<bool> isEarlyLeave;
  final Value<bool> isAbsent;
  final Value<bool> isLeave;
  final Value<bool> isException;
  final Value<bool> needsPatch;
  final Value<bool> patched;
  final Value<int> overtimeMinutesRaw;
  final Value<int> leaveMinutes;
  final Value<double> overtimeHoursRounded;
  final Value<String> source;
  final Value<String?> note;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  const AttendanceRecordsCompanion({
    this.id = const Value.absent(),
    this.day = const Value.absent(),
    this.checkInAt = const Value.absent(),
    this.checkOutAt = const Value.absent(),
    this.isWorkday = const Value.absent(),
    this.isLate = const Value.absent(),
    this.isEarlyLeave = const Value.absent(),
    this.isAbsent = const Value.absent(),
    this.isLeave = const Value.absent(),
    this.isException = const Value.absent(),
    this.needsPatch = const Value.absent(),
    this.patched = const Value.absent(),
    this.overtimeMinutesRaw = const Value.absent(),
    this.leaveMinutes = const Value.absent(),
    this.overtimeHoursRounded = const Value.absent(),
    this.source = const Value.absent(),
    this.note = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  AttendanceRecordsCompanion.insert({
    this.id = const Value.absent(),
    required DateTime day,
    this.checkInAt = const Value.absent(),
    this.checkOutAt = const Value.absent(),
    this.isWorkday = const Value.absent(),
    this.isLate = const Value.absent(),
    this.isEarlyLeave = const Value.absent(),
    this.isAbsent = const Value.absent(),
    this.isLeave = const Value.absent(),
    this.isException = const Value.absent(),
    this.needsPatch = const Value.absent(),
    this.patched = const Value.absent(),
    this.overtimeMinutesRaw = const Value.absent(),
    this.leaveMinutes = const Value.absent(),
    this.overtimeHoursRounded = const Value.absent(),
    this.source = const Value.absent(),
    this.note = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  }) : day = Value(day);
  static Insertable<AttendanceRecord> custom({
    Expression<int>? id,
    Expression<DateTime>? day,
    Expression<DateTime>? checkInAt,
    Expression<DateTime>? checkOutAt,
    Expression<bool>? isWorkday,
    Expression<bool>? isLate,
    Expression<bool>? isEarlyLeave,
    Expression<bool>? isAbsent,
    Expression<bool>? isLeave,
    Expression<bool>? isException,
    Expression<bool>? needsPatch,
    Expression<bool>? patched,
    Expression<int>? overtimeMinutesRaw,
    Expression<int>? leaveMinutes,
    Expression<double>? overtimeHoursRounded,
    Expression<String>? source,
    Expression<String>? note,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (day != null) 'day': day,
      if (checkInAt != null) 'check_in_at': checkInAt,
      if (checkOutAt != null) 'check_out_at': checkOutAt,
      if (isWorkday != null) 'is_workday': isWorkday,
      if (isLate != null) 'is_late': isLate,
      if (isEarlyLeave != null) 'is_early_leave': isEarlyLeave,
      if (isAbsent != null) 'is_absent': isAbsent,
      if (isLeave != null) 'is_leave': isLeave,
      if (isException != null) 'is_exception': isException,
      if (needsPatch != null) 'needs_patch': needsPatch,
      if (patched != null) 'patched': patched,
      if (overtimeMinutesRaw != null)
        'overtime_minutes_raw': overtimeMinutesRaw,
      if (leaveMinutes != null) 'leave_minutes': leaveMinutes,
      if (overtimeHoursRounded != null)
        'overtime_hours_rounded': overtimeHoursRounded,
      if (source != null) 'source': source,
      if (note != null) 'note': note,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  AttendanceRecordsCompanion copyWith(
      {Value<int>? id,
      Value<DateTime>? day,
      Value<DateTime?>? checkInAt,
      Value<DateTime?>? checkOutAt,
      Value<bool>? isWorkday,
      Value<bool>? isLate,
      Value<bool>? isEarlyLeave,
      Value<bool>? isAbsent,
      Value<bool>? isLeave,
      Value<bool>? isException,
      Value<bool>? needsPatch,
      Value<bool>? patched,
      Value<int>? overtimeMinutesRaw,
      Value<int>? leaveMinutes,
      Value<double>? overtimeHoursRounded,
      Value<String>? source,
      Value<String?>? note,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt}) {
    return AttendanceRecordsCompanion(
      id: id ?? this.id,
      day: day ?? this.day,
      checkInAt: checkInAt ?? this.checkInAt,
      checkOutAt: checkOutAt ?? this.checkOutAt,
      isWorkday: isWorkday ?? this.isWorkday,
      isLate: isLate ?? this.isLate,
      isEarlyLeave: isEarlyLeave ?? this.isEarlyLeave,
      isAbsent: isAbsent ?? this.isAbsent,
      isLeave: isLeave ?? this.isLeave,
      isException: isException ?? this.isException,
      needsPatch: needsPatch ?? this.needsPatch,
      patched: patched ?? this.patched,
      overtimeMinutesRaw: overtimeMinutesRaw ?? this.overtimeMinutesRaw,
      leaveMinutes: leaveMinutes ?? this.leaveMinutes,
      overtimeHoursRounded: overtimeHoursRounded ?? this.overtimeHoursRounded,
      source: source ?? this.source,
      note: note ?? this.note,
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
    if (day.present) {
      map['day'] = Variable<DateTime>(day.value);
    }
    if (checkInAt.present) {
      map['check_in_at'] = Variable<DateTime>(checkInAt.value);
    }
    if (checkOutAt.present) {
      map['check_out_at'] = Variable<DateTime>(checkOutAt.value);
    }
    if (isWorkday.present) {
      map['is_workday'] = Variable<bool>(isWorkday.value);
    }
    if (isLate.present) {
      map['is_late'] = Variable<bool>(isLate.value);
    }
    if (isEarlyLeave.present) {
      map['is_early_leave'] = Variable<bool>(isEarlyLeave.value);
    }
    if (isAbsent.present) {
      map['is_absent'] = Variable<bool>(isAbsent.value);
    }
    if (isLeave.present) {
      map['is_leave'] = Variable<bool>(isLeave.value);
    }
    if (isException.present) {
      map['is_exception'] = Variable<bool>(isException.value);
    }
    if (needsPatch.present) {
      map['needs_patch'] = Variable<bool>(needsPatch.value);
    }
    if (patched.present) {
      map['patched'] = Variable<bool>(patched.value);
    }
    if (overtimeMinutesRaw.present) {
      map['overtime_minutes_raw'] = Variable<int>(overtimeMinutesRaw.value);
    }
    if (leaveMinutes.present) {
      map['leave_minutes'] = Variable<int>(leaveMinutes.value);
    }
    if (overtimeHoursRounded.present) {
      map['overtime_hours_rounded'] =
          Variable<double>(overtimeHoursRounded.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
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
    return (StringBuffer('AttendanceRecordsCompanion(')
          ..write('id: $id, ')
          ..write('day: $day, ')
          ..write('checkInAt: $checkInAt, ')
          ..write('checkOutAt: $checkOutAt, ')
          ..write('isWorkday: $isWorkday, ')
          ..write('isLate: $isLate, ')
          ..write('isEarlyLeave: $isEarlyLeave, ')
          ..write('isAbsent: $isAbsent, ')
          ..write('isLeave: $isLeave, ')
          ..write('isException: $isException, ')
          ..write('needsPatch: $needsPatch, ')
          ..write('patched: $patched, ')
          ..write('overtimeMinutesRaw: $overtimeMinutesRaw, ')
          ..write('leaveMinutes: $leaveMinutes, ')
          ..write('overtimeHoursRounded: $overtimeHoursRounded, ')
          ..write('source: $source, ')
          ..write('note: $note, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $PatchRequestsTable extends PatchRequests
    with TableInfo<$PatchRequestsTable, PatchRequest> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PatchRequestsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _dayMeta = const VerificationMeta('day');
  @override
  late final GeneratedColumn<DateTime> day = GeneratedColumn<DateTime>(
      'day', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _patchTypeMeta =
      const VerificationMeta('patchType');
  @override
  late final GeneratedColumn<String> patchType = GeneratedColumn<String>(
      'patch_type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _requestedCheckInAtMeta =
      const VerificationMeta('requestedCheckInAt');
  @override
  late final GeneratedColumn<DateTime> requestedCheckInAt =
      GeneratedColumn<DateTime>('requested_check_in_at', aliasedName, true,
          type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _requestedCheckOutAtMeta =
      const VerificationMeta('requestedCheckOutAt');
  @override
  late final GeneratedColumn<DateTime> requestedCheckOutAt =
      GeneratedColumn<DateTime>('requested_check_out_at', aliasedName, true,
          type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _reasonMeta = const VerificationMeta('reason');
  @override
  late final GeneratedColumn<String> reason = GeneratedColumn<String>(
      'reason', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
      'status', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('pending'));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _reviewedAtMeta =
      const VerificationMeta('reviewedAt');
  @override
  late final GeneratedColumn<DateTime> reviewedAt = GeneratedColumn<DateTime>(
      'reviewed_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        day,
        patchType,
        requestedCheckInAt,
        requestedCheckOutAt,
        reason,
        status,
        createdAt,
        reviewedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'patch_requests';
  @override
  VerificationContext validateIntegrity(Insertable<PatchRequest> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('day')) {
      context.handle(
          _dayMeta, day.isAcceptableOrUnknown(data['day']!, _dayMeta));
    } else if (isInserting) {
      context.missing(_dayMeta);
    }
    if (data.containsKey('patch_type')) {
      context.handle(_patchTypeMeta,
          patchType.isAcceptableOrUnknown(data['patch_type']!, _patchTypeMeta));
    } else if (isInserting) {
      context.missing(_patchTypeMeta);
    }
    if (data.containsKey('requested_check_in_at')) {
      context.handle(
          _requestedCheckInAtMeta,
          requestedCheckInAt.isAcceptableOrUnknown(
              data['requested_check_in_at']!, _requestedCheckInAtMeta));
    }
    if (data.containsKey('requested_check_out_at')) {
      context.handle(
          _requestedCheckOutAtMeta,
          requestedCheckOutAt.isAcceptableOrUnknown(
              data['requested_check_out_at']!, _requestedCheckOutAtMeta));
    }
    if (data.containsKey('reason')) {
      context.handle(_reasonMeta,
          reason.isAcceptableOrUnknown(data['reason']!, _reasonMeta));
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    if (data.containsKey('reviewed_at')) {
      context.handle(
          _reviewedAtMeta,
          reviewedAt.isAcceptableOrUnknown(
              data['reviewed_at']!, _reviewedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PatchRequest map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PatchRequest(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      day: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}day'])!,
      patchType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}patch_type'])!,
      requestedCheckInAt: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime,
          data['${effectivePrefix}requested_check_in_at']),
      requestedCheckOutAt: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime,
          data['${effectivePrefix}requested_check_out_at']),
      reason: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}reason'])!,
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      reviewedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}reviewed_at']),
    );
  }

  @override
  $PatchRequestsTable createAlias(String alias) {
    return $PatchRequestsTable(attachedDatabase, alias);
  }
}

class PatchRequest extends DataClass implements Insertable<PatchRequest> {
  final int id;
  final DateTime day;
  final String patchType;
  final DateTime? requestedCheckInAt;
  final DateTime? requestedCheckOutAt;
  final String reason;
  final String status;
  final DateTime createdAt;
  final DateTime? reviewedAt;
  const PatchRequest(
      {required this.id,
      required this.day,
      required this.patchType,
      this.requestedCheckInAt,
      this.requestedCheckOutAt,
      required this.reason,
      required this.status,
      required this.createdAt,
      this.reviewedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['day'] = Variable<DateTime>(day);
    map['patch_type'] = Variable<String>(patchType);
    if (!nullToAbsent || requestedCheckInAt != null) {
      map['requested_check_in_at'] = Variable<DateTime>(requestedCheckInAt);
    }
    if (!nullToAbsent || requestedCheckOutAt != null) {
      map['requested_check_out_at'] = Variable<DateTime>(requestedCheckOutAt);
    }
    map['reason'] = Variable<String>(reason);
    map['status'] = Variable<String>(status);
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || reviewedAt != null) {
      map['reviewed_at'] = Variable<DateTime>(reviewedAt);
    }
    return map;
  }

  PatchRequestsCompanion toCompanion(bool nullToAbsent) {
    return PatchRequestsCompanion(
      id: Value(id),
      day: Value(day),
      patchType: Value(patchType),
      requestedCheckInAt: requestedCheckInAt == null && nullToAbsent
          ? const Value.absent()
          : Value(requestedCheckInAt),
      requestedCheckOutAt: requestedCheckOutAt == null && nullToAbsent
          ? const Value.absent()
          : Value(requestedCheckOutAt),
      reason: Value(reason),
      status: Value(status),
      createdAt: Value(createdAt),
      reviewedAt: reviewedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(reviewedAt),
    );
  }

  factory PatchRequest.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PatchRequest(
      id: serializer.fromJson<int>(json['id']),
      day: serializer.fromJson<DateTime>(json['day']),
      patchType: serializer.fromJson<String>(json['patchType']),
      requestedCheckInAt:
          serializer.fromJson<DateTime?>(json['requestedCheckInAt']),
      requestedCheckOutAt:
          serializer.fromJson<DateTime?>(json['requestedCheckOutAt']),
      reason: serializer.fromJson<String>(json['reason']),
      status: serializer.fromJson<String>(json['status']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      reviewedAt: serializer.fromJson<DateTime?>(json['reviewedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'day': serializer.toJson<DateTime>(day),
      'patchType': serializer.toJson<String>(patchType),
      'requestedCheckInAt': serializer.toJson<DateTime?>(requestedCheckInAt),
      'requestedCheckOutAt': serializer.toJson<DateTime?>(requestedCheckOutAt),
      'reason': serializer.toJson<String>(reason),
      'status': serializer.toJson<String>(status),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'reviewedAt': serializer.toJson<DateTime?>(reviewedAt),
    };
  }

  PatchRequest copyWith(
          {int? id,
          DateTime? day,
          String? patchType,
          Value<DateTime?> requestedCheckInAt = const Value.absent(),
          Value<DateTime?> requestedCheckOutAt = const Value.absent(),
          String? reason,
          String? status,
          DateTime? createdAt,
          Value<DateTime?> reviewedAt = const Value.absent()}) =>
      PatchRequest(
        id: id ?? this.id,
        day: day ?? this.day,
        patchType: patchType ?? this.patchType,
        requestedCheckInAt: requestedCheckInAt.present
            ? requestedCheckInAt.value
            : this.requestedCheckInAt,
        requestedCheckOutAt: requestedCheckOutAt.present
            ? requestedCheckOutAt.value
            : this.requestedCheckOutAt,
        reason: reason ?? this.reason,
        status: status ?? this.status,
        createdAt: createdAt ?? this.createdAt,
        reviewedAt: reviewedAt.present ? reviewedAt.value : this.reviewedAt,
      );
  PatchRequest copyWithCompanion(PatchRequestsCompanion data) {
    return PatchRequest(
      id: data.id.present ? data.id.value : this.id,
      day: data.day.present ? data.day.value : this.day,
      patchType: data.patchType.present ? data.patchType.value : this.patchType,
      requestedCheckInAt: data.requestedCheckInAt.present
          ? data.requestedCheckInAt.value
          : this.requestedCheckInAt,
      requestedCheckOutAt: data.requestedCheckOutAt.present
          ? data.requestedCheckOutAt.value
          : this.requestedCheckOutAt,
      reason: data.reason.present ? data.reason.value : this.reason,
      status: data.status.present ? data.status.value : this.status,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      reviewedAt:
          data.reviewedAt.present ? data.reviewedAt.value : this.reviewedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PatchRequest(')
          ..write('id: $id, ')
          ..write('day: $day, ')
          ..write('patchType: $patchType, ')
          ..write('requestedCheckInAt: $requestedCheckInAt, ')
          ..write('requestedCheckOutAt: $requestedCheckOutAt, ')
          ..write('reason: $reason, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt, ')
          ..write('reviewedAt: $reviewedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, day, patchType, requestedCheckInAt,
      requestedCheckOutAt, reason, status, createdAt, reviewedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PatchRequest &&
          other.id == this.id &&
          other.day == this.day &&
          other.patchType == this.patchType &&
          other.requestedCheckInAt == this.requestedCheckInAt &&
          other.requestedCheckOutAt == this.requestedCheckOutAt &&
          other.reason == this.reason &&
          other.status == this.status &&
          other.createdAt == this.createdAt &&
          other.reviewedAt == this.reviewedAt);
}

class PatchRequestsCompanion extends UpdateCompanion<PatchRequest> {
  final Value<int> id;
  final Value<DateTime> day;
  final Value<String> patchType;
  final Value<DateTime?> requestedCheckInAt;
  final Value<DateTime?> requestedCheckOutAt;
  final Value<String> reason;
  final Value<String> status;
  final Value<DateTime> createdAt;
  final Value<DateTime?> reviewedAt;
  const PatchRequestsCompanion({
    this.id = const Value.absent(),
    this.day = const Value.absent(),
    this.patchType = const Value.absent(),
    this.requestedCheckInAt = const Value.absent(),
    this.requestedCheckOutAt = const Value.absent(),
    this.reason = const Value.absent(),
    this.status = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.reviewedAt = const Value.absent(),
  });
  PatchRequestsCompanion.insert({
    this.id = const Value.absent(),
    required DateTime day,
    required String patchType,
    this.requestedCheckInAt = const Value.absent(),
    this.requestedCheckOutAt = const Value.absent(),
    this.reason = const Value.absent(),
    this.status = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.reviewedAt = const Value.absent(),
  })  : day = Value(day),
        patchType = Value(patchType);
  static Insertable<PatchRequest> custom({
    Expression<int>? id,
    Expression<DateTime>? day,
    Expression<String>? patchType,
    Expression<DateTime>? requestedCheckInAt,
    Expression<DateTime>? requestedCheckOutAt,
    Expression<String>? reason,
    Expression<String>? status,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? reviewedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (day != null) 'day': day,
      if (patchType != null) 'patch_type': patchType,
      if (requestedCheckInAt != null)
        'requested_check_in_at': requestedCheckInAt,
      if (requestedCheckOutAt != null)
        'requested_check_out_at': requestedCheckOutAt,
      if (reason != null) 'reason': reason,
      if (status != null) 'status': status,
      if (createdAt != null) 'created_at': createdAt,
      if (reviewedAt != null) 'reviewed_at': reviewedAt,
    });
  }

  PatchRequestsCompanion copyWith(
      {Value<int>? id,
      Value<DateTime>? day,
      Value<String>? patchType,
      Value<DateTime?>? requestedCheckInAt,
      Value<DateTime?>? requestedCheckOutAt,
      Value<String>? reason,
      Value<String>? status,
      Value<DateTime>? createdAt,
      Value<DateTime?>? reviewedAt}) {
    return PatchRequestsCompanion(
      id: id ?? this.id,
      day: day ?? this.day,
      patchType: patchType ?? this.patchType,
      requestedCheckInAt: requestedCheckInAt ?? this.requestedCheckInAt,
      requestedCheckOutAt: requestedCheckOutAt ?? this.requestedCheckOutAt,
      reason: reason ?? this.reason,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      reviewedAt: reviewedAt ?? this.reviewedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (day.present) {
      map['day'] = Variable<DateTime>(day.value);
    }
    if (patchType.present) {
      map['patch_type'] = Variable<String>(patchType.value);
    }
    if (requestedCheckInAt.present) {
      map['requested_check_in_at'] =
          Variable<DateTime>(requestedCheckInAt.value);
    }
    if (requestedCheckOutAt.present) {
      map['requested_check_out_at'] =
          Variable<DateTime>(requestedCheckOutAt.value);
    }
    if (reason.present) {
      map['reason'] = Variable<String>(reason.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (reviewedAt.present) {
      map['reviewed_at'] = Variable<DateTime>(reviewedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PatchRequestsCompanion(')
          ..write('id: $id, ')
          ..write('day: $day, ')
          ..write('patchType: $patchType, ')
          ..write('requestedCheckInAt: $requestedCheckInAt, ')
          ..write('requestedCheckOutAt: $requestedCheckOutAt, ')
          ..write('reason: $reason, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt, ')
          ..write('reviewedAt: $reviewedAt')
          ..write(')'))
        .toString();
  }
}

class $GeofenceDailyStatesTable extends GeofenceDailyStates
    with TableInfo<$GeofenceDailyStatesTable, GeofenceDailyState> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GeofenceDailyStatesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _dayMeta = const VerificationMeta('day');
  @override
  late final GeneratedColumn<DateTime> day = GeneratedColumn<DateTime>(
      'day', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'));
  static const VerificationMeta _wasInsideMeta =
      const VerificationMeta('wasInside');
  @override
  late final GeneratedColumn<bool> wasInside = GeneratedColumn<bool>(
      'was_inside', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("was_inside" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _triggeredMeta =
      const VerificationMeta('triggered');
  @override
  late final GeneratedColumn<bool> triggered = GeneratedColumn<bool>(
      'triggered', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("triggered" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _triggeredCountMeta =
      const VerificationMeta('triggeredCount');
  @override
  late final GeneratedColumn<int> triggeredCount = GeneratedColumn<int>(
      'triggered_count', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _lastTriggeredAtMeta =
      const VerificationMeta('lastTriggeredAt');
  @override
  late final GeneratedColumn<DateTime> lastTriggeredAt =
      GeneratedColumn<DateTime>('last_triggered_at', aliasedName, true,
          type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        day,
        wasInside,
        triggered,
        triggeredCount,
        lastTriggeredAt,
        updatedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'geofence_daily_states';
  @override
  VerificationContext validateIntegrity(Insertable<GeofenceDailyState> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('day')) {
      context.handle(
          _dayMeta, day.isAcceptableOrUnknown(data['day']!, _dayMeta));
    } else if (isInserting) {
      context.missing(_dayMeta);
    }
    if (data.containsKey('was_inside')) {
      context.handle(_wasInsideMeta,
          wasInside.isAcceptableOrUnknown(data['was_inside']!, _wasInsideMeta));
    }
    if (data.containsKey('triggered')) {
      context.handle(_triggeredMeta,
          triggered.isAcceptableOrUnknown(data['triggered']!, _triggeredMeta));
    }
    if (data.containsKey('triggered_count')) {
      context.handle(
          _triggeredCountMeta,
          triggeredCount.isAcceptableOrUnknown(
              data['triggered_count']!, _triggeredCountMeta));
    }
    if (data.containsKey('last_triggered_at')) {
      context.handle(
          _lastTriggeredAtMeta,
          lastTriggeredAt.isAcceptableOrUnknown(
              data['last_triggered_at']!, _lastTriggeredAtMeta));
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
  GeofenceDailyState map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return GeofenceDailyState(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      day: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}day'])!,
      wasInside: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}was_inside'])!,
      triggered: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}triggered'])!,
      triggeredCount: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}triggered_count'])!,
      lastTriggeredAt: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}last_triggered_at']),
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $GeofenceDailyStatesTable createAlias(String alias) {
    return $GeofenceDailyStatesTable(attachedDatabase, alias);
  }
}

class GeofenceDailyState extends DataClass
    implements Insertable<GeofenceDailyState> {
  final int id;
  final DateTime day;
  final bool wasInside;
  final bool triggered;
  final int triggeredCount;
  final DateTime? lastTriggeredAt;
  final DateTime updatedAt;
  const GeofenceDailyState(
      {required this.id,
      required this.day,
      required this.wasInside,
      required this.triggered,
      required this.triggeredCount,
      this.lastTriggeredAt,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['day'] = Variable<DateTime>(day);
    map['was_inside'] = Variable<bool>(wasInside);
    map['triggered'] = Variable<bool>(triggered);
    map['triggered_count'] = Variable<int>(triggeredCount);
    if (!nullToAbsent || lastTriggeredAt != null) {
      map['last_triggered_at'] = Variable<DateTime>(lastTriggeredAt);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  GeofenceDailyStatesCompanion toCompanion(bool nullToAbsent) {
    return GeofenceDailyStatesCompanion(
      id: Value(id),
      day: Value(day),
      wasInside: Value(wasInside),
      triggered: Value(triggered),
      triggeredCount: Value(triggeredCount),
      lastTriggeredAt: lastTriggeredAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastTriggeredAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory GeofenceDailyState.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return GeofenceDailyState(
      id: serializer.fromJson<int>(json['id']),
      day: serializer.fromJson<DateTime>(json['day']),
      wasInside: serializer.fromJson<bool>(json['wasInside']),
      triggered: serializer.fromJson<bool>(json['triggered']),
      triggeredCount: serializer.fromJson<int>(json['triggeredCount']),
      lastTriggeredAt: serializer.fromJson<DateTime?>(json['lastTriggeredAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'day': serializer.toJson<DateTime>(day),
      'wasInside': serializer.toJson<bool>(wasInside),
      'triggered': serializer.toJson<bool>(triggered),
      'triggeredCount': serializer.toJson<int>(triggeredCount),
      'lastTriggeredAt': serializer.toJson<DateTime?>(lastTriggeredAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  GeofenceDailyState copyWith(
          {int? id,
          DateTime? day,
          bool? wasInside,
          bool? triggered,
          int? triggeredCount,
          Value<DateTime?> lastTriggeredAt = const Value.absent(),
          DateTime? updatedAt}) =>
      GeofenceDailyState(
        id: id ?? this.id,
        day: day ?? this.day,
        wasInside: wasInside ?? this.wasInside,
        triggered: triggered ?? this.triggered,
        triggeredCount: triggeredCount ?? this.triggeredCount,
        lastTriggeredAt: lastTriggeredAt.present
            ? lastTriggeredAt.value
            : this.lastTriggeredAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  GeofenceDailyState copyWithCompanion(GeofenceDailyStatesCompanion data) {
    return GeofenceDailyState(
      id: data.id.present ? data.id.value : this.id,
      day: data.day.present ? data.day.value : this.day,
      wasInside: data.wasInside.present ? data.wasInside.value : this.wasInside,
      triggered: data.triggered.present ? data.triggered.value : this.triggered,
      triggeredCount: data.triggeredCount.present
          ? data.triggeredCount.value
          : this.triggeredCount,
      lastTriggeredAt: data.lastTriggeredAt.present
          ? data.lastTriggeredAt.value
          : this.lastTriggeredAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('GeofenceDailyState(')
          ..write('id: $id, ')
          ..write('day: $day, ')
          ..write('wasInside: $wasInside, ')
          ..write('triggered: $triggered, ')
          ..write('triggeredCount: $triggeredCount, ')
          ..write('lastTriggeredAt: $lastTriggeredAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, day, wasInside, triggered, triggeredCount,
      lastTriggeredAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GeofenceDailyState &&
          other.id == this.id &&
          other.day == this.day &&
          other.wasInside == this.wasInside &&
          other.triggered == this.triggered &&
          other.triggeredCount == this.triggeredCount &&
          other.lastTriggeredAt == this.lastTriggeredAt &&
          other.updatedAt == this.updatedAt);
}

class GeofenceDailyStatesCompanion extends UpdateCompanion<GeofenceDailyState> {
  final Value<int> id;
  final Value<DateTime> day;
  final Value<bool> wasInside;
  final Value<bool> triggered;
  final Value<int> triggeredCount;
  final Value<DateTime?> lastTriggeredAt;
  final Value<DateTime> updatedAt;
  const GeofenceDailyStatesCompanion({
    this.id = const Value.absent(),
    this.day = const Value.absent(),
    this.wasInside = const Value.absent(),
    this.triggered = const Value.absent(),
    this.triggeredCount = const Value.absent(),
    this.lastTriggeredAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  GeofenceDailyStatesCompanion.insert({
    this.id = const Value.absent(),
    required DateTime day,
    this.wasInside = const Value.absent(),
    this.triggered = const Value.absent(),
    this.triggeredCount = const Value.absent(),
    this.lastTriggeredAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  }) : day = Value(day);
  static Insertable<GeofenceDailyState> custom({
    Expression<int>? id,
    Expression<DateTime>? day,
    Expression<bool>? wasInside,
    Expression<bool>? triggered,
    Expression<int>? triggeredCount,
    Expression<DateTime>? lastTriggeredAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (day != null) 'day': day,
      if (wasInside != null) 'was_inside': wasInside,
      if (triggered != null) 'triggered': triggered,
      if (triggeredCount != null) 'triggered_count': triggeredCount,
      if (lastTriggeredAt != null) 'last_triggered_at': lastTriggeredAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  GeofenceDailyStatesCompanion copyWith(
      {Value<int>? id,
      Value<DateTime>? day,
      Value<bool>? wasInside,
      Value<bool>? triggered,
      Value<int>? triggeredCount,
      Value<DateTime?>? lastTriggeredAt,
      Value<DateTime>? updatedAt}) {
    return GeofenceDailyStatesCompanion(
      id: id ?? this.id,
      day: day ?? this.day,
      wasInside: wasInside ?? this.wasInside,
      triggered: triggered ?? this.triggered,
      triggeredCount: triggeredCount ?? this.triggeredCount,
      lastTriggeredAt: lastTriggeredAt ?? this.lastTriggeredAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (day.present) {
      map['day'] = Variable<DateTime>(day.value);
    }
    if (wasInside.present) {
      map['was_inside'] = Variable<bool>(wasInside.value);
    }
    if (triggered.present) {
      map['triggered'] = Variable<bool>(triggered.value);
    }
    if (triggeredCount.present) {
      map['triggered_count'] = Variable<int>(triggeredCount.value);
    }
    if (lastTriggeredAt.present) {
      map['last_triggered_at'] = Variable<DateTime>(lastTriggeredAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GeofenceDailyStatesCompanion(')
          ..write('id: $id, ')
          ..write('day: $day, ')
          ..write('wasInside: $wasInside, ')
          ..write('triggered: $triggered, ')
          ..write('triggeredCount: $triggeredCount, ')
          ..write('lastTriggeredAt: $lastTriggeredAt, ')
          ..write('updatedAt: $updatedAt')
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
  late final $AttendanceRulesTable attendanceRules =
      $AttendanceRulesTable(this);
  late final $AttendanceRecordsTable attendanceRecords =
      $AttendanceRecordsTable(this);
  late final $PatchRequestsTable patchRequests = $PatchRequestsTable(this);
  late final $GeofenceDailyStatesTable geofenceDailyStates =
      $GeofenceDailyStatesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
        products,
        batches,
        orders,
        orderItems,
        stockMovements,
        attendanceRules,
        attendanceRecords,
        patchRequests,
        geofenceDailyStates
      ];
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
  Value<bool> isException,
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
  Value<bool> isException,
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

  ColumnFilters<bool> get isException => $composableBuilder(
      column: $table.isException, builder: (column) => ColumnFilters(column));

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

  ColumnOrderings<bool> get isException => $composableBuilder(
      column: $table.isException, builder: (column) => ColumnOrderings(column));

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

  GeneratedColumn<bool> get isException => $composableBuilder(
      column: $table.isException, builder: (column) => column);

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
            Value<bool> isException = const Value.absent(),
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
            isException: isException,
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
            Value<bool> isException = const Value.absent(),
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
            isException: isException,
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
typedef $$AttendanceRulesTableCreateCompanionBuilder = AttendanceRulesCompanion
    Function({
  Value<int> id,
  Value<String> workStartTime,
  Value<String> workEndTime,
  Value<int> lateGraceMinutes,
  Value<String> weekendType,
  Value<int> overtimeRoundingMinutes,
  Value<double?> officeLat,
  Value<double?> officeLng,
  Value<int> officeRadiusMeters,
  Value<bool> geofenceEnabled,
  Value<bool> checkinReminderEnabled,
  Value<bool> checkoutReminderEnabled,
  Value<DateTime> updatedAt,
});
typedef $$AttendanceRulesTableUpdateCompanionBuilder = AttendanceRulesCompanion
    Function({
  Value<int> id,
  Value<String> workStartTime,
  Value<String> workEndTime,
  Value<int> lateGraceMinutes,
  Value<String> weekendType,
  Value<int> overtimeRoundingMinutes,
  Value<double?> officeLat,
  Value<double?> officeLng,
  Value<int> officeRadiusMeters,
  Value<bool> geofenceEnabled,
  Value<bool> checkinReminderEnabled,
  Value<bool> checkoutReminderEnabled,
  Value<DateTime> updatedAt,
});

class $$AttendanceRulesTableFilterComposer
    extends Composer<_$AppDatabase, $AttendanceRulesTable> {
  $$AttendanceRulesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get workStartTime => $composableBuilder(
      column: $table.workStartTime, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get workEndTime => $composableBuilder(
      column: $table.workEndTime, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get lateGraceMinutes => $composableBuilder(
      column: $table.lateGraceMinutes,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get weekendType => $composableBuilder(
      column: $table.weekendType, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get overtimeRoundingMinutes => $composableBuilder(
      column: $table.overtimeRoundingMinutes,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get officeLat => $composableBuilder(
      column: $table.officeLat, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get officeLng => $composableBuilder(
      column: $table.officeLng, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get officeRadiusMeters => $composableBuilder(
      column: $table.officeRadiusMeters,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get geofenceEnabled => $composableBuilder(
      column: $table.geofenceEnabled,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get checkinReminderEnabled => $composableBuilder(
      column: $table.checkinReminderEnabled,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get checkoutReminderEnabled => $composableBuilder(
      column: $table.checkoutReminderEnabled,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$AttendanceRulesTableOrderingComposer
    extends Composer<_$AppDatabase, $AttendanceRulesTable> {
  $$AttendanceRulesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get workStartTime => $composableBuilder(
      column: $table.workStartTime,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get workEndTime => $composableBuilder(
      column: $table.workEndTime, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get lateGraceMinutes => $composableBuilder(
      column: $table.lateGraceMinutes,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get weekendType => $composableBuilder(
      column: $table.weekendType, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get overtimeRoundingMinutes => $composableBuilder(
      column: $table.overtimeRoundingMinutes,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get officeLat => $composableBuilder(
      column: $table.officeLat, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get officeLng => $composableBuilder(
      column: $table.officeLng, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get officeRadiusMeters => $composableBuilder(
      column: $table.officeRadiusMeters,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get geofenceEnabled => $composableBuilder(
      column: $table.geofenceEnabled,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get checkinReminderEnabled => $composableBuilder(
      column: $table.checkinReminderEnabled,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get checkoutReminderEnabled => $composableBuilder(
      column: $table.checkoutReminderEnabled,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$AttendanceRulesTableAnnotationComposer
    extends Composer<_$AppDatabase, $AttendanceRulesTable> {
  $$AttendanceRulesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get workStartTime => $composableBuilder(
      column: $table.workStartTime, builder: (column) => column);

  GeneratedColumn<String> get workEndTime => $composableBuilder(
      column: $table.workEndTime, builder: (column) => column);

  GeneratedColumn<int> get lateGraceMinutes => $composableBuilder(
      column: $table.lateGraceMinutes, builder: (column) => column);

  GeneratedColumn<String> get weekendType => $composableBuilder(
      column: $table.weekendType, builder: (column) => column);

  GeneratedColumn<int> get overtimeRoundingMinutes => $composableBuilder(
      column: $table.overtimeRoundingMinutes, builder: (column) => column);

  GeneratedColumn<double> get officeLat =>
      $composableBuilder(column: $table.officeLat, builder: (column) => column);

  GeneratedColumn<double> get officeLng =>
      $composableBuilder(column: $table.officeLng, builder: (column) => column);

  GeneratedColumn<int> get officeRadiusMeters => $composableBuilder(
      column: $table.officeRadiusMeters, builder: (column) => column);

  GeneratedColumn<bool> get geofenceEnabled => $composableBuilder(
      column: $table.geofenceEnabled, builder: (column) => column);

  GeneratedColumn<bool> get checkinReminderEnabled => $composableBuilder(
      column: $table.checkinReminderEnabled, builder: (column) => column);

  GeneratedColumn<bool> get checkoutReminderEnabled => $composableBuilder(
      column: $table.checkoutReminderEnabled, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$AttendanceRulesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $AttendanceRulesTable,
    AttendanceRule,
    $$AttendanceRulesTableFilterComposer,
    $$AttendanceRulesTableOrderingComposer,
    $$AttendanceRulesTableAnnotationComposer,
    $$AttendanceRulesTableCreateCompanionBuilder,
    $$AttendanceRulesTableUpdateCompanionBuilder,
    (
      AttendanceRule,
      BaseReferences<_$AppDatabase, $AttendanceRulesTable, AttendanceRule>
    ),
    AttendanceRule,
    PrefetchHooks Function()> {
  $$AttendanceRulesTableTableManager(
      _$AppDatabase db, $AttendanceRulesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AttendanceRulesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AttendanceRulesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AttendanceRulesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> workStartTime = const Value.absent(),
            Value<String> workEndTime = const Value.absent(),
            Value<int> lateGraceMinutes = const Value.absent(),
            Value<String> weekendType = const Value.absent(),
            Value<int> overtimeRoundingMinutes = const Value.absent(),
            Value<double?> officeLat = const Value.absent(),
            Value<double?> officeLng = const Value.absent(),
            Value<int> officeRadiusMeters = const Value.absent(),
            Value<bool> geofenceEnabled = const Value.absent(),
            Value<bool> checkinReminderEnabled = const Value.absent(),
            Value<bool> checkoutReminderEnabled = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
          }) =>
              AttendanceRulesCompanion(
            id: id,
            workStartTime: workStartTime,
            workEndTime: workEndTime,
            lateGraceMinutes: lateGraceMinutes,
            weekendType: weekendType,
            overtimeRoundingMinutes: overtimeRoundingMinutes,
            officeLat: officeLat,
            officeLng: officeLng,
            officeRadiusMeters: officeRadiusMeters,
            geofenceEnabled: geofenceEnabled,
            checkinReminderEnabled: checkinReminderEnabled,
            checkoutReminderEnabled: checkoutReminderEnabled,
            updatedAt: updatedAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> workStartTime = const Value.absent(),
            Value<String> workEndTime = const Value.absent(),
            Value<int> lateGraceMinutes = const Value.absent(),
            Value<String> weekendType = const Value.absent(),
            Value<int> overtimeRoundingMinutes = const Value.absent(),
            Value<double?> officeLat = const Value.absent(),
            Value<double?> officeLng = const Value.absent(),
            Value<int> officeRadiusMeters = const Value.absent(),
            Value<bool> geofenceEnabled = const Value.absent(),
            Value<bool> checkinReminderEnabled = const Value.absent(),
            Value<bool> checkoutReminderEnabled = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
          }) =>
              AttendanceRulesCompanion.insert(
            id: id,
            workStartTime: workStartTime,
            workEndTime: workEndTime,
            lateGraceMinutes: lateGraceMinutes,
            weekendType: weekendType,
            overtimeRoundingMinutes: overtimeRoundingMinutes,
            officeLat: officeLat,
            officeLng: officeLng,
            officeRadiusMeters: officeRadiusMeters,
            geofenceEnabled: geofenceEnabled,
            checkinReminderEnabled: checkinReminderEnabled,
            checkoutReminderEnabled: checkoutReminderEnabled,
            updatedAt: updatedAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$AttendanceRulesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $AttendanceRulesTable,
    AttendanceRule,
    $$AttendanceRulesTableFilterComposer,
    $$AttendanceRulesTableOrderingComposer,
    $$AttendanceRulesTableAnnotationComposer,
    $$AttendanceRulesTableCreateCompanionBuilder,
    $$AttendanceRulesTableUpdateCompanionBuilder,
    (
      AttendanceRule,
      BaseReferences<_$AppDatabase, $AttendanceRulesTable, AttendanceRule>
    ),
    AttendanceRule,
    PrefetchHooks Function()>;
typedef $$AttendanceRecordsTableCreateCompanionBuilder
    = AttendanceRecordsCompanion Function({
  Value<int> id,
  required DateTime day,
  Value<DateTime?> checkInAt,
  Value<DateTime?> checkOutAt,
  Value<bool> isWorkday,
  Value<bool> isLate,
  Value<bool> isEarlyLeave,
  Value<bool> isAbsent,
  Value<bool> isLeave,
  Value<bool> isException,
  Value<bool> needsPatch,
  Value<bool> patched,
  Value<int> overtimeMinutesRaw,
  Value<int> leaveMinutes,
  Value<double> overtimeHoursRounded,
  Value<String> source,
  Value<String?> note,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
});
typedef $$AttendanceRecordsTableUpdateCompanionBuilder
    = AttendanceRecordsCompanion Function({
  Value<int> id,
  Value<DateTime> day,
  Value<DateTime?> checkInAt,
  Value<DateTime?> checkOutAt,
  Value<bool> isWorkday,
  Value<bool> isLate,
  Value<bool> isEarlyLeave,
  Value<bool> isAbsent,
  Value<bool> isLeave,
  Value<bool> isException,
  Value<bool> needsPatch,
  Value<bool> patched,
  Value<int> overtimeMinutesRaw,
  Value<int> leaveMinutes,
  Value<double> overtimeHoursRounded,
  Value<String> source,
  Value<String?> note,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
});

class $$AttendanceRecordsTableFilterComposer
    extends Composer<_$AppDatabase, $AttendanceRecordsTable> {
  $$AttendanceRecordsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get day => $composableBuilder(
      column: $table.day, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get checkInAt => $composableBuilder(
      column: $table.checkInAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get checkOutAt => $composableBuilder(
      column: $table.checkOutAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isWorkday => $composableBuilder(
      column: $table.isWorkday, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isLate => $composableBuilder(
      column: $table.isLate, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isEarlyLeave => $composableBuilder(
      column: $table.isEarlyLeave, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isAbsent => $composableBuilder(
      column: $table.isAbsent, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isLeave => $composableBuilder(
      column: $table.isLeave, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isException => $composableBuilder(
      column: $table.isException, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get needsPatch => $composableBuilder(
      column: $table.needsPatch, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get patched => $composableBuilder(
      column: $table.patched, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get overtimeMinutesRaw => $composableBuilder(
      column: $table.overtimeMinutesRaw,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get leaveMinutes => $composableBuilder(
      column: $table.leaveMinutes, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get overtimeHoursRounded => $composableBuilder(
      column: $table.overtimeHoursRounded,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get source => $composableBuilder(
      column: $table.source, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get note => $composableBuilder(
      column: $table.note, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$AttendanceRecordsTableOrderingComposer
    extends Composer<_$AppDatabase, $AttendanceRecordsTable> {
  $$AttendanceRecordsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get day => $composableBuilder(
      column: $table.day, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get checkInAt => $composableBuilder(
      column: $table.checkInAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get checkOutAt => $composableBuilder(
      column: $table.checkOutAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isWorkday => $composableBuilder(
      column: $table.isWorkday, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isLate => $composableBuilder(
      column: $table.isLate, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isEarlyLeave => $composableBuilder(
      column: $table.isEarlyLeave,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isAbsent => $composableBuilder(
      column: $table.isAbsent, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isLeave => $composableBuilder(
      column: $table.isLeave, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isException => $composableBuilder(
      column: $table.isException, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get needsPatch => $composableBuilder(
      column: $table.needsPatch, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get patched => $composableBuilder(
      column: $table.patched, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get overtimeMinutesRaw => $composableBuilder(
      column: $table.overtimeMinutesRaw,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get leaveMinutes => $composableBuilder(
      column: $table.leaveMinutes,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get overtimeHoursRounded => $composableBuilder(
      column: $table.overtimeHoursRounded,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get source => $composableBuilder(
      column: $table.source, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get note => $composableBuilder(
      column: $table.note, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$AttendanceRecordsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AttendanceRecordsTable> {
  $$AttendanceRecordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get day =>
      $composableBuilder(column: $table.day, builder: (column) => column);

  GeneratedColumn<DateTime> get checkInAt =>
      $composableBuilder(column: $table.checkInAt, builder: (column) => column);

  GeneratedColumn<DateTime> get checkOutAt => $composableBuilder(
      column: $table.checkOutAt, builder: (column) => column);

  GeneratedColumn<bool> get isWorkday =>
      $composableBuilder(column: $table.isWorkday, builder: (column) => column);

  GeneratedColumn<bool> get isLate =>
      $composableBuilder(column: $table.isLate, builder: (column) => column);

  GeneratedColumn<bool> get isEarlyLeave => $composableBuilder(
      column: $table.isEarlyLeave, builder: (column) => column);

  GeneratedColumn<bool> get isAbsent =>
      $composableBuilder(column: $table.isAbsent, builder: (column) => column);

  GeneratedColumn<bool> get isLeave =>
      $composableBuilder(column: $table.isLeave, builder: (column) => column);

  GeneratedColumn<bool> get isException => $composableBuilder(
      column: $table.isException, builder: (column) => column);

  GeneratedColumn<bool> get needsPatch => $composableBuilder(
      column: $table.needsPatch, builder: (column) => column);

  GeneratedColumn<bool> get patched =>
      $composableBuilder(column: $table.patched, builder: (column) => column);

  GeneratedColumn<int> get overtimeMinutesRaw => $composableBuilder(
      column: $table.overtimeMinutesRaw, builder: (column) => column);

  GeneratedColumn<int> get leaveMinutes => $composableBuilder(
      column: $table.leaveMinutes, builder: (column) => column);

  GeneratedColumn<double> get overtimeHoursRounded => $composableBuilder(
      column: $table.overtimeHoursRounded, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$AttendanceRecordsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $AttendanceRecordsTable,
    AttendanceRecord,
    $$AttendanceRecordsTableFilterComposer,
    $$AttendanceRecordsTableOrderingComposer,
    $$AttendanceRecordsTableAnnotationComposer,
    $$AttendanceRecordsTableCreateCompanionBuilder,
    $$AttendanceRecordsTableUpdateCompanionBuilder,
    (
      AttendanceRecord,
      BaseReferences<_$AppDatabase, $AttendanceRecordsTable, AttendanceRecord>
    ),
    AttendanceRecord,
    PrefetchHooks Function()> {
  $$AttendanceRecordsTableTableManager(
      _$AppDatabase db, $AttendanceRecordsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AttendanceRecordsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AttendanceRecordsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AttendanceRecordsTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<DateTime> day = const Value.absent(),
            Value<DateTime?> checkInAt = const Value.absent(),
            Value<DateTime?> checkOutAt = const Value.absent(),
            Value<bool> isWorkday = const Value.absent(),
            Value<bool> isLate = const Value.absent(),
            Value<bool> isEarlyLeave = const Value.absent(),
            Value<bool> isAbsent = const Value.absent(),
            Value<bool> isLeave = const Value.absent(),
            Value<bool> isException = const Value.absent(),
            Value<bool> needsPatch = const Value.absent(),
            Value<bool> patched = const Value.absent(),
            Value<int> overtimeMinutesRaw = const Value.absent(),
            Value<int> leaveMinutes = const Value.absent(),
            Value<double> overtimeHoursRounded = const Value.absent(),
            Value<String> source = const Value.absent(),
            Value<String?> note = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
          }) =>
              AttendanceRecordsCompanion(
            id: id,
            day: day,
            checkInAt: checkInAt,
            checkOutAt: checkOutAt,
            isWorkday: isWorkday,
            isLate: isLate,
            isEarlyLeave: isEarlyLeave,
            isAbsent: isAbsent,
            isLeave: isLeave,
            isException: isException,
            needsPatch: needsPatch,
            patched: patched,
            overtimeMinutesRaw: overtimeMinutesRaw,
            leaveMinutes: leaveMinutes,
            overtimeHoursRounded: overtimeHoursRounded,
            source: source,
            note: note,
            createdAt: createdAt,
            updatedAt: updatedAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required DateTime day,
            Value<DateTime?> checkInAt = const Value.absent(),
            Value<DateTime?> checkOutAt = const Value.absent(),
            Value<bool> isWorkday = const Value.absent(),
            Value<bool> isLate = const Value.absent(),
            Value<bool> isEarlyLeave = const Value.absent(),
            Value<bool> isAbsent = const Value.absent(),
            Value<bool> isLeave = const Value.absent(),
            Value<bool> isException = const Value.absent(),
            Value<bool> needsPatch = const Value.absent(),
            Value<bool> patched = const Value.absent(),
            Value<int> overtimeMinutesRaw = const Value.absent(),
            Value<int> leaveMinutes = const Value.absent(),
            Value<double> overtimeHoursRounded = const Value.absent(),
            Value<String> source = const Value.absent(),
            Value<String?> note = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
          }) =>
              AttendanceRecordsCompanion.insert(
            id: id,
            day: day,
            checkInAt: checkInAt,
            checkOutAt: checkOutAt,
            isWorkday: isWorkday,
            isLate: isLate,
            isEarlyLeave: isEarlyLeave,
            isAbsent: isAbsent,
            isLeave: isLeave,
            isException: isException,
            needsPatch: needsPatch,
            patched: patched,
            overtimeMinutesRaw: overtimeMinutesRaw,
            leaveMinutes: leaveMinutes,
            overtimeHoursRounded: overtimeHoursRounded,
            source: source,
            note: note,
            createdAt: createdAt,
            updatedAt: updatedAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$AttendanceRecordsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $AttendanceRecordsTable,
    AttendanceRecord,
    $$AttendanceRecordsTableFilterComposer,
    $$AttendanceRecordsTableOrderingComposer,
    $$AttendanceRecordsTableAnnotationComposer,
    $$AttendanceRecordsTableCreateCompanionBuilder,
    $$AttendanceRecordsTableUpdateCompanionBuilder,
    (
      AttendanceRecord,
      BaseReferences<_$AppDatabase, $AttendanceRecordsTable, AttendanceRecord>
    ),
    AttendanceRecord,
    PrefetchHooks Function()>;
typedef $$PatchRequestsTableCreateCompanionBuilder = PatchRequestsCompanion
    Function({
  Value<int> id,
  required DateTime day,
  required String patchType,
  Value<DateTime?> requestedCheckInAt,
  Value<DateTime?> requestedCheckOutAt,
  Value<String> reason,
  Value<String> status,
  Value<DateTime> createdAt,
  Value<DateTime?> reviewedAt,
});
typedef $$PatchRequestsTableUpdateCompanionBuilder = PatchRequestsCompanion
    Function({
  Value<int> id,
  Value<DateTime> day,
  Value<String> patchType,
  Value<DateTime?> requestedCheckInAt,
  Value<DateTime?> requestedCheckOutAt,
  Value<String> reason,
  Value<String> status,
  Value<DateTime> createdAt,
  Value<DateTime?> reviewedAt,
});

class $$PatchRequestsTableFilterComposer
    extends Composer<_$AppDatabase, $PatchRequestsTable> {
  $$PatchRequestsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get day => $composableBuilder(
      column: $table.day, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get patchType => $composableBuilder(
      column: $table.patchType, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get requestedCheckInAt => $composableBuilder(
      column: $table.requestedCheckInAt,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get requestedCheckOutAt => $composableBuilder(
      column: $table.requestedCheckOutAt,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get reason => $composableBuilder(
      column: $table.reason, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get reviewedAt => $composableBuilder(
      column: $table.reviewedAt, builder: (column) => ColumnFilters(column));
}

class $$PatchRequestsTableOrderingComposer
    extends Composer<_$AppDatabase, $PatchRequestsTable> {
  $$PatchRequestsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get day => $composableBuilder(
      column: $table.day, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get patchType => $composableBuilder(
      column: $table.patchType, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get requestedCheckInAt => $composableBuilder(
      column: $table.requestedCheckInAt,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get requestedCheckOutAt => $composableBuilder(
      column: $table.requestedCheckOutAt,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get reason => $composableBuilder(
      column: $table.reason, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get reviewedAt => $composableBuilder(
      column: $table.reviewedAt, builder: (column) => ColumnOrderings(column));
}

class $$PatchRequestsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PatchRequestsTable> {
  $$PatchRequestsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get day =>
      $composableBuilder(column: $table.day, builder: (column) => column);

  GeneratedColumn<String> get patchType =>
      $composableBuilder(column: $table.patchType, builder: (column) => column);

  GeneratedColumn<DateTime> get requestedCheckInAt => $composableBuilder(
      column: $table.requestedCheckInAt, builder: (column) => column);

  GeneratedColumn<DateTime> get requestedCheckOutAt => $composableBuilder(
      column: $table.requestedCheckOutAt, builder: (column) => column);

  GeneratedColumn<String> get reason =>
      $composableBuilder(column: $table.reason, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get reviewedAt => $composableBuilder(
      column: $table.reviewedAt, builder: (column) => column);
}

class $$PatchRequestsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $PatchRequestsTable,
    PatchRequest,
    $$PatchRequestsTableFilterComposer,
    $$PatchRequestsTableOrderingComposer,
    $$PatchRequestsTableAnnotationComposer,
    $$PatchRequestsTableCreateCompanionBuilder,
    $$PatchRequestsTableUpdateCompanionBuilder,
    (
      PatchRequest,
      BaseReferences<_$AppDatabase, $PatchRequestsTable, PatchRequest>
    ),
    PatchRequest,
    PrefetchHooks Function()> {
  $$PatchRequestsTableTableManager(_$AppDatabase db, $PatchRequestsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PatchRequestsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PatchRequestsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PatchRequestsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<DateTime> day = const Value.absent(),
            Value<String> patchType = const Value.absent(),
            Value<DateTime?> requestedCheckInAt = const Value.absent(),
            Value<DateTime?> requestedCheckOutAt = const Value.absent(),
            Value<String> reason = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime?> reviewedAt = const Value.absent(),
          }) =>
              PatchRequestsCompanion(
            id: id,
            day: day,
            patchType: patchType,
            requestedCheckInAt: requestedCheckInAt,
            requestedCheckOutAt: requestedCheckOutAt,
            reason: reason,
            status: status,
            createdAt: createdAt,
            reviewedAt: reviewedAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required DateTime day,
            required String patchType,
            Value<DateTime?> requestedCheckInAt = const Value.absent(),
            Value<DateTime?> requestedCheckOutAt = const Value.absent(),
            Value<String> reason = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime?> reviewedAt = const Value.absent(),
          }) =>
              PatchRequestsCompanion.insert(
            id: id,
            day: day,
            patchType: patchType,
            requestedCheckInAt: requestedCheckInAt,
            requestedCheckOutAt: requestedCheckOutAt,
            reason: reason,
            status: status,
            createdAt: createdAt,
            reviewedAt: reviewedAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$PatchRequestsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $PatchRequestsTable,
    PatchRequest,
    $$PatchRequestsTableFilterComposer,
    $$PatchRequestsTableOrderingComposer,
    $$PatchRequestsTableAnnotationComposer,
    $$PatchRequestsTableCreateCompanionBuilder,
    $$PatchRequestsTableUpdateCompanionBuilder,
    (
      PatchRequest,
      BaseReferences<_$AppDatabase, $PatchRequestsTable, PatchRequest>
    ),
    PatchRequest,
    PrefetchHooks Function()>;
typedef $$GeofenceDailyStatesTableCreateCompanionBuilder
    = GeofenceDailyStatesCompanion Function({
  Value<int> id,
  required DateTime day,
  Value<bool> wasInside,
  Value<bool> triggered,
  Value<int> triggeredCount,
  Value<DateTime?> lastTriggeredAt,
  Value<DateTime> updatedAt,
});
typedef $$GeofenceDailyStatesTableUpdateCompanionBuilder
    = GeofenceDailyStatesCompanion Function({
  Value<int> id,
  Value<DateTime> day,
  Value<bool> wasInside,
  Value<bool> triggered,
  Value<int> triggeredCount,
  Value<DateTime?> lastTriggeredAt,
  Value<DateTime> updatedAt,
});

class $$GeofenceDailyStatesTableFilterComposer
    extends Composer<_$AppDatabase, $GeofenceDailyStatesTable> {
  $$GeofenceDailyStatesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get day => $composableBuilder(
      column: $table.day, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get wasInside => $composableBuilder(
      column: $table.wasInside, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get triggered => $composableBuilder(
      column: $table.triggered, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get triggeredCount => $composableBuilder(
      column: $table.triggeredCount,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get lastTriggeredAt => $composableBuilder(
      column: $table.lastTriggeredAt,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$GeofenceDailyStatesTableOrderingComposer
    extends Composer<_$AppDatabase, $GeofenceDailyStatesTable> {
  $$GeofenceDailyStatesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get day => $composableBuilder(
      column: $table.day, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get wasInside => $composableBuilder(
      column: $table.wasInside, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get triggered => $composableBuilder(
      column: $table.triggered, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get triggeredCount => $composableBuilder(
      column: $table.triggeredCount,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get lastTriggeredAt => $composableBuilder(
      column: $table.lastTriggeredAt,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$GeofenceDailyStatesTableAnnotationComposer
    extends Composer<_$AppDatabase, $GeofenceDailyStatesTable> {
  $$GeofenceDailyStatesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get day =>
      $composableBuilder(column: $table.day, builder: (column) => column);

  GeneratedColumn<bool> get wasInside =>
      $composableBuilder(column: $table.wasInside, builder: (column) => column);

  GeneratedColumn<bool> get triggered =>
      $composableBuilder(column: $table.triggered, builder: (column) => column);

  GeneratedColumn<int> get triggeredCount => $composableBuilder(
      column: $table.triggeredCount, builder: (column) => column);

  GeneratedColumn<DateTime> get lastTriggeredAt => $composableBuilder(
      column: $table.lastTriggeredAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$GeofenceDailyStatesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $GeofenceDailyStatesTable,
    GeofenceDailyState,
    $$GeofenceDailyStatesTableFilterComposer,
    $$GeofenceDailyStatesTableOrderingComposer,
    $$GeofenceDailyStatesTableAnnotationComposer,
    $$GeofenceDailyStatesTableCreateCompanionBuilder,
    $$GeofenceDailyStatesTableUpdateCompanionBuilder,
    (
      GeofenceDailyState,
      BaseReferences<_$AppDatabase, $GeofenceDailyStatesTable,
          GeofenceDailyState>
    ),
    GeofenceDailyState,
    PrefetchHooks Function()> {
  $$GeofenceDailyStatesTableTableManager(
      _$AppDatabase db, $GeofenceDailyStatesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$GeofenceDailyStatesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$GeofenceDailyStatesTableOrderingComposer(
                  $db: db, $table: table),
          createComputedFieldComposer: () =>
              $$GeofenceDailyStatesTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<DateTime> day = const Value.absent(),
            Value<bool> wasInside = const Value.absent(),
            Value<bool> triggered = const Value.absent(),
            Value<int> triggeredCount = const Value.absent(),
            Value<DateTime?> lastTriggeredAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
          }) =>
              GeofenceDailyStatesCompanion(
            id: id,
            day: day,
            wasInside: wasInside,
            triggered: triggered,
            triggeredCount: triggeredCount,
            lastTriggeredAt: lastTriggeredAt,
            updatedAt: updatedAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required DateTime day,
            Value<bool> wasInside = const Value.absent(),
            Value<bool> triggered = const Value.absent(),
            Value<int> triggeredCount = const Value.absent(),
            Value<DateTime?> lastTriggeredAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
          }) =>
              GeofenceDailyStatesCompanion.insert(
            id: id,
            day: day,
            wasInside: wasInside,
            triggered: triggered,
            triggeredCount: triggeredCount,
            lastTriggeredAt: lastTriggeredAt,
            updatedAt: updatedAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$GeofenceDailyStatesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $GeofenceDailyStatesTable,
    GeofenceDailyState,
    $$GeofenceDailyStatesTableFilterComposer,
    $$GeofenceDailyStatesTableOrderingComposer,
    $$GeofenceDailyStatesTableAnnotationComposer,
    $$GeofenceDailyStatesTableCreateCompanionBuilder,
    $$GeofenceDailyStatesTableUpdateCompanionBuilder,
    (
      GeofenceDailyState,
      BaseReferences<_$AppDatabase, $GeofenceDailyStatesTable,
          GeofenceDailyState>
    ),
    GeofenceDailyState,
    PrefetchHooks Function()>;

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
  $$AttendanceRulesTableTableManager get attendanceRules =>
      $$AttendanceRulesTableTableManager(_db, _db.attendanceRules);
  $$AttendanceRecordsTableTableManager get attendanceRecords =>
      $$AttendanceRecordsTableTableManager(_db, _db.attendanceRecords);
  $$PatchRequestsTableTableManager get patchRequests =>
      $$PatchRequestsTableTableManager(_db, _db.patchRequests);
  $$GeofenceDailyStatesTableTableManager get geofenceDailyStates =>
      $$GeofenceDailyStatesTableTableManager(_db, _db.geofenceDailyStates);
}
