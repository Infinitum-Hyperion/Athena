part of athena;

class StateGraphSimulator {
  final ExprStateSimulator exprSimulator = ExprStateSimulator();
  late final StmtStateSimulator stmtSimulator =
      StmtStateSimulator(exprSimulator);
  final AST ast;

  StateGraphSimulator({
    required List<Token> tokens,
    required this.ast,
  });

  StateGraph2D simulate2D() {
    stmtSimulator.visitBlockStmt(
        ast is BlockStmt ? ast as BlockStmt : BlockStmt(statements: ast));
    return exprSimulator.stateGraph2D;
  }
}

class StmtStateSimulator implements StmtVisitor<void> {
  final ExprStateSimulator exprSimulator;

  StmtStateSimulator(this.exprSimulator);

  @override
  void visitBlockStmt(BlockStmt stmt) {
    for (final statement in stmt.statements) {
      print('Visiting ${statement.runtimeType}');
      statement.accept(this);
    }
  }

  @override
  void visitExpressionStmt(ExpressionStmt stmt) {
    stmt.expression.accept(exprSimulator);
  }

  @override
  void visitFunctionStmt(FunctionStmt stmt) {
    // No constraints to evaluate
  }

  @override
  void visitIfStmt(IfStmt stmt) {
    // note the initial condition, in order to simulate the else-branch later on
    final initialCondition = exprSimulator.stateGraph2D.current;
    // if-branch precondition
    final ifCondition = stmt.condition.accept(exprSimulator).booleanConstraint;
    // add a subgraph based on this condition
    exprSimulator.stateGraph2D.addEdge(
      node: initialCondition,
      condition: ifCondition,
    );

    // simulate the if-branch
    stmt.thenBranch.accept(this);
    // else-branch precondition
    final elseCondition = ifCondition.not();
    // simulate the else-branch
    exprSimulator.stateGraph2D.addEdge(
      node: initialCondition,
      condition: elseCondition,
    );
    // else-branch postcondition
    stmt.elseBranch?.accept(this);

    // merge the two states if possible and reset the state pointer in the state graph
    exprSimulator.stateGraph2D.mergeIfElseBranchStates(
      initialState: initialCondition,
    );
  }

  @override
  void visitReturnStmt(ReturnStmt stmt) {
    // No constraints to evaluate
  }

  @override
  void visitVarStmt(VarStmt stmt) {
    Constraints? varConstraints;
    if (stmt.initializer != null) {
      varConstraints = stmt.initializer!.accept(exprSimulator);
    }
    exprSimulator.stateGraph2D
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
  final StateGraph2D stateGraph2D = StateGraph2D();
  ExprStateSimulator();

  @override
  Constraints visitBinaryExpr(BinaryExpr expr) {
    print('bin exp');
    final left = evalConstraints(expr.left);
    final right = evalConstraints(expr.right);
    print(left.prettyPrint(0));
    print(right.prettyPrint(0));
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

  /// This is not defined in the [ExprVisitor] interface, but we need to separate
  /// updates to [Constraints]s from the assertion of [Constraints]s.
  /// Typically, this method will be called by the visitors from [StmtStateSimulator]
  /// when evaluating conditional structures such as `for` and `if`.
  Constraints visitComparisonExpr(BinaryExpr expr) {
    final left = evalConstraints(expr.left);
    final right = evalConstraints(expr.right);

    switch (expr.operator.tokenType) {
      case TokenType.R_CHEV:
        return Constraints(
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
        );
      case TokenType.MORE_THAN_OR_EQUAL:
        return Constraints(
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
        );
      case TokenType.L_CHEV:
        return Constraints(
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
        );
      case TokenType.LESS_THAN_OR_EQUAL:
        return Constraints(
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
        );
      case TokenType.BANG_EQUAL:
      case TokenType.EQUAL_EQUAL:
      default:
        throw UnimplementedError();
    }
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

class StateGraph2D {
  final StateGraph2DNode root = StateGraph2DNode.empty();
  late StateGraph2DNode current = root;

  void mergeIfElseBranchStates({
    required StateGraph2DNode initialState,
  }) {
    // todo
    current = initialState;
  }

  Constraints getVar(String name) {
    // this is tough, the variable is in two states at once
    return current.variables[name] ??
        (throw Exception('Variable $name not found'));
  }

  void updateVar(String name, Constraints constraints) {
    if (current.subgraphs.isNotEmpty) {
      for (final subgraph in current.subgraphs.entries) {
        subgraph.value.variables[name] = constraints;
      }
    } else {
      current.variables[name] = constraints;
    }
  }

  void addEdge({
    required StateGraph2DNode node,
    required BooleanConstraint condition,
  }) {
    node.subgraphs[condition] = StateGraph2DNode(node.variables);
    current = node;
  }

  void prettyPrint() {
    print('State Graph 2D');
    for (final variable in root.variables.entries) {
      print('${variable.key}\n${variable.value.prettyPrint(2)}');
    }
  }
}

class StateGraph2DNode {
  final Map<String, Constraints> variables;
  final Map<BooleanConstraint, StateGraph2DNode> subgraphs = {};

  StateGraph2DNode(this.variables);
  StateGraph2DNode.empty() : variables = {};
}
