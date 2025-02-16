part of athena;

typedef ConstraintExpression = (List<Expr>, List<double>);

class PossibleStates {
  final List<Constraints> constraints;

  const PossibleStates(this.constraints);
}

/// A [Constraints] object consists of the three fundamental [Constraint]s.
class Constraints {
  DiscreteRangeConstraint discreteRangeConstraint;
  ContinuousRangeConstraint continuousRangeConstraint;
  ValueConstraint valueConstraint;
  BooleanConstraint booleanConstraint;

  Constraints({
    DiscreteRangeConstraint? discreteRangeConstraint,
    ContinuousRangeConstraint? continuousRangeConstraint,
    ValueConstraint? valueConstraint,
    BooleanConstraint? booleanConstraint,
  })  : discreteRangeConstraint =
            discreteRangeConstraint ?? DiscreteRangeConstraint(),
        continuousRangeConstraint =
            continuousRangeConstraint ?? ContinuousRangeConstraint(),
        valueConstraint = valueConstraint ?? ValueConstraint(),
        booleanConstraint = booleanConstraint ?? BooleanConstraint();

  /// For no other purpose than to be perfectly explicit, we add an empty named constructor.
  Constraints.none()
      : discreteRangeConstraint = DiscreteRangeConstraint(),
        continuousRangeConstraint = ContinuousRangeConstraint(),
        valueConstraint = ValueConstraint(),
        booleanConstraint = BooleanConstraint();

  Constraints operator +(Constraints other) {
    return Constraints(
      discreteRangeConstraint:
          discreteRangeConstraint + other.discreteRangeConstraint,
      continuousRangeConstraint:
          continuousRangeConstraint + other.continuousRangeConstraint,
      valueConstraint: valueConstraint + other.valueConstraint,
    );
  }

  Constraints operator -(Constraints other) {
    return Constraints(
      discreteRangeConstraint:
          discreteRangeConstraint + other.discreteRangeConstraint,
      continuousRangeConstraint:
          continuousRangeConstraint - other.continuousRangeConstraint,
      valueConstraint: valueConstraint - other.valueConstraint,
    );
  }

  String prettyPrint(int indent) =>
      "${' ' * indent} |- Discrete\n${discreteRangeConstraint.prettyPrint(indent + 2)}\n" +
      "${' ' * indent} |- Continuous\n${continuousRangeConstraint.prettyPrint(indent + 2)}\n" +
      "${' ' * indent} |- Value\n${valueConstraint.prettyPrint(indent + 2)}\n" +
      "${' ' * indent} |- Boolean\n${booleanConstraint.prettyPrint(indent + 2)}";
}

sealed class Constraint {
  const Constraint();

  List<Expr> union(List<Expr> a, List<Expr> b) =>
      [...a, ...b.where((expr) => !a.contains(expr))];

  /// Removes the elements in [a] that are also in [b], and further adds, to [a],
  /// the negative of the elements in [b] that are not in [a].
  /// E.g: [1, 2, 3] - [2, 3, 4] = [1, -4]
  List<Expr> subtractAndNegate(List<Expr> a, List<Expr> b) => [
        ...a.where((elemInA) => b.remove(elemInA)),
        ...b.map(
          (remainingInB) => UnaryExpr(
            operator: Token(TokenType.MINUS, lexeme: '-', line: -1),
            right: remainingInB,
          ),
        )
      ];

  String prettyPrint(int indent);
}

/// A method of merging two objects of type [T], which are usually [ConstraintExpression]s,
/// by taking the non-null values for each field.
T? takeNonNulls<T>(
  T? a,
  T? b, {
  required T Function(
    T a,
    T b,
  ) orElse,
}) {
  if (a == null && b == null) {
    return null;
  } else if (a == null) {
    return b;
  } else if (b == null) {
    return a;
  } else {
    return orElse(a, b);
  }
}

/// A method of merging two objects of type [T], which are usually [ConstraintExpression]s,
/// by taking the null values for each field.
T? takeNulls<T>(
  T? a,
  T? b, {
  required T Function(
    T a,
    T b,
  ) orElse,
}) {
  if (a == null || b == null) {
    return null;
  } else {
    return orElse(a, b);
  }
}

abstract class RangeConstraint extends Constraint {
  const RangeConstraint();
}

class DiscreteRangeConstraint extends Constraint {
  final List<ConstraintExpression> includedValues;

  const DiscreteRangeConstraint([this.includedValues = const []]);

  /// DOES append the set of values in [other] to the end of [includedValues] of [this]
  ///
  /// DOES NOT perform a union of two [DiscreteRangeConstraint]s.
  DiscreteRangeConstraint operator +(DiscreteRangeConstraint other) {
    return DiscreteRangeConstraint(
        [...includedValues, ...other.includedValues]);
  }

  @override
  String prettyPrint(int indent) =>
      "${' ' * indent} |- ${includedValues.map((expr) => expr.toString()).join(', ')}";
}

enum BoundType {
  inclusive,
  exclusive;

