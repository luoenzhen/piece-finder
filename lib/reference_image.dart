import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'models.dart';
import 'repository.dart';

class ReferenceImage extends StatefulWidget {
  const ReferenceImage({
    super.key,
    required this.puzzle,
    required this.repository,
    this.fit = BoxFit.contain,
    this.height,
  });
  final Puzzle puzzle;
  final PuzzleRepository repository;
  final BoxFit fit;
  final double? height;
  @override
  State<ReferenceImage> createState() => _ReferenceImageState();
}

class _ReferenceImageState extends State<ReferenceImage> {
  late Future<Uint8List> _bytes = widget.repository.readReference(
    widget.puzzle,
  );
  @override
  void didUpdateWidget(ReferenceImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.puzzle.imagePath != widget.puzzle.imagePath ||
        oldWidget.repository != widget.repository) {
      _bytes = widget.repository.readReference(widget.puzzle);
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Uint8List>(
    future: _bytes,
    builder: (context, snapshot) {
      if (snapshot.hasData) {
        return Image.memory(
          snapshot.data!,
          fit: widget.fit,
          height: widget.height,
          errorBuilder: (_, _, _) => SizedBox(
            height: widget.height ?? 180,
            child: const Center(child: Text('Reference image unavailable')),
          ),
        );
      }
      return SizedBox(
        height: widget.height ?? 180,
        child: Center(
          child: snapshot.hasError
              ? const Text('Reference image unavailable')
              : const CircularProgressIndicator(),
        ),
      );
    },
  );
}
