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
    final overlayNodeId = useState<int?>(null);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dart AST Viewer'),
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Expanded(
            flex: 2,
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.all(8.0),
              child: Column(
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      autofocus: true,
                      autocorrect: false,
                      expands: true,
                      maxLines: null,
                      minLines: null,
                      decoration: InputDecoration.collapsed(
                        hintText: 'Enter your source code...',
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
                ],
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: ColoredBox(
              color: Colors.grey.shade200,
              child: Stack(
                children: [
                  InteractiveViewer(
                    constrained: false,
                    boundaryMargin: const EdgeInsets.all(100),
                    minScale: 0.01,
                    maxScale: 10.00,
                    child: graph.hasNodes()
                        ? GraphView(
                            graph: graph,
                            algorithm: BuchheimWalkerAlgorithm(
                                config, TreeEdgeRenderer(config)),
                            paint: Paint()
                              ..color = Colors.blue.shade200
                              ..strokeWidth = 1
                              ..style = PaintingStyle.stroke,
                            builder: (Node node) {
                              final id = node.key!.value;
                              return AstNodeWidget(
                                id: id,
                                nodes: nodes,
                                color: id == overlayNodeId.value
                                    ? Colors.blue.shade300
                                    : Colors.grey.shade400,
                                constrained: true,
                                onPressed: () => overlayNodeId.value = id,
                              );
                            },
                          )
                        : const SizedBox(),
                  ),
                  if (overlayNodeId.value != null)
                    Align(
                      alignment: Alignment.bottomRight,
                      child: AstNodeWidget(
                        id: overlayNodeId.value!,
                        nodes: nodes,
                        color: Colors.blue.shade600.withOpacity(0.6),
                        onPressed: () => overlayNodeId.value = null,
                      ),
                    ),
                ],
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
    this.color,
    this.constrained = false,
    this.onPressed,
  }) : super(key: key);

  final int id;
  final Map<int, AstNode> nodes;
  final Color? color;
  final bool constrained;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final node = nodes[id];
    final mediaWidth = MediaQuery.of(context).size.width;
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        constraints:
            constrained ? BoxConstraints(maxWidth: mediaWidth * 0.2) : null,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Flexible(
              child: Text(
                node?.toSource() ?? 'UNKNOWN',
                maxLines: constrained ? 3 : null,
                overflow: constrained ? TextOverflow.ellipsis : null,
              ),
            ),
            const SizedBox(height: 8),
            Text('type: ${node.runtimeType}'),
          ],
        ),
      ),
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
