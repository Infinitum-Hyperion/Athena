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
    // required FunctionStmt origin,
  }) {
    final List<Token> tokens = Tokeniser(source: source).tokenise();
    final AST ast = Parser(tokens).parse();
    final history = analyseTemporalDependencies();

    final Iterable<StateGraph2D> endStates = StateGraphSimulator(
      ast: ast,
      // origin: origin,
    ).simulate2D();

    print("${endStates.length} states");

    for (final endState in endStates) {
      endState.prettyPrint();
    }

    return [];
  }

  void analyseTemporalDependencies() {}
}
