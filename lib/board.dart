import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'main.dart';
import 'models.dart';
import 'repository.dart';

class BoardScreen extends StatefulWidget {
  const BoardScreen({
    super.key,
    required this.puzzle,
    required this.repository,
    this.candidates = const [],
  });
  final Puzzle puzzle;
  final PuzzleRepository repository;
  final List<Candidate> candidates;
  @override
  State<BoardScreen> createState() => _BoardScreenState();
}

class _BoardScreenState extends State<BoardScreen> {
  final _transform = TransformationController();
  final _boardKey = GlobalKey();
  final _viewerKey = GlobalKey();
  late final Set<int> _placed = Set.of(widget.puzzle.placed);
  bool _grid = true;
  bool _showPlaced = true;
  bool _saving = false;
  int _selected = 0;
  Candidate? get _candidate =>
      widget.candidates.isEmpty ? null : widget.candidates[_selected];
  void _centerCandidate() {
    final candidate = _candidate;
    final board = _boardKey.currentContext?.findRenderObject() as RenderBox?;
    final viewport =
        _viewerKey.currentContext?.findRenderObject() as RenderBox?;
    if (candidate == null || board == null || viewport == null) {
      _transform.value = Matrix4.identity();
      return;
    }
    final x =
        (viewport.size.width - board.size.width) / 2 +
        (candidate.column + .5) / widget.puzzle.columns * board.size.width;
    final y =
        (viewport.size.height - board.size.height) / 2 +
        (candidate.row + .5) / widget.puzzle.rows * board.size.height;
    const scale = 3.0;
    _transform.value = Matrix4.identity()
      ..translateByDouble(
        viewport.size.width / 2 - x * scale,
        viewport.size.height / 2 - y * scale,
        0,
        1,
      )
      ..scaleByDouble(scale, scale, 1, 1);
  }

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  Future<void> _togglePlaced() async {
    final candidate = _candidate!;
    final cell = candidate.row * widget.puzzle.columns + candidate.column;
    final placed = !_placed.contains(cell);
    setState(() => _saving = true);
    try {
      await widget.repository.setPlaced(widget.puzzle, cell, placed);
      if (mounted) {
        setState(() {
          if (placed) {
            _placed.add(cell);
          } else {
            _placed.remove(cell);
          }
        });
      }
      HapticFeedback.selectionClick();
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final candidate = _candidate;
    final marked =
        candidate != null &&
        _placed.contains(
          candidate.row * widget.puzzle.columns + candidate.column,
        );
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.puzzle.name),
        actions: [
          IconButton(
            tooltip: 'Reset zoom',
            onPressed: () => _transform.value = Matrix4.identity(),
            icon: const Icon(Icons.center_focus_strong),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Wrap(
                spacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    '${_placed.length} / ${widget.puzzle.count} placed',
                    style: const TextStyle(
                      color: ink,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  FilterChip(
                    label: const Text('Grid'),
                    selected: _grid,
                    onSelected: (v) => setState(() => _grid = v),
                  ),
                  FilterChip(
                    label: const Text('Placed'),
                    selected: _showPlaced,
                    onSelected: (v) => setState(() => _showPlaced = v),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: ColoredBox(
                    color: const Color(0xFFE9E8E0),
                    child: LayoutBuilder(
                      builder: (context, constraints) => InteractiveViewer(
                        key: _viewerKey,
                        transformationController: _transform,
                        minScale: 1,
                        maxScale: 8,
                        child: Center(
                          child: GestureDetector(
                            onDoubleTap: _centerCandidate,
                            child: BoardImage(
                              key: _boardKey,
                              puzzle: widget.puzzle,
                              candidates: widget.candidates,
                              selected: _selected,
                              grid: _grid,
                              placed: _showPlaced ? _placed : const {},
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const Text(
              'Pinch to explore · zoom up to 8×',
              style: TextStyle(color: Colors.black54, fontSize: 12),
            ),
            if (candidate != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (widget.candidates.length > 1)
                      Wrap(
                        spacing: 8,
                        children: List.generate(
                          widget.candidates.length,
                          (index) => ChoiceChip(
                            label: Text('Candidate ${index + 1}'),
                            selected: _selected == index,
                            onSelected: (_) =>
                                setState(() => _selected = index),
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),
                    Text(
                      'Row ${candidate.row + 1} · Column ${candidate.column + 1}',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        color: ink,
                      ),
                    ),
                    Text(
                      candidate.clockwiseTurns == 0
                          ? 'Keep this orientation'
                          : 'Rotate ${candidate.clockwiseTurns * 90}° clockwise',
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _saving ? null : _togglePlaced,
                      icon: Icon(marked ? Icons.check_circle : Icons.add_task),
                      label: Text(
                        marked ? 'Placed · tap to undo' : 'Mark as placed',
                      ),
                    ),
                  ],
                ),
              ),
            if (candidate == null) const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class BoardImage extends StatelessWidget {
  const BoardImage({
    super.key,
    required this.puzzle,
    this.candidates = const [],
    this.selected = 0,
    this.grid = false,
    this.placed = const {},
  });
  final Puzzle puzzle;
  final List<Candidate> candidates;
  final int selected;
  final bool grid;
  final Set<int> placed;
  @override
  Widget build(BuildContext context) => Stack(
    children: [
      Image.file(
        File(puzzle.imagePath),
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => const SizedBox(
          height: 180,
          child: Center(child: Text('Reference image unavailable')),
        ),
      ),
      Positioned.fill(
        child: IgnorePointer(
          child: CustomPaint(
            painter: BoardPainter(
              rows: puzzle.rows,
              columns: puzzle.columns,
              candidates: candidates,
              selected: selected,
              grid: grid,
              placed: placed,
            ),
          ),
        ),
      ),
    ],
  );
}

class BoardPainter extends CustomPainter {
  BoardPainter({
    required this.rows,
    required this.columns,
    required this.candidates,
    required this.selected,
    required this.grid,
    required Set<int> placed,
  }) : placed = Set.of(placed);
  final int rows, columns, selected;
  final bool grid;
  final List<Candidate> candidates;
  final Set<int> placed;
  @override
  void paint(Canvas canvas, Size size) {
    final cw = size.width / columns, ch = size.height / rows;
    if (grid) {
      final line = Paint()
        ..color = Colors.white.withValues(alpha: .4)
        ..strokeWidth = .5;
      for (var col = 1; col < columns; col++) {
        canvas.drawLine(
          Offset(col * cw, 0),
          Offset(col * cw, size.height),
          line,
        );
      }
      for (var row = 1; row < rows; row++) {
        canvas.drawLine(
          Offset(0, row * ch),
          Offset(size.width, row * ch),
          line,
        );
      }
    }
    for (final cell in placed) {
      canvas.drawRect(
        Rect.fromLTWH((cell % columns) * cw, (cell ~/ columns) * ch, cw, ch),
        Paint()..color = mint.withValues(alpha: .7),
      );
    }
    for (var i = candidates.length - 1; i >= 0; i--) {
      final c = candidates[i];
      final center = Offset((c.column + .5) * cw, (c.row + .5) * ch);
      canvas.drawCircle(
        center,
        i == selected ? 17 : 12,
        Paint()..color = i == selected ? const Color(0xFFFFD681) : Colors.white,
      );
      canvas.drawCircle(
        center,
        i == selected ? 17 : 12,
        Paint()
          ..color = ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      final text = TextPainter(
        text: TextSpan(
          text: '${i + 1}',
          style: const TextStyle(
            color: ink,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      text.paint(canvas, center - Offset(text.width / 2, text.height / 2));
    }
  }

  @override
  bool shouldRepaint(BoardPainter oldDelegate) => true;
}
