part of athena;

class StateGraphSimulator {
  final StateGraph2D defaultStateGraph = StateGraph2D();
  late final Map<String, StateGraph2D> possibilites = {
    defaultStateGraph.id: defaultStateGraph
  };
  late final ExprStateSimulator exprSimulator = ExprStateSimulator(
    stateGraph2D: defaultStateGraph,
  );
  late final StmtStateSimulator stmtSimulator = StmtStateSimulator(sim: this);
  final AST ast;
  late String currentStateGraphId = defaultStateGraph.id;

  StateGraph2D get currentState => possibilites[currentStateGraphId]!;

  StateGraphSimulator({
    required this.ast,
  });

  /// Set a new variable-constraint mapping
  void setContext(String id) => currentStateGraphId = id;

  /// Delete an old mapping
  void deleteContext(String id) => possibilites.remove(id);

  void addGraph(StateGraph2D stateGraph) =>
      possibilites[stateGraph.id] = stateGraph;

  Iterable<StateGraph2D> simulate2D() {
    for (final stmt in ast) {
      stmt.accept(stmtSimulator);
    }

    return possibilites.values;
  }
}

class StmtStateSimulator implements StmtVisitor<void> {
  final StateGraphSimulator sim;

  StmtStateSimulator({
    required this.sim,
  });

  @override
  void visitBlockStmt(BlockStmt stmt) {
    for (final statement in stmt.statements) {
      statement.accept(this);
    }
  }

  @override
  void visitExpressionStmt(ExpressionStmt stmt) {
    stmt.expression.accept(sim.exprSimulator);
  }

  @override
  void visitFunctionStmt(FunctionStmt stmt) {
    // No constraints to evaluate
  }

  @override
  void visitIfStmt(IfStmt stmt) {
    print('orig: ${sim.currentState.id}');
    // 1. Clone the current context and then delete it
    final ifBranchStateGraph = StateGraph2D.clone(sim.currentState);
    print('if: ${ifBranchStateGraph.id}');
    sim.addGraph(ifBranchStateGraph);
    final elseBranchStateGraph = StateGraph2D.clone(sim.currentState);
    print('else: ${elseBranchStateGraph.id}');
    sim.addGraph(elseBranchStateGraph);
    sim.deleteContext(sim.currentState.id);

    // 2. simulate the if-branch
    sim.setContext(ifBranchStateGraph.id);
    //    evaluate the if-condition and assert those constraints
    ifBranchStateGraph.mode = StateGraphMode.assrt;
    stmt.condition.accept(sim.exprSimulator);
    ifBranchStateGraph.mode = StateGraphMode.none;
    //    run the if-branch statements
    stmt.thenBranch.accept(this);

    // 3. simulate the else-branch
    sim.setContext(elseBranchStateGraph.id);
    //    evaluate the else-condition and assert those constraints
    elseBranchStateGraph.mode = StateGraphMode.assrt;
    stmt.condition.accept(sim.exprSimulator);
    elseBranchStateGraph.mode = StateGraphMode.none;
    //    run the if-branch statements
    stmt.thenBranch.accept(this);
  }

  @override
  void visitReturnStmt(ReturnStmt stmt) {
    // No constraints to evaluate
  }

  @override
  void visitVarStmt(VarStmt stmt) {
    Constraints? varConstraints;
    if (stmt.initializer != null) {
      varConstraints = stmt.initializer!.accept(sim.exprSimulator);
    }
    sim.currentState
        .updateVar(stmt.name.lexeme, varConstraints ?? Constraints.none());
  }

  @override
  void visitWhileStmt(WhileStmt stmt) {
    throw UnimplementedError();
  }

  @override
  void visitForStmt(ForStmt stmt) {
    throw UnimplementedError();
    /* final initializer = stmt.initializer.accept(exprSimulator);
    final condition = stmt.condition.accept(exprSimulator);
    final increment = stmt.increment.accept(exprSimulator);
    final body = stmt.body.accept(this);

    return initializer +
        condition.booleanConstraint.whileTrue(body + increment); */
  }
}

class ExprStateSimulator implements ExprVisitor<Constraints> {
  final StateGraph2D stateGraph2D;

  ExprStateSimulator({
    required this.stateGraph2D,
  });

