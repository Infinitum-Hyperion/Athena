import 'package:athena_sdk/athena_sdk.dart';

void main(List<String> arguments) {
  const src1 = """var res = 10;
var y = 10 + 5;
var x = 2;
var z = y - x;
var a;
var g = z - a;
""";

  AverhydeBeta(
    kgraph: KnowledgeGraph(
      sources: [
        ObjectNode(
          label: 'List',
          concepts: [
            ConceptNode(
              label: 'sorting',
              nestedConcepts: [
                ConceptNode(label: 'descending'),
                ConceptNode(label: 'ascending'),
              ],
            ),
          ],
          properties: [
            PropertyNode(label: 'last'),
            PropertyNode(label: 'first'),
            PropertyNode(label: 'length'),
          ],
          methods: [
            MethodNode(label: 'sort'),
            MethodNode(label: 'reverse'),
          ],
        ),
        ConceptNode(
          label: 'For Loop',
          nestedConcepts: [
            ConceptNode(label: 'scoped variable'),
            ConceptNode(label: 'ascending'),
          ],
        ),
      ],
    ),
  ).createAlternatives(source: src1);
}
