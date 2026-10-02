import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import 'board.dart';
import 'capture.dart';
import 'main.dart';
import 'models.dart';
import 'repository.dart';
import 'reference_image.dart';
import 'setup.dart';
import 'vision.dart';

class Dashboard extends StatefulWidget {
  const Dashboard({super.key, required this.repository});
  final PuzzleRepository repository;
  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  List<Puzzle> _puzzles = [];
  ScanQuota? _quota;
  bool _loading = true;
  bool _busy = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    try {
      final puzzles = await widget.repository.puzzles();
      final quota = await widget.repository.quota();
      if (mounted) {
        setState(() {
          _puzzles = puzzles;
          _quota = quota;
          _loading = false;
          _error = null;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _newPuzzle() async {
    final camera = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Start with the big picture',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text('Photograph the box'),
                onTap: () => Navigator.pop(context, true),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Choose a photo'),
                onTap: () => Navigator.pop(context, false),
              ),
            ],
          ),
        ),
      ),
    );
    if (camera == null || !mounted) return;
    try {
      Uint8List? bytes;
      if (camera) {
        bytes = await Navigator.push<Uint8List>(
          context,
          MaterialPageRoute(builder: (_) => const CaptureScreen(boxArt: true)),
        );
      } else {
        final image = await ImagePicker().pickImage(
          source: ImageSource.gallery,
          maxWidth: 2400,
          maxHeight: 2400,
        );
        bytes = await image?.readAsBytes();
      }
      if (bytes == null || !mounted) return;
      final puzzle = await Navigator.push<Puzzle>(
        context,
        MaterialPageRoute(
          builder: (_) =>
              SetupScreen(bytes: bytes!, repository: widget.repository),
        ),
      );
      await _reload();
      if (puzzle != null && mounted) _board(puzzle);
    } catch (error) {
      if (mounted) showError(context, error);
    }
  }

  Future<void> _board(
    Puzzle puzzle, [
    List<Candidate> candidates = const [],
  ]) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => BoardScreen(
          puzzle: puzzle,
          repository: widget.repository,
          candidates: candidates,
        ),
      ),
    );
    await _reload();
  }

  static ScanResult _match((Uint8List, Uint8List, int, int) args) => matchPiece(
    referenceBytes: args.$1,
    pieceBytes: args.$2,
    rows: args.$3,
    columns: args.$4,
  );
  Future<void> _scan(Puzzle puzzle) async {
    if (_busy) return;
    final quota = await widget.repository.quota();
    if (!mounted) return;
    if (quota.remaining(DateTime.now().toUtc()) == 0) {
      showError(
        context,
        'Five free scans used. Available again at ${quota.resetsAt.toLocal()}.',
      );
      return;
    }
    final bytes = await Navigator.push<Uint8List>(
      context,
      MaterialPageRoute(builder: (_) => const CaptureScreen()),
    );
    if (bytes == null || !mounted) return;
    setState(() => _busy = true);
    ScanResult? result;
    try {
      final reference = await widget.repository.readReference(puzzle);
      final matched = await compute(_match, (
        reference,
        bytes,
        puzzle.rows,
        puzzle.columns,
      ));
      await widget.repository.saveScan(puzzle, matched);
      result = matched;
      HapticFeedback.mediumImpact();
      await _reload();
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (mounted && result != null) await _showResult(puzzle, result);
  }

  Future<void> _showResult(Puzzle puzzle, ScanResult result) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: FractionallySizedBox(
          heightFactor: .85,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            children: [
              Text(
                result.isAmbiguous
                    ? 'A few places to try'
                    : 'Your best candidate',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                  color: ink,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                result.lowTexture
                    ? 'This piece has very little visual detail. Compare the shapes at each location.'
                    : 'Compare these locations on your puzzle before placing the piece.',
                style: const TextStyle(height: 1.5),
              ),
              const SizedBox(height: 20),
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BoardImage(
                  puzzle: puzzle,
                  repository: widget.repository,
                  candidates: result.candidates,
                ),
              ),
              const SizedBox(height: 16),
              for (var i = 0; i < result.candidates.length; i++)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: i == 0 ? const Color(0xFFFFD681) : mint,
                    child: Text('${i + 1}'),
                  ),
                  title: Text(
                    'Row ${result.candidates[i].row + 1} · Column ${result.candidates[i].column + 1}',
                  ),
                  subtitle: Text(
                    result.candidates[i].clockwiseTurns == 0
                        ? 'Keep this orientation'
                        : 'Rotate ${result.candidates[i].clockwiseTurns * 90}° clockwise',
                  ),
                  trailing: Text(
                    '${(result.candidates[i].similarity * 100).round()} / 100',
                  ),
                ),
              const Text(
                'Visual similarity scores are not accuracy probabilities.',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () => Navigator.pop(context, 'board'),
                icon: const Icon(Icons.grid_on_outlined),
                label: const Text('View on board'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => Navigator.pop(context, 'scan'),
                child: const Text('Next scan'),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted) return;
    if (action == 'board') await _board(puzzle, result.candidates);
    if (action == 'scan') await _scan(puzzle);
  }

  Future<void> _history(Puzzle puzzle) async {
    try {
      final history = await widget.repository.history(puzzle);
      if (!mounted) return;
      final result = await showModalBottomSheet<ScanResult>(
        context: context,
        showDragHandle: true,
        builder: (context) => SafeArea(
          child: history.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(32),
                  child: Text('Your scans will appear here.'),
                )
              : ListView.builder(
                  itemCount: history.length,
                  itemBuilder: (context, index) {
                    final scan = history[index];
                    final first = scan.candidates.first;
                    return ListTile(
                      leading: const Icon(Icons.history),
                      title: Text(
                        'Row ${first.row + 1} · Column ${first.column + 1}',
                      ),
                      subtitle: Text(
                        scan.isAmbiguous
                            ? 'Multiple candidates'
                            : 'Best candidate',
                      ),
                      onTap: () => Navigator.pop(context, scan),
                    );
                  },
                ),
        ),
      );
      if (result != null && mounted) await _showResult(puzzle, result);
    } catch (error) {
      if (mounted) showError(context, error);
    }
  }

  Future<void> _delete(Puzzle puzzle) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${puzzle.name}?'),
        content: const Text(
          'Its reference photo, placements and scan history will be removed from this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep puzzle'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.repository.delete(puzzle);
      await _reload();
    } catch (error) {
      if (mounted) showError(context, error);
    }
  }

  void _settings() => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) => const SafeArea(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Made for your puzzle table',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: ink,
              ),
            ),
            SizedBox(height: 16),
            Text(
              'Photos and matching stay on your device. Deleting a puzzle removes its saved images and history. No account is required.',
              style: TextStyle(height: 1.6),
            ),
            SizedBox(height: 16),
            Text(
              'Development preview · matching is experimental. Five scans per 24 hours. Pro subscriptions are not available in this build.',
              style: TextStyle(height: 1.6),
            ),
          ],
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.extension_outlined),
          SizedBox(width: 10),
          Flexible(
            child: Text(
              'PieceFinder',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          tooltip: 'Settings',
          onPressed: _settings,
          icon: const Icon(Icons.tune_rounded),
        ),
      ],
    ),
    body: Stack(
      children: [
        RefreshIndicator(
          onRefresh: _reload,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 110),
            children: [
              Wrap(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: mint,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: const Text(
                      'A LITTLE HELP, A LOT OF JOY',
                      style: TextStyle(
                        fontSize: 10,
                        letterSpacing: 1,
                        fontWeight: FontWeight.w700,
                        color: ink,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Text(
                'Every piece\nhas a place.',
                style: TextStyle(
                  fontSize: 42,
                  height: 1.06,
                  letterSpacing: -1.5,
                  fontWeight: FontWeight.w600,
                  color: ink,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'A fresh pair of eyes for the tricky bits.',
                style: TextStyle(fontSize: 16, color: Colors.black54),
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'My puzzles',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        color: ink,
                      ),
                    ),
                  ),
                  if (_quota != null)
                    Text(
                      '${_quota!.remaining(DateTime.now().toUtc())} free scans',
                      style: const TextStyle(color: ink, fontSize: 12),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              if (_loading) const Center(child: CircularProgressIndicator()),
              if (_error != null)
                TextButton(
                  onPressed: _reload,
                  child: const Text('Could not load puzzles. Tap to retry.'),
                ),
              if (!_loading && _puzzles.isEmpty && _error == null)
                Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECEAE0),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Column(
                    children: [
                      Icon(Icons.extension_rounded, size: 72, color: ink),
                      SizedBox(height: 24),
                      Text(
                        'Start something good.',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                          color: ink,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Add a photo of your puzzle box.\nWe’ll help you find where each piece belongs.',
                        textAlign: TextAlign.center,
                        style: TextStyle(height: 1.6, color: Colors.black54),
                      ),
                    ],
                  ),
                ),
              for (final puzzle in _puzzles)
                Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        GestureDetector(
                          onTap: () => _board(puzzle),
                          child: ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(24),
                            ),
                            child: ReferenceImage(
                              puzzle: puzzle,
                              repository: widget.repository,
                              height: 180,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 12, 12, 0),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  puzzle.name,
                                  style: const TextStyle(
                                    fontSize: 21,
                                    fontWeight: FontWeight.w600,
                                    color: ink,
                                  ),
                                ),
                              ),
                              PopupMenuButton<String>(
                                tooltip: 'Puzzle options',
                                onSelected: (value) => value == 'history'
                                    ? _history(puzzle)
                                    : _delete(puzzle),
                                itemBuilder: (_) => [
                                  const PopupMenuItem(
                                    value: 'history',
                                    child: Text('Scan history'),
                                  ),
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Text('Delete puzzle'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                '${puzzle.count} pieces · ${puzzle.placed.length} placed',
                                style: const TextStyle(color: Colors.black54),
                              ),
                              const SizedBox(height: 12),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: puzzle.placed.length / puzzle.count,
                                  minHeight: 5,
                                  color: ink,
                                  backgroundColor: mint,
                                ),
                              ),
                              const SizedBox(height: 16),
                              FilledButton.icon(
                                onPressed: _busy ? null : () => _scan(puzzle),
                                icon: const Icon(Icons.center_focus_strong),
                                label: const Text('Find a piece'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.wifi_off_rounded, size: 14, color: Colors.black45),
                  SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'On your device. At your own pace.',
                      style: TextStyle(fontSize: 12, color: Colors.black45),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (_busy)
          const Positioned.fill(
            child: ColoredBox(
              color: Color(0xE6F7F5EF),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 24),
                    Text(
                      'Looking for your piece…',
                      style: TextStyle(fontSize: 20, color: ink),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    ),
    floatingActionButton: _busy
        ? null
        : FloatingActionButton.extended(
            backgroundColor: ink,
            foregroundColor: Colors.white,
            onPressed: _newPuzzle,
            icon: const Icon(Icons.add),
            label: const Text('New puzzle'),
          ),
  );
}