  @override
  Constraints visitBinaryExpr(BinaryExpr expr) {
    final left = evalConstraints(expr.left);
    final right = evalConstraints(expr.right);

    switch (expr.operator.tokenType) {
      case TokenType.PLUS:
        return left + right;
      case TokenType.MINUS:
        return left - right;
      case TokenType.ASTERISK:
        // mind-bendingly difficult
        throw UnimplementedError();
      case TokenType.SLASH:
        // see above
        throw UnimplementedError();

      default:
        return Constraints.none();
    }
  }

  /// Flips comparative operators, so that the right-hand operand can be made
  /// the subject (which is the left-hand operand)
  TokenType flipOperator(TokenType op) => switch (op) {
        TokenType.R_CHEV => TokenType.L_CHEV,
        TokenType.L_CHEV => TokenType.R_CHEV,
        TokenType.MORE_THAN_OR_EQUAL => TokenType.LESS_THAN_OR_EQUAL,
        TokenType.LESS_THAN_OR_EQUAL => TokenType.MORE_THAN_OR_EQUAL,
        TokenType() => throw UnimplementedError(),
      };

  /// This is not defined in the [ExprVisitor] interface, but we need to separate
  /// updates to [Constraints]s from the assertion of [Constraints]s.
  /// Typically, this method will be called by the visitors from [StmtStateSimulator]
  /// when evaluating conditional structures such as `for` and `if`.
  Constraints visitComparisonExpr(BinaryExpr binExpr) {
    Constraints getLeftOperandConstraints(
        Expr leftExpr, TokenType op, Expr rightExpr) {
      final left = evalConstraints(leftExpr);
      final right = evalConstraints(rightExpr);
      return switch (op) {
        TokenType.R_CHEV => Constraints(
            continuousRangeConstraint: ContinuousRangeConstraint(
              lowerBoundType: BoundType.exclusive,
              lowerBound: mergeNulls(
                left.continuousRangeConstraint.lowerBound,
                right.continuousRangeConstraint.lowerBound,
                orElse: (a, b) => (b),
              ),
              upperBound: mergeNulls(
                left.continuousRangeConstraint.upperBound,
                right.continuousRangeConstraint.upperBound,
                orElse: (a, b) => (a),
              ),
              upperBoundType: left.continuousRangeConstraint.upperBoundType,
            ),
          ),
        TokenType.MORE_THAN_OR_EQUAL => Constraints(
            continuousRangeConstraint: ContinuousRangeConstraint(
              lowerBoundType: BoundType.inclusive,
              lowerBound: mergeNulls(
                left.continuousRangeConstraint.lowerBound,
                right.continuousRangeConstraint.lowerBound,
                orElse: (a, b) => (b),
              ),
              upperBound: mergeNulls(
                left.continuousRangeConstraint.upperBound,
                right.continuousRangeConstraint.upperBound,
                orElse: (a, b) => (a),
              ),
              upperBoundType: left.continuousRangeConstraint.upperBoundType,
            ),
          ),
        TokenType.L_CHEV => Constraints(
            continuousRangeConstraint: ContinuousRangeConstraint(
              lowerBoundType: left.continuousRangeConstraint.lowerBoundType,
              lowerBound: mergeNulls(
                left.continuousRangeConstraint.lowerBound,
                right.continuousRangeConstraint.lowerBound,
                orElse: (a, b) => (a),
              ),
              upperBound: mergeNulls(
                left.continuousRangeConstraint.upperBound,
                right.continuousRangeConstraint.upperBound,
                orElse: (a, b) => (b),
              ),
              upperBoundType: BoundType.exclusive,
            ),
          ),
        TokenType.LESS_THAN_OR_EQUAL => Constraints(
            continuousRangeConstraint: ContinuousRangeConstraint(
              lowerBoundType: left.continuousRangeConstraint.lowerBoundType,
              lowerBound: mergeNulls(
                left.continuousRangeConstraint.lowerBound,
                right.continuousRangeConstraint.lowerBound,
                orElse: (a, b) => (a),
              ),
              upperBound: mergeNulls(
                left.continuousRangeConstraint.upperBound,
                right.continuousRangeConstraint.upperBound,
                orElse: (a, b) => (b),
              ),
              upperBoundType: BoundType.inclusive,
            ),
          ),
        TokenType.BANG_EQUAL => Constraints.none(),
        TokenType.EQUAL_EQUAL => Constraints.none(),
        TokenType() => throw UnimplementedError(),
      };
    }

    stateGraph2D.assignOrAssertConstraints(
      binExpr.left,
      getLeftOperandConstraints(
          binExpr.left, binExpr.operator.tokenType, binExpr.right),
    );

    if (![TokenType.EQUAL_EQUAL, TokenType.BANG_EQUAL]
        .contains(binExpr.operator.tokenType)) {
      stateGraph2D.assignOrAssertConstraints(
        binExpr.left,
        getLeftOperandConstraints(binExpr.right,
            flipOperator(binExpr.operator.tokenType), binExpr.left),
      );
    }

    return Constraints.none();
  }

