import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:graphview/GraphView.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Dart AST Viewer',
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends HookWidget {
  const MyHomePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final controller = useTextEditingController();

    final config = useMemoized(
      () => BuchheimWalkerConfiguration()
        ..orientation = BuchheimWalkerConfiguration.ORIENTATION_LEFT_RIGHT,
      [],
    );

    final result = useState<CompilationUnit?>(null);
    final nodes = useMemoized<Map<int, AstNode>>(() => {}, [result.value]);

    final graph = useMemoized(
      () => result.value != null ? toGraph(nodes, result.value!.root) : Graph(),
      [nodes, result.value],
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dart AST Viewer'),
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Expanded(
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.all(8.0),
              child: TextField(
                controller: controller,
                autofocus: true,
                autocorrect: false,
                expands: true,
                maxLines: null,
                minLines: null,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                result.value = compileCode(controller.value.text);
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'parsing error: ${e.toString()}',
                    ),
                  ),
                );
              }
            },
            child: const Text('convert'),
          ),
          Expanded(
            child: InteractiveViewer(
              constrained: false,
              boundaryMargin: const EdgeInsets.all(100),
              minScale: 0.01,
              maxScale: 10.00,
              child: GraphView(
                graph: graph,
                algorithm:
                    BuchheimWalkerAlgorithm(config, TreeEdgeRenderer(config)),
                paint: Paint()
                  ..color = Colors.blue
                  ..strokeWidth = 1
                  ..style = PaintingStyle.stroke,
                builder: (Node node) {
                  return AstNodeWidget(
                    id: node.key!.value,
                    nodes: nodes,
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AstNodeWidget extends HookWidget {
  const AstNodeWidget({
    Key? key,
    required this.id,
    required this.nodes,
  }) : super(key: key);

  final int id;
  final Map<int, AstNode> nodes;

  @override
  Widget build(BuildContext context) {
    final text = nodes[id] != null ? toStringNode(nodes[id]!) : 'UNKNOWN';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black12,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(text),
    );
  }
}

CompilationUnit compileCode(String source) {
  final result = parseString(content: source);

  return result.unit;
}

Graph toGraph(Map<int, AstNode> nodes, AstNode root) {
  final graph = Graph();
  graph.isTree = true;

  traverse(graph, nodes, null, root);

  return graph;
}

void traverse(
  Graph graph,
  Map<int, AstNode> nodes,
  AstNode? parent,
  AstNode node,
) {
  final gnode = Node.Id(node.hashCode);
  final gparent = parent != null ? Node.Id(parent.hashCode) : null;

  nodes[node.hashCode] = node;
  graph.addNode(gnode);
  if (gparent != null) graph.addEdge(gparent, gnode);

  for (final child in node.childEntities) {
    if (child is AstNode) {
      traverse(graph, nodes, node, child);
    }
  }
}

String toStringNode(AstNode node) {
  final result = StringBuffer();

  result.writeln('$node');
  result.writeln('type: ${node.runtimeType}');

  return result.toString();
}
