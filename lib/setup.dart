import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'main.dart';
import 'calibration.dart' as calibration;
import 'models.dart';
import 'repository.dart';
import 'vision.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key, required this.bytes, required this.repository});
  final Uint8List bytes;
  final PuzzleRepository repository;
  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _name = TextEditingController();
  final _rows = TextEditingController(text: '20');
  final _columns = TextEditingController(text: '25');
  final _corners = <ImagePoint>[
    (x: .02, y: .02),
    (x: .98, y: .02),
    (x: .98, y: .98),
    (x: .02, y: .98),
  ];
  Uint8List? _photo;
  double _ratio = 1.5;
  int _count = 500;
  bool _saving = false;
  bool _dragging = false;
  int? _activeCorner;
  Offset? _dragOrigin;
  ImagePoint? _cornerOrigin;
  String? _error;
  @override
  void initState() {
    super.initState();
    _prepare();
  }

  Future<void> _prepare() async {
    try {
      final prepared = await compute(_prepareImage, widget.bytes);
      if (mounted) {
        setState(() {
          _photo = prepared.$1;
          _ratio = prepared.$2;
          _estimate(_count);
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  static (Uint8List, double) _prepareImage(Uint8List bytes) {
    final photo = normalizePhoto(bytes);
    final decoded = decodePhoto(photo);
    return (photo, decoded.width / decoded.height);
  }

  void _estimate(int count) {
    _count = count;
    final grid = PuzzleGrid.estimate(count, _ratio);
    _rows.text = '${grid.rows}';
    _columns.text = '${grid.columns}';
  }

  Future<void> _save() async {
    final rows = int.tryParse(_rows.text),
        columns = int.tryParse(_columns.text);
    if (_name.text.trim().isEmpty ||
        rows == null ||
        columns == null ||
        rows < 2 ||
        columns < 2 ||
        rows > 100 ||
        columns > 100) {
      setState(
        () => _error = 'Enter a name and grid dimensions between 2 and 100.',
      );
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final image = await compute(_rectify, (
        _photo!,
        List<ImagePoint>.of(_corners),
      ));
      final puzzle = await widget.repository.create(
        name: _name.text,
        reference: image,
        rows: rows,
        columns: columns,
      );
      if (mounted) Navigator.pop<Puzzle>(context, puzzle);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  static Uint8List _rectify((Uint8List, List<ImagePoint>) args) =>
      calibration.rectifyPhoto(args.$1, args.$2);

  Widget _buildCrop() => LayoutBuilder(
    builder: (context, constraints) {
      const inset = 24.0;
      final width = constraints.maxWidth - inset * 2;
      final height = width / _ratio;
      return SizedBox(
        height: height + inset * 2,
        child: Stack(
          children: [
            Positioned(
              left: inset,
              top: inset,
              width: width,
              height: height,
              child: Image.memory(_photo!, fit: BoxFit.fill),
            ),
            Positioned(
              left: inset,
              top: inset,
              width: width,
              height: height,
              child: IgnorePointer(
                child: CustomPaint(painter: CropPainter(_corners)),
              ),
            ),
            for (var i = 0; i < 4; i++)
              Positioned(
                left: inset + _corners[i].x * width - 24,
                top: inset + _corners[i].y * height - 24,
                child: Semantics(
                  label: 'Artwork corner ${i + 1}',
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onPanDown: (details) {
                      _dragOrigin = details.globalPosition;
                      _cornerOrigin = _corners[i];
                    },
                    onPanStart: (_) => setState(() {
                      _dragging = true;
                      _activeCorner = i;
                    }),
                    onPanUpdate: (details) {
                      final delta = details.globalPosition - _dragOrigin!;
                      setState(
                        () => _corners[i] = (
                          x: (_cornerOrigin!.x + delta.dx / width).clamp(0, 1),
                          y: (_cornerOrigin!.y + delta.dy / height).clamp(0, 1),
                        ),
                      );
                    },
                    onPanEnd: (_) => _endDrag(),
                    onPanCancel: _endDrag,
                    child: SizedBox(
                      width: 48,
                      height: 48,
                      child: Center(
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: ink, width: 3),
                          ),
                          child: Center(
                            child: Text(
                              '${i + 1}',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            if (_activeCorner != null)
              Positioned(
                top: 0,
                left: _corners[_activeCorner!].x >= .5 ? 0 : null,
                right: _corners[_activeCorner!].x < .5 ? 0 : null,
                child: IgnorePointer(
                  child: Semantics(
                    label: 'Corner magnifier, 2 times zoom',
                    child: Container(
                      width: 112,
                      height: 112,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: ink, width: 3),
                        boxShadow: const [
                          BoxShadow(blurRadius: 8, color: Colors.black26),
                        ],
                      ),
                      child: ClipOval(
                        child: ColoredBox(
                          color: paper,
                          child: Stack(
                            children: [
                              Positioned(
                                left:
                                    53 - _corners[_activeCorner!].x * width * 2,
                                top:
                                    53 -
                                    _corners[_activeCorner!].y * height * 2,
                                width: width * 2,
                                height: height * 2,
                                child: Image.memory(_photo!, fit: BoxFit.fill),
                              ),
                              const Center(
                                child: Icon(
                                  Icons.add,
                                  color: Colors.white,
                                  size: 24,
                                  shadows: [
                                    Shadow(color: Colors.black, blurRadius: 3),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    },
  );
  void _endDrag() => setState(() {
    _dragging = false;
    _activeCorner = null;
  });

  @override
  void dispose() {
    _name.dispose();
    _rows.dispose();
    _columns.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Set up your puzzle')),
    body: SafeArea(
      child: AbsorbPointer(
        absorbing: _saving,
        child: ListView(
          physics: _dragging ? const NeverScrollableScrollPhysics() : null,
          padding: const EdgeInsets.all(24),
          children: [
            const Text(
              'A little preparation.\nA lot more finding.',
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w600,
                color: ink,
                height: 1.15,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Drag each corner onto the artwork, excluding the box border and any text.',
              style: TextStyle(height: 1.5),
            ),
            const SizedBox(height: 24),
            if (_photo == null && _error == null)
              const Center(child: CircularProgressIndicator()),
            if (_photo != null) _buildCrop(),
            const SizedBox(height: 28),
            TextField(
              controller: _name,
              maxLength: 80,
              decoration: const InputDecoration(
                labelText: 'Puzzle name',
                hintText: 'Sunday by the sea',
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'PIECE COUNT',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.8,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [300, 500, 1000, 1500, 2000]
                  .map(
                    (count) => ChoiceChip(
                      label: Text('$count'),
                      selected: _count == count,
                      onSelected: (_) => setState(() => _estimate(count)),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 16),
            const Text(
              'Confirm the actual rows and columns. Piece count only provides an estimate.',
              style: TextStyle(height: 1.4),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _rows,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Rows'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _columns,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Columns'),
                  ),
                ),
              ],
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _photo == null || _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check),
              label: Text(_saving ? 'Preparing your board…' : 'Create puzzle'),
            ),
            const SizedBox(height: 12),
            const Text(
              'Your photos stay on this device.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54, fontSize: 12),
            ),
          ],
        ),
      ),
    ),
  );
}

class CropPainter extends CustomPainter {
  CropPainter(List<ImagePoint> corners) : corners = List.of(corners);
  final List<ImagePoint> corners;
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(corners[0].x * size.width, corners[0].y * size.height);
    for (final point in corners.skip(1)) {
      path.lineTo(point.x * size.width, point.y * size.height);
    }
    path.close();
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFF90E9CB)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(CropPainter oldDelegate) => true;
}
