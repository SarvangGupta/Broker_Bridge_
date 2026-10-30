import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../domain/cheque_leaf_data.dart';
import '../domain/gst_certificate_data.dart';
import 'cheque_leaf_parser.dart';
import 'gst_certificate_parser.dart';

typedef ImageTextRecognizer = Future<String> Function(String imagePath);

/// Result wrapper for OCR operations.
class OcrResult<T> {
  final T? data;
  final String? errorMessage;

  const OcrResult.success(this.data) : errorMessage = null;
  const OcrResult.failure(this.errorMessage) : data = null;

  bool get isSuccess => errorMessage == null && data != null;
}

/// Service that performs on-device OCR using Google ML Kit and parses
/// GST REG-06 registration certificates and Cheque leaves.
class OcrExtractionService {
  final ImageTextRecognizer? _recognizer;
  final GstCertificateParser _gstParser;
  final ChequeLeafParser _chequeParser;

  const OcrExtractionService({
    ImageTextRecognizer? recognizer,
    GstCertificateParser gstParser = const GstCertificateParser(),
    ChequeLeafParser chequeParser = const ChequeLeafParser(),
  })  : _recognizer = recognizer,
        _gstParser = gstParser,
        _chequeParser = chequeParser;

  /// Extract GST Certificate Form REG-06 details from image.
  Future<OcrResult<GstCertificateData>> extractGstCertificate(String imagePath) async {
    try {
      final text = await (_recognizer ?? _recognizeWithMlKit)(imagePath);
      if (text.trim().isEmpty) {
        return const OcrResult.failure(
          'No readable text was found. Please retake the photo in good lighting or enter details manually.',
        );
      }

      final data = _gstParser.parse(text);
      if (data.isEmpty) {
        return const OcrResult.failure(
          'Document does not appear to be a valid GST Registration Certificate (Form GST REG-06). Please review or enter details manually.',
        );
      }

      return OcrResult.success(data);
    } catch (e) {
      debugPrint('GST Certificate OCR error: $e');
      return const OcrResult.failure(
        'Failed to read text from certificate image. Please retake the photo or enter details manually.',
      );
    }
  }

  /// Extract Cheque Leaf details from image.
  Future<OcrResult<ChequeLeafData>> extractChequeLeaf(String imagePath) async {
    try {
      final text = await (_recognizer ?? _recognizeWithMlKit)(imagePath);
      if (text.trim().isEmpty) {
        return const OcrResult.failure(
          'No readable text was found on the cheque leaf. Please retake the photo in good lighting.',
        );
      }

      final data = _chequeParser.parse(text);
      if (data.isEmpty) {
        return const OcrResult.failure(
          'Could not detect account or IFSC details on this cheque leaf. Please enter manually or try another photo.',
        );
      }

      return OcrResult.success(data);
    } catch (e) {
      debugPrint('Cheque Leaf OCR error: $e');
      return const OcrResult.failure(
        'Failed to read text from cheque leaf image. Please try again or re-upload.',
      );
    }
  }

  static Future<String> _recognizeWithMlKit(String imagePath) async {
    final file = File(imagePath);
    if (!file.existsSync() || file.lengthSync() == 0) {
      throw const FileSystemException('Document image is missing or empty');
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