  BoundType union(BoundType? other) {
    if (other == null) return this;
    if (this == BoundType.inclusive || other == BoundType.inclusive) {
      return BoundType.inclusive;
    } else {
      return BoundType.exclusive;
    }
  }
}

class ContinuousRangeConstraint extends RangeConstraint {
  /// A bunch of terminals and non-terminals whose sum expresses the upper bound of the range.
  final ConstraintExpression upperBound;

  /// A bunch of terminals and non-terminals whose sum expresses the lower bound of the range.
  final ConstraintExpression lowerBound;

  final BoundType lowerBoundType;
  final BoundType upperBoundType;

  const ContinuousRangeConstraint({
    this.lowerBoundType = BoundType.exclusive,
    this.lowerBound = const ([], [-double.infinity]),
    this.upperBound = const ([], [double.infinity]),
    this.upperBoundType = BoundType.exclusive,
  });

  ContinuousRangeConstraint operator +(ContinuousRangeConstraint other) {
    final ConstraintExpression newLower = (
      union(lowerBound.$1, other.lowerBound.$1),
      [lowerBound.$2.first + other.lowerBound.$2.first],
    );

    final ConstraintExpression newUpper = (
      union(upperBound.$1, other.upperBound.$1),
      [upperBound.$2.first + other.upperBound.$2.first],
    );

    return ContinuousRangeConstraint(
      lowerBoundType: lowerBoundType.union(other.lowerBoundType),
      lowerBound: newLower,
      upperBound: newUpper,
      upperBoundType: upperBoundType.union(other.upperBoundType),
    );
  }

  ContinuousRangeConstraint operator -(ContinuousRangeConstraint other) {
    final ConstraintExpression newLower = (
      subtractAndNegate(lowerBound.$1, other.lowerBound.$1),
      [lowerBound.$2.first - other.lowerBound.$2.first],
    );

    final ConstraintExpression newUpper = (
      subtractAndNegate(upperBound.$1, other.upperBound.$1),
      [upperBound.$2.first - other.upperBound.$2.first],
    );

    return ContinuousRangeConstraint(
      lowerBoundType: lowerBoundType.union(other.lowerBoundType),
      lowerBound: newLower,
      upperBound: newUpper,
      upperBoundType: upperBoundType.union(other.upperBoundType),
    );
  }

  String prettyPrint(int indent) {
    return "${' ' * indent} |- Lower: $lowerBound, Upper: $upperBound";
  }
}

class ValueConstraint extends Constraint {
  final ConstraintExpression value;

  const ValueConstraint([this.value = const ([], [])]);

  ValueConstraint operator +(ValueConstraint other) {
    return ValueConstraint((
      union(value.$1, other.value.$1),
      [value.$2.first + other.value.$2.first],
    ));
  }

  ValueConstraint operator -(ValueConstraint other) {
    return ValueConstraint((
      subtractAndNegate(value.$1, other.value.$1),
      [value.$2.first - other.value.$2.first],
    ));
  }

  @override
  String prettyPrint(int indent) {
    final List<String> res = [];
    for (final expr in value.$1) {
      res.add("${' ' * indent}|- EXPR: ${expr.runtimeType.toString()}");
    }
    res.add("${' ' * indent} |- CONST: ${value.$2[0]}");
    return res.join('\n');
  }
}

/// Used to constrain boolean expressions. Either [whenTrue] or [whenFalse] can be empty.
/// If both are empty, the boolean constraint is considered to be unconstrained.
/// When directly creating a [BooleanConstraint], pass in the [whenTrue] constraints. The
/// [whenFalse] constraints are reserved for the [not] method, which flips the constraint conditions.
/// The 2D list structure is enforces the relationship between [Constraint]s:
/// - The outer list contains sets of [Constraint]s combined with a logical OR.
/// - The inner list represents [Constraint]s combined with a logical AND.
class BooleanConstraint extends Constraint {
  final List<List<Constraints>> whenTrue;
  final List<List<Constraints>> whenFalse;

  const BooleanConstraint(
      [this.whenTrue = const [], this.whenFalse = const []]);

  BooleanConstraint and(BooleanConstraint other) {
    return BooleanConstraint(
      [
        for (final set in whenTrue) ...[set, ...other.whenTrue]
      ],
      [
        for (final set in whenFalse) ...[set, ...other.whenFalse]
      ],
    );
  }

  BooleanConstraint or(BooleanConstraint other) {
    return BooleanConstraint(
      [...whenTrue, ...other.whenTrue],
      [...whenFalse, ...other.whenFalse],
    );
  }

  BooleanConstraint not() => BooleanConstraint(whenFalse, whenTrue);

  @override
  String prettyPrint(int indent) {
    return "${' ' * indent} |- whenTrue: ${whenTrue.map((set) => set.map((c) => c.prettyPrint(0)).join(', ')).join(' | ')}\n" +
        "${' ' * indent} |- whenFalse: ${whenFalse.map((set) => set.map((c) => c.prettyPrint(0)).join(', ')).join(' | ')}";
  }
}
