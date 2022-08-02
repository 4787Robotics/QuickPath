import 'package:flutter/cupertino.dart';

//https://stackoverflow.com/questions/65977699/how-to-create-a-movable-widget-in-flutter-such-that-is-stays-at-the-position-it
class StatefulDragArea extends StatefulWidget {
  final Widget child;

  const StatefulDragArea({required this.child});

  @override
  _DragAreaStateStateful createState() => _DragAreaStateStateful();
}

class _DragAreaStateStateful extends State<StatefulDragArea> {
  Offset position = Offset(10, 10);

  void updatePosition(Offset newPosition) =>
      setState(() => position = newPosition);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      child: Stack(
        children: [
          Positioned(
            left: position.dx,
            top: position.dy,
            child: Draggable(
              maxSimultaneousDrags: 1,
              feedback: widget.child,
              childWhenDragging: Opacity(
                opacity: .3,
                child: Container(),
              ),
              onDragEnd: (details) => updatePosition(details.offset),
              child: widget.child,
            ),
          ),
        ],
      ),
    );
  }
}
