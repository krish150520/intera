import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img_lib;
import 'package:tflite_flutter/tflite_flutter.dart';

class NsfwDetectionService {
  // Common NSFW / adult keywords for text filtering
  static const List<String> _nsfwKeywords = [
    'nsfw',
    'porn',
    'nudity',
    'naked',
    'sex',
    'adult',
    'gore',
    'violence',
    'xxx',
    'erotic',
  ];

  /// Checks if text content contains any NSFW keywords.
  static Future<bool> isTextNsfw(String text) async {
    if (text.isEmpty) return false;
    final lowerText = text.toLowerCase();
    
    for (final keyword in _nsfwKeywords) {
      if (lowerText.contains(keyword)) {
        return true;
      }
    }
    return false;
  }

  /// Scans media file name and analyzes pixels for high proportions of skin tones if it's an image.
  static Future<bool> isMediaNsfw(File? mediaFile) async {
    if (mediaFile == null) return false;
    
    // 1. Check filename keywords
    final fileName = mediaFile.path.split('/').last.split('\\').last.toLowerCase();
    for (final keyword in _nsfwKeywords) {
      if (fileName.contains(keyword)) {
        return true;
      }
    }
    
    // 2. Perform TF-Lite / Fallback analysis if it's an image
    final lowerPath = mediaFile.path.toLowerCase();
    final isImg = lowerPath.endsWith('.jpg') || 
                  lowerPath.endsWith('.jpeg') || 
                  lowerPath.endsWith('.png') ||
                  lowerPath.endsWith('.webp');
                  
    if (isImg) {
      return await _isImageNsfw(mediaFile);
    }
    
    return false;
  }

  /// Analyzes the image using a local pre-trained TF-Lite model.
  /// Falls back to skin-tone heuristic color analysis if TF-Lite fails.
  static Future<bool> _isImageNsfw(File imageFile) async {
    try {
      // Initialize the pre-trained on-device ML model from assets
      final interpreter = await Interpreter.fromAsset('assets/models/nsfw_detector.tflite');
      
      final bytes = await imageFile.readAsBytes();
      final image = img_lib.decodeImage(bytes);
      if (image == null) {
        interpreter.close();
        return false;
      }
      
      // Standard input size for MobileNet / ResNet NSFW classifiers
      final resized = img_lib.copyResize(image, width: 224, height: 224);
      
      // Preprocess image bytes to shape [1, 224, 224, 3] and normalize inputs to 0.0 - 1.0
      final input = List.generate(
        1,
        (_) => List.generate(
          224,
          (y) => List.generate(
            224,
            (x) {
              final pixel = resized.getPixel(x, y);
              return [
                pixel.r / 255.0,
                pixel.g / 255.0,
                pixel.b / 255.0,
              ];
            },
          ),
        ),
      );
      
      // Buffer for outputs [1, 2] (index 0: SFW probability, index 1: NSFW probability)
      final output = List.generate(1, (_) => List.filled(2, 0.0));
      
      interpreter.run(input, output);
      interpreter.close();
      
      final sfwProb = output[0][0];
      final nsfwProb = output[0][1];
      
      debugPrint('[NsfwDetection] TF-Lite Inference -> SFW: $sfwProb, NSFW: $nsfwProb');
      return nsfwProb > 0.5;
    } catch (e) {
      // Fallback if the placeholder or native libraries fail to initialize
      debugPrint('[NsfwDetection] TF-Lite model not initialized, falling back to pixel heuristics: $e');
      return await _isImageNsfwFallback(imageFile);
    }
  }

  /// Fallback color analysis to detect potential nudity/NSFW content without a model file.
  static Future<bool> _isImageNsfwFallback(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final image = img_lib.decodeImage(bytes);
      if (image == null) return false;

      int skinPixels = 0;
      int totalSampled = 0;

      // Sample pixels in a grid to optimize performance and prevent UI lag
      final stepX = (image.width / 15).clamp(1.0, double.infinity).toInt();
      final stepY = (image.height / 15).clamp(1.0, double.infinity).toInt();

      for (int y = 0; y < image.height; y += stepY) {
        for (int x = 0; x < image.width; x += stepX) {
          final pixel = image.getPixel(x, y);
          
          // Get RGB channels
          final r = pixel.r.toInt();
          final g = pixel.g.toInt();
          final b = pixel.b.toInt();

          totalSampled++;

          // Skin tone range heuristic in RGB space
          final isSkin = r > 95 &&
              g > 40 &&
              b > 20 &&
              r > g &&
              r > b &&
              (r - g).abs() > 15 &&
              (r - b).abs() > 15;

          if (isSkin) {
            skinPixels++;
          }
        }
      }

      if (totalSampled == 0) return false;

      final skinPercentage = (skinPixels / totalSampled) * 100;
      
      // If skin tone density exceeds 38%, flag as sensitive/NSFW
      if (skinPercentage > 38.0) {
        return true;
      }
    } catch (e) {
      debugPrint('[NsfwDetection] Fallback image analysis error: $e');
    }
    return false;
  }
}
