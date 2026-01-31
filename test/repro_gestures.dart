
import 'package:flutter/material.dart';

void main() {
  runApp(const MaterialApp(home: ReproGestures()));
}

class ReproGestures extends StatefulWidget {
  const ReproGestures({super.key});

  @override
  State<ReproGestures> createState() => _ReproGesturesState();
}

class _ReproGesturesState extends State<ReproGestures> {
  String status = "Ready";
  bool isDragging = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(status)),
      body: Center(
        child: LongPressDraggable<String>(
          data: "test",
          feedback: Material(child: Container(color: Colors.red, width: 100, height: 50, child: const Text("Dragging"))),
          onDragStarted: () {
            setState(() {
              status = "Dragging started";
              isDragging = true;
            });
          },
          onDraggableCanceled: (velocity, offset) {
            setState(() {
              status = "Drag canceled";
              isDragging = false;
            });
          },
          onDragEnd: (_) {
             setState(() {
              status = "Drag ended";
              isDragging = false;
            });
          },
          child: GestureDetector(
            behavior: HitTestBehavior.deferToChild,
            onTap: () {
              setState(() {
                status = "Outer Tap Detected";
              });
            },
            child: Container(
              padding: const EdgeInsets.all(20),
              color: Colors.blue.withValues(alpha: 0.2),
              child: const TextField(
                decoration: InputDecoration(
                  hintText: "Try to drag me or tap outside text",
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
