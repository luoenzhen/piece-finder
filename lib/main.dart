import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'dashboard.dart';
import 'repository.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PieceFinderApp());
}

const ink = Color(0xFF173E3A);
const paper = Color(0xFFF7F5EF);
const mint = Color(0xFFD8ECE4);

ThemeData pieceFinderTheme() => ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(seedColor: ink, surface: paper),
  scaffoldBackgroundColor: paper,
  appBarTheme: const AppBarTheme(
    backgroundColor: paper,
    foregroundColor: ink,
    centerTitle: false,
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      backgroundColor: ink,
      foregroundColor: Colors.white,
      minimumSize: const Size(48, 54),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: Colors.white,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide.none,
    ),
  ),
);

class PieceFinderApp extends StatefulWidget {
  const PieceFinderApp({super.key, this.repository});
  final PuzzleRepository? repository;
  @override
  State<PieceFinderApp> createState() => _PieceFinderAppState();
}

class _PieceFinderAppState extends State<PieceFinderApp> {
  late Future<PuzzleRepository> _repository;
  @override
  void initState() {
    super.initState();
    _repository = widget.repository == null
        ? PuzzleRepository.open()
        : Future.value(widget.repository);
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'PieceFinder',
    debugShowCheckedModeBanner: false,
    theme: pieceFinderTheme(),
    builder: kIsWeb
        ? (context, child) => ColoredBox(
            color: paper,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: child,
              ),
            ),
          )
        : null,
    home: FutureBuilder<PuzzleRepository>(
      future: _repository,
      builder: (context, snapshot) {
        if (snapshot.hasData) return Dashboard(repository: snapshot.data!);
        if (snapshot.hasError) {
          return Scaffold(
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.storage_rounded, size: 48),
                    const Text(
                      'Your puzzle library could not be opened. Check available storage, then try again.',
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: () =>
                          setState(() => _repository = PuzzleRepository.open()),
                      child: const Text('Try again'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      },
    ),
  );
}

void showError(BuildContext context, Object error) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(error.toString()),
      duration: const Duration(seconds: 6),
    ),
  );
}
