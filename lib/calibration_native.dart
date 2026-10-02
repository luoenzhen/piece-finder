import 'dart:typed_data';

import 'package:dartcv4/dartcv.dart' as cv;

import 'vision.dart' show ImagePoint, VisionException, calibrationDimensions;

/// The setup screen supplies an orientation-normalized, size-limited photo.
/// OpenCV performs the homography and resampling through its C++ FFI bindings.
Uint8List rectifyPhoto(Uint8List bytes, List<ImagePoint> corners) {
  final source = cv.imdecode(bytes, cv.IMREAD_COLOR);
  cv.VecPoint2f? from;
  cv.VecPoint2f? to;
  cv.Mat? transform;
  cv.Mat? output;
  try {
    if (source.isEmpty) {
      throw const VisionException(
        'This photo could not be read. Choose a JPEG or PNG image.',
      );
    }
    final (width, height) = calibrationDimensions(
      corners,
      source.cols,
      source.rows,
    );
    from = cv.VecPoint2f.generate(
      4,
      (i) => cv.Point2f(
        corners[i].x * (source.cols - 1),
        corners[i].y * (source.rows - 1),
      ),
    );
    to = cv.VecPoint2f.generate(
      4,
      (i) => cv.Point2f(
        i == 1 || i == 2 ? width - 1.0 : 0,
        i >= 2 ? height - 1.0 : 0,
      ),
    );
    transform = cv.getPerspectiveTransform2f(from, to);
    output = cv.warpPerspective(source, transform, (
      width,
      height,
    ), borderMode: cv.BORDER_REPLICATE);
    final (success, encoded) = cv.imencode('.jpg', output);
    if (!success) {
      throw const VisionException(
        'Could not prepare the artwork. Try another photo.',
      );
    }
    return encoded;
  } finally {
    output?.dispose();
    transform?.dispose();
    to?.dispose();
    from?.dispose();
    source.dispose();
  }
}
