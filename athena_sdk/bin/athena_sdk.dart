import 'package:athena_sdk/athena_sdk.dart';

void main(List<String> arguments) {
  final FuncDeclNode funcDeclNode = FuncDeclNode(
    body: BlockNode(
      childNodes: [
        ParamDeclNode(name: 'x', type: 'List<int>'),
        ForLoopNode(
          scopedVar: VarDeclNode(
            name: 'i',
            type: 'int',
            value: LiteralNode(type: 'string', value: 0),
          ),
          clause: BinExpNode(
            left: VarRefNode(varName: 'i'),
            operator: ASTOperatorNode(operator: '<'),
            right: PropAccessNode(
                obj: VarRefNode(varName: 'x'), property: 'length'),
          ),
          increment: UnaryExpNode(
            operand: VarRefNode(varName: 'i'),
            operator: ASTOperatorNode(operator: '++'),
          ),
          body: [],
        ),
      ],
    ),
  );

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
  ).createAlternatives(
    origin: funcDeclNode.body,
    fullContext: AST(
      topLevelNodes: [funcDeclNode],
    ),
  );
}
