import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../domain/gst_certificate_data.dart';
import 'gst_certificate_parser.dart';

typedef ImageTextRecognizer = Future<String> Function(String imagePath);

class GstOcrResult {
  final GstCertificateData data;
  final String? errorMessage;

  const GstOcrResult.success(this.data) : errorMessage = null;
  const GstOcrResult.failure(this.errorMessage)
    : data = const GstCertificateData();

  bool get isSuccess => errorMessage == null;
}

/// Reads a GST certificate photo with on-device ML Kit (images only; nothing
/// leaves the device) and parses it with [GstCertificateParser].
class GstCertificateOcrService {
  final ImageTextRecognizer? _recognizer;

  const GstCertificateOcrService({ImageTextRecognizer? recognizer})
    // ignore: prefer_initializing_formals
    : _recognizer = recognizer;

  Future<GstOcrResult> extract(String imagePath) async {
    try {
      final text = await (_recognizer ?? _recognizeWithMlKit)(imagePath);
      if (text.trim().isEmpty) {
        return const GstOcrResult.failure(
          'No readable text was found. Retake the photo in good light, or enter the details manually.',
        );
      }
      final data = const GstCertificateParser().parse(text);
      if (data.isEmpty) {
        return const GstOcrResult.failure(
          'This does not look like a GST Registration Certificate (Form GST REG-06). You can enter the details manually.',
        );
      }
      return GstOcrResult.success(data);
    } catch (e) {
      // Never log recognised text: the certificate holds personal data.
      debugPrint('GST certificate OCR error: ${e.runtimeType}');
      return const GstOcrResult.failure(
        'Text could not be read from this image. Retake the photo, or enter the details manually.',
      );
    }
  }

  static Future<String> _recognizeWithMlKit(String imagePath) async {
    final file = File(imagePath);
    if (!file.existsSync() || file.lengthSync() == 0) {
      throw const FileSystemException('Certificate image is missing or empty');
    }
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final result = await recognizer.processImage(
        InputImage.fromFilePath(imagePath),
      );
      return result.text;
    } finally {
      await recognizer.close();
    }
  }
}
