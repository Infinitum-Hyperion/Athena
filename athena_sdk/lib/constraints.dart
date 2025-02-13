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
            discreteRangeConstraint ?? DiscreteRangeConstraint(null),
        continuousRangeConstraint = continuousRangeConstraint ??
            ContinuousRangeConstraint(
              lowerBound: null,
              upperBound: null,
              lowerBoundType: null,
              upperBoundType: null,
            ),
        valueConstraint = valueConstraint ?? ValueConstraint(null),
        booleanConstraint = booleanConstraint ?? BooleanConstraint([], []);

  /// For no other purpose than to be perfectly explicit, we add an empty named constructor.
  Constraints.none()
      : discreteRangeConstraint = DiscreteRangeConstraint(null),
        continuousRangeConstraint = ContinuousRangeConstraint(
          lowerBound: null,
          upperBound: null,
          lowerBoundType: null,
          upperBoundType: null,
        ),
        valueConstraint = ValueConstraint(null),
        booleanConstraint = BooleanConstraint(const [], const []);

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
  List<Expr> subtractAndNegate(List<Expr> a, List<Expr> b) =>
      [...a, ...b.where((expr) => !a.contains(expr))];

  String prettyPrint(int indent);
}

T? mergeNulls<T>(
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

abstract class RangeConstraint extends Constraint {
  const RangeConstraint();
}

class DiscreteRangeConstraint extends Constraint {
  final ConstraintExpression? includedValues;

  const DiscreteRangeConstraint(this.includedValues);

  /// Performs a union of two [DiscreteRangeConstraint]s.
  DiscreteRangeConstraint operator +(DiscreteRangeConstraint other) {
    return DiscreteRangeConstraint(
      mergeNulls(includedValues, other.includedValues,
          orElse: (a, b) => (
                union(a.$1, b.$1),
                [...a.$2, ...b.$2],
              )),
    );
  }

  @override
  String prettyPrint(int indent) {
    return includedValues != null
        ? "${' ' * indent} |- ${includedValues!.$1.map((expr) => expr.runtimeType).join(', ')}"
        : "${' ' * indent} |- NONE";
  }
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
  final ConstraintExpression? upperBound;

  /// A bunch of terminals and non-terminals whose sum expresses the lower bound of the range.
  final ConstraintExpression? lowerBound;

  final BoundType? lowerBoundType;
  final BoundType? upperBoundType;

  const ContinuousRangeConstraint({
    this.lowerBoundType,
    this.lowerBound,
    this.upperBound,
    this.upperBoundType,
  });

  ContinuousRangeConstraint operator +(ContinuousRangeConstraint other) {
    final ConstraintExpression? newLower =
        mergeNulls(lowerBound, other.lowerBound, orElse: (a, b) {
      return (
        union(a.$1, b.$1),
        [a.$2.first + b.$2.first],
      );
    });

    final ConstraintExpression? newUpper =
        mergeNulls(upperBound, other.upperBound, orElse: (a, b) {
      return (
        union(a.$1, b.$1),
        [a.$2.first + b.$2.first],
      );
    });

    return ContinuousRangeConstraint(
      lowerBoundType:
          newLower != null ? lowerBoundType!.union(other.lowerBoundType) : null,
      lowerBound: newLower,
      upperBound: newUpper,
      upperBoundType:
          newUpper != null ? upperBoundType!.union(other.upperBoundType) : null,
    );
  }

  ContinuousRangeConstraint operator -(ContinuousRangeConstraint other) {
    final ConstraintExpression? newLower =
        mergeNulls(lowerBound, other.lowerBound, orElse: (a, b) {
      return (
        subtractAndNegate(a.$1, b.$1),
        [a.$2.first - b.$2.first],
      );
    });

    final ConstraintExpression? newUpper =
        mergeNulls(upperBound, other.upperBound, orElse: (a, b) {
      return (
        subtractAndNegate(a.$1, b.$1),
        [a.$2.first - b.$2.first],
      );
    });

    return ContinuousRangeConstraint(
      lowerBoundType:
          newLower != null ? lowerBoundType!.union(other.lowerBoundType) : null,
      lowerBound: newLower,
      upperBound: newUpper,
      upperBoundType:
          newUpper != null ? upperBoundType!.union(other.upperBoundType) : null,
    );
  }

  String prettyPrint(int indent) {
    return "${' ' * indent} |- Lower: $lowerBound, Upper: $upperBound";
  }
}

class ValueConstraint extends Constraint {
  final ConstraintExpression? value;

  const ValueConstraint(this.value);

  ValueConstraint operator +(ValueConstraint other) {
    return ValueConstraint(
      mergeNulls(
        value,
        other.value,
        orElse: (a, b) => (
          union(a.$1, b.$1),
          [a.$2.first + b.$2.first],
        ),
      ),
    );
  }

  ValueConstraint operator -(ValueConstraint other) {
    return ValueConstraint(
      mergeNulls(
        value,
        other.value,
        orElse: (a, b) => (
          subtractAndNegate(a.$1, b.$1),
          [a.$2.first - b.$2.first],
        ),
      ),
    );
  }

  @override
  String prettyPrint(int indent) {
    if (value != null) {
      final List<String> res = [];
      for (final expr in value!.$1) {
        res.add("${' ' * indent}|- EXPR: ${expr.runtimeType.toString()}");
      }
      res.add("${' ' * indent} |- CONST: ${value!.$2[0]}");
      return res.join('\n');
    } else {
      return "${' ' * indent} |- NONE";
    }
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

  const BooleanConstraint(this.whenTrue, this.whenFalse);

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
