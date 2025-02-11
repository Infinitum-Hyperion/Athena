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

  Constraints({
    DiscreteRangeConstraint? discreteRangeConstraint,
    ContinuousRangeConstraint? continuousRangeConstraint,
    ValueConstraint? valueConstraint,
  })  : discreteRangeConstraint =
            discreteRangeConstraint ?? DiscreteRangeConstraint(null),
        continuousRangeConstraint = continuousRangeConstraint ??
            ContinuousRangeConstraint(
              lowerBound: null,
              upperBound: null,
              lowerBoundType: null,
              upperBoundType: null,
            ),
        valueConstraint = valueConstraint ?? ValueConstraint(null);

  /// For no other purpose than to be perfectly explicit, we add an empty named constructor.
  Constraints.none()
      : discreteRangeConstraint = DiscreteRangeConstraint(null),
        continuousRangeConstraint = ContinuousRangeConstraint(
          lowerBound: null,
          upperBound: null,
          lowerBoundType: null,
          upperBoundType: null,
        ),
        valueConstraint = ValueConstraint(null);

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
}

ConstraintExpression? mergeNulls(
  ConstraintExpression? a,
  ConstraintExpression? b, {
  required ConstraintExpression Function(
    ConstraintExpression a,
    ConstraintExpression b,
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
}