  @override
  Constraints visitLiteralExpr(LiteralExpr expr) {
    return Constraints(
        valueConstraint: ValueConstraint(
      (const [], [expr.value as double]),
    ));
  }

  @override
  Constraints visitUnaryExpr(UnaryExpr expr) {
    final right = expr.right.accept(this);
    final constraints = right;
    // relook the unary negation
    switch (expr.operator.tokenType) {
      case TokenType.MINUS:
        return Constraints.none() - constraints;
      case TokenType.MINUS_MINUS:
        return right -
            Constraints(
              valueConstraint: ValueConstraint((const <Expr>[], [1.0])),
            );
      case TokenType.PLUS_PLUS:
        return right +
            Constraints(
              valueConstraint: ValueConstraint((const <Expr>[], [1.0])),
            );
      case TokenType.BANG:
        return right..booleanConstraint = right.booleanConstraint.not();
      default:
        return Constraints.none();
    }
  }

  @override
  Constraints visitLogicalExpr(LogicalExpr expr) {
    final left = evalConstraints(expr.left);
    final right = evalConstraints(expr.right);

    switch (expr.operator.tokenType) {
      case TokenType.AMP_AMP:
        return Constraints(
          booleanConstraint:
              left.booleanConstraint.and(right.booleanConstraint),
        );
      case TokenType.PIPE_PIPE:
        return Constraints(
          booleanConstraint: left.booleanConstraint.or(right.booleanConstraint),
        );
      default:
        return Constraints.none();
    }
  }

  @override
  Constraints visitVariableExpr(VariableExpr expr) {
    return stateGraph2D.getVar(expr.name.lexeme);
  }

  @override
  Constraints visitCallExpr(CallExpr expr) {
    return Constraints.none();
  }

  @override
  Constraints visitGetExpr(GetExpr expr) {
    return Constraints.none();
  }

  @override
  Constraints visitSetExpr(SetExpr expr) {
    return Constraints.none();
  }

  @override
  Constraints visitAssignExpr(AssignExpr expr) {
    final varConstraints = expr.value.accept(this);
    stateGraph2D.updateVar(expr.name.lexeme, varConstraints);
    return varConstraints;
  }

  Constraints evalConstraints(Expr expr) {
    return expr.accept(this);
  }
}

enum StateGraphMode {
  assign,
  assrt,
  none;
}

class StateGraph2D {
  final Map<String, Constraints> variables = {};
  late final String id = hashCode.toString();
  StateGraphMode mode = StateGraphMode.none;
  (Constraints?, Constraints?) assignedConstraints = (null, null);

  StateGraph2D();

  StateGraph2D.clone(StateGraph2D old) {
    variables.addAll(old.variables);
    assignedConstraints = old.assignedConstraints;
  }

  Constraints getVar(String name) =>
      variables[name] ?? (throw Exception('Variable $name not found'));

  void updateVar(String name, Constraints constraints) =>
      variables[name] = constraints;

  /// A [mode]-dependent update to the constraints of binary operands
  void assignOrAssertConstraints(Expr operand, Constraints constraints) {
    switch (mode) {
      case StateGraphMode.none:
        return;
      case StateGraphMode.assign:
        if (assignedConstraints.$1 == null) {
          assignedConstraints = (constraints, null);
        } else if (assignedConstraints.$2 == null) {
          assignedConstraints = (assignedConstraints.$1, constraints);
        } else {
          // merge using AND
          throw Exception('quite the conundrum');
        }
      case StateGraphMode.assrt:
        if (operand is VariableExpr) {
          variables[operand.name.lexeme] = constraints;
        }
    }
  }

  void prettyPrint() {
    print('SG2D ($id)');
    for (final variable in variables.entries) {
      print('${variable.key}\n${variable.value.prettyPrint(2)}');
    }
  }
}
