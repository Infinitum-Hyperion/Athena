library athena;

import 'package:mochaccino_sdk/mochaccino_sdk.dart';

part './kgraph.dart';
part './constraints.dart';
part './state_graph_simulator.dart';

const indentSize = 2;

class AverhydeBeta {
  final KnowledgeGraph kgraph;

  const AverhydeBeta({
    required this.kgraph,
  });

  List<AST> createAlternatives({
    required String source,
    required FunctionStmt origin,
  }) {
    final List<Token> tokens = Tokeniser(source: source).tokenise();
    final AST ast = Parser(tokens).parse();
    final history = analyseTemporalDependencies();

    final List<StateGraph2D> possibleStates = StateGraphSimulator(
      tokens: tokens,
      ast: ast,
      origin: origin,
    ).simulate2D();

    throw UnimplementedError();
  }

  void analyseTemporalDependencies() {}
}

class StateGraph2D {}
