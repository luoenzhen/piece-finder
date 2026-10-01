import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

class CaptureScreen extends StatefulWidget {
  const CaptureScreen({super.key, this.boxArt = false});
  final bool boxArt;
  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen>
    with WidgetsBindingObserver {
  CameraController? _camera;
  String? _error;
  bool _busy = false;
  bool _torch = false;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initialize();
  }

  Future<void> _initialize() async {
    final generation = ++_generation;
    CameraController? controller;
    try {
      final cameras = await availableCameras();
      if (!mounted || generation != _generation) return;
      if (cameras.isEmpty) throw StateError('No camera available.');
      final back = cameras.where(
        (c) => c.lensDirection == CameraLensDirection.back,
      );
      controller = CameraController(
        back.isEmpty ? cameras.first : back.first,
        ResolutionPreset.high,
        enableAudio: false,
      );
      await controller.initialize();
      if (!mounted || generation != _generation) {
        await controller.dispose();
        return;
      }
      setState(() {
        _camera = controller;
        _error = null;
        _torch = false;
      });
    } catch (_) {
      await controller?.dispose();
      if (mounted && generation == _generation) {
        setState(
          () => _error = 'Camera unavailable. Allow camera access in Settings, or import a photo.',
        );
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive) {
      _generation++;
      final old = _camera;
      setState(() => _camera = null);
      old?.dispose();
    } else if (state == AppLifecycleState.resumed && _camera == null) {
      _initialize();
    }
  }

  @override
  void dispose() {
    _generation++;
    WidgetsBinding.instance.removeObserver(this);
    _camera?.dispose();
    super.dispose();
  }

  Future<void> _capture({bool gallery = false}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final XFile? photo = gallery
          ? await ImagePicker().pickImage(
              source: ImageSource.gallery,
              maxWidth: 2400,
              maxHeight: 2400,
            )
          : await _camera!.takePicture();
      if (photo == null) return;
      final bytes = await photo.readAsBytes();
      if (!mounted) return;
      HapticFeedback.lightImpact();
      Navigator.pop<Uint8List>(context, bytes);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Could not capture that photo. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggleTorch() async {
    try {
      await _camera?.setFlashMode(_torch ? FlashMode.off : FlashMode.torch);
      if (mounted) setState(() => _torch = !_torch);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Flashlight is unavailable on this camera.');
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF122421),
    appBar: AppBar(
      backgroundColor: const Color(0xFF122421),
      foregroundColor: Colors.white,
      title: Text(widget.boxArt ? 'Capture box artwork' : 'Find this piece'),
      actions: [
        IconButton(
          tooltip: 'Toggle flashlight',
          onPressed: _camera == null ? null : _toggleTorch,
          icon: Icon(_torch ? Icons.flashlight_on : Icons.flashlight_off),
        ),
      ],
    ),
    body: SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              widget.boxArt
                  ? 'Photograph the artwork straight on. You can adjust its corners next.'
                  : 'One piece. Plain contrasting paper. Photograph straight down, with the four sides aligned to the frame.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, height: 1.5),
            ),
          ),
          Expanded(
            child: Center(
              child: _camera == null
                  ? Padding(
                      padding: const EdgeInsets.all(32),
                      child: _error == null
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(
                              _error!,
                              style: const TextStyle(color: Colors.white),
                              textAlign: TextAlign.center,
                            ),
                    )
                  : Stack(
                      alignment: Alignment.center,
                      children: [
                        CameraPreview(_camera!),
                        IgnorePointer(
                          child: FractionallySizedBox(
                            widthFactor: .65,
                            heightFactor: .6,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: Colors.white70,
                                  width: 2,
                                ),
                                borderRadius: BorderRadius.circular(24),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          if (_error != null && _camera != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(_error!, style: const TextStyle(color: Colors.white)),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                IconButton.filledTonal(
                  tooltip: 'Import photo',
                  onPressed: _busy ? null : () => _capture(gallery: true),
                  icon: const Icon(Icons.photo_library_outlined),
                ),
                Semantics(
                  label: 'Take photo',
                  button: true,
                  child: SizedBox(
                    width: 82,
                    height: 82,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF173E3A),
                        shape: const CircleBorder(),
                        padding: EdgeInsets.zero,
                      ),
                      onPressed: _camera == null || _busy
                          ? null
                          : () => _capture(),
                      child: _busy
                          ? const CircularProgressIndicator()
                          : const Icon(Icons.camera_alt_outlined, size: 34),
                    ),
                  ),
                ),
                IconButton.filledTonal(
                  tooltip: 'Retry camera',
                  onPressed: _camera == null && !_busy ? _initialize : null,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
