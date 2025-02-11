part of athena;

class KnowledgeGraph {
  final List<KNode> sources;

  const KnowledgeGraph({
    required this.sources,
  });
}

class StateGraphProperty {}

abstract class KNode {
  final String label;
  final List<StateGraphProperty>? stateGraphProperties;

  const KNode({
    required this.label,
    this.stateGraphProperties,
  });
}

class ObjectNode extends KNode {
  final List<ConceptNode> concepts;
  final List<PropertyNode> properties;
  final List<MethodNode> methods;

  const ObjectNode({
    required super.label,
    super.stateGraphProperties,
    required this.concepts,
    required this.properties,
    required this.methods,
  });
}

class ConceptNode extends KNode {
  final List<ConceptNode>? nestedConcepts;
  const ConceptNode({
    required super.label,
    super.stateGraphProperties,
    this.nestedConcepts,
  });
}

class PropertyNode extends KNode {
  const PropertyNode({
    required super.label,
    super.stateGraphProperties,
  });
}

class MethodNode extends KNode {
  const MethodNode({
    required super.label,
    super.stateGraphProperties,
  });
}
