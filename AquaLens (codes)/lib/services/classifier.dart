import 'dart:io';
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;

class BoatClassifier {
  Interpreter? _interpreter;
  List<String> _labels = [];
  bool _isLoaded = false;
  double temperatureScale = 1.0;

  // Temperature scaling removed for accurate predictions

  bool get isLoaded => _isLoaded;

  // Load the TensorFlow Lite model and labels
  Future<bool> loadModel() async {
    try {
      debugPrint('Starting model loading process...');

      // Load labels with timeout
      debugPrint('Loading labels...');
      final labelsData = await rootBundle
          .loadString('assets/labels.txt')
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              debugPrint('ERROR: Labels loading timed out');
              throw TimeoutException('Failed to load labels file');
            },
          );
      _labels = labelsData.split('\n').where((label) => label.isNotEmpty).map((
        label,
      ) {
        // Remove numbered prefix (e.g., "0 Bamboo Raft" -> "Bamboo Raft")
        final parts = label.split(' ');
        if (parts.length > 1 && parts[0].contains(RegExp(r'^\d+$'))) {
          return parts.sublist(1).join(' ').trim();
        }
        return label.trim();
      }).toList();
      
      // Ensure labels are sorted alphabetically if they aren't already
      // This is crucial if the model output indices correspond to alphabetical order
      // _labels.sort(); 
      
      debugPrint('Labels loaded successfully. Count: ${_labels.length}');
      debugPrint('Labels: ${_labels.join(', ')}');

      if (_labels.isEmpty) {
        debugPrint('ERROR: No labels found');
        _isLoaded = false;
        return false;
      }

      // Try to load the TFLite model with better error handling
      try {
        debugPrint('Loading TFLite model...');

        // Try different interpreter options to handle Windows DLL issues
        final options = InterpreterOptions();

        _interpreter =
            await Interpreter.fromAsset(
              'assets/model_unquant.tflite',
              options: options,
            ).timeout(
              const Duration(seconds: 30),
              onTimeout: () {
                debugPrint('ERROR: Model loading timed out after 30 seconds');
                throw TimeoutException('Failed to load TFLite model - timeout');
              },
            );

        debugPrint('TFLite model interpreter created');

        // Get input and output shapes
        debugPrint('Getting tensor shapes...');
        final inputTensor = _interpreter!.getInputTensor(0);
        final outputTensor = _interpreter!.getOutputTensor(0);
        final inputShape = inputTensor.shape;
        final outputShape = outputTensor.shape;
        final inputType = inputTensor.type;
        final outputType = outputTensor.type;

        debugPrint('✓ Model loaded successfully!');
        debugPrint('✓ Input shape: $inputShape, type: $inputType');
        debugPrint('✓ Output shape: $outputShape, type: $outputType');
        debugPrint('✓ Labels count: ${_labels.length}');
        debugPrint('✓ Model file path: assets/model_unquant.tflite');
        debugPrint('✓ Model size: 2 MB (expected)');
        debugPrint(
          '⚠ IMPORTANT: Verify that model_unquant.tflite is the REAL trained model',
        );
        debugPrint(
          '⚠ If model was trained only on sailboats, that explains why all predictions are Sail Boat',
        );

        if (outputShape.isNotEmpty && outputShape.last != _labels.length) {
          debugPrint(
            '⚠ WARNING: Output classes (${outputShape.last}) != Labels (${_labels.length})',
          );
        }

        _isLoaded = true;
        return true;
      } catch (modelError) {
        debugPrint('❌ Failed to load TFLite model: $modelError');
        _isLoaded = false;
        return false;
      }
    } catch (e) {
      debugPrint('ERROR in model loading process: $e');
      _isLoaded = false;
      return false;
    }
  }

  // Classify image from file
  Future<ClassificationResult?> classifyImage(File imageFile) async {
    if (!_isLoaded) {
      debugPrint('Model not loaded');
      return null;
    }

    try {
      if (_interpreter == null) {
        debugPrint('Model interpreter is null');
        return null;
      }

      // Read and preprocess image
      final imageBytes = await imageFile.readAsBytes();
      final image = img.decodeImage(imageBytes);

      if (image == null) {
        debugPrint('Failed to decode image');
        return null;
      }

      // Check input tensor type to determine preprocessing
      final inputTensor = _interpreter!.getInputTensor(0);
      final inputType = inputTensor.type;
      debugPrint('Input Tensor Type: $inputType');

      // For Teachable Machine models (Float32), the standard is [-1, 1]
      // For Quantized models (Uint8), the standard is [0, 255]
      
      if (inputType == TensorType.uint8) {
        debugPrint('Detected Quantized Model (uint8). Using [0, 255] preprocessing.');
        return _classifyImageWithPreprocessing(image, 'raw');
      } else {
        debugPrint('Detected Float32 Model. Using standard Teachable Machine normalization [-1, 1].');
        // This is the most common for model_unquant.tflite
        return _classifyImageWithPreprocessing(image, 'normalized');
      }
    } catch (e) {
      debugPrint('Error classifying image: $e');
      return null;
    }
  }

  // Classify image with different preprocessing methods
  ClassificationResult? _classifyImageWithPreprocessing(
    img.Image image,
    String method,
  ) {
    try {
      debugPrint('=== Trying preprocessing method: $method ===');

      // Get input tensor info
      final inputTensor = _interpreter!.getInputTensor(0);
      final inputShape = inputTensor.shape;

      int inputWidth = 224;
      int inputHeight = 224;

      if (inputShape.length >= 3) {
        inputHeight = inputShape[1];
        inputWidth = inputShape[2];
      } else if (inputShape.length >= 2) {
        inputHeight = inputShape[0];
        inputWidth = inputShape[1];
      }

      // Resize image
      final resizedImage = img.copyResize(
        image,
        width: inputWidth,
        height: inputHeight,
      );

      // Create input buffer
      // IMPORTANT: If input is uint8, we must use Uint8List, otherwise Float32List (List<double>)
      
      Object inputBuffer;
      final inputType = _interpreter!.getInputTensor(0).type;

      if (inputType == TensorType.uint8) {
         // Create [1, height, width, 3] uint8 buffer
         // Using List.generate to ensure deep copy and proper typing
         inputBuffer = List.generate(
          1,
          (_) => List.generate(
            inputHeight,
            (_) => List.generate(
              inputWidth,
              (_) => List.filled(3, 0),
            ),
          ),
        );
      } else {
        // Float32
        inputBuffer = List.generate(
          1,
          (_) => List.generate(
            inputHeight,
            (_) => List.generate(
              inputWidth,
              (_) => List.filled(3, 0.0),
            ),
          ),
        );
      }

      // Apply different preprocessing based on method
      switch (method) {
        case 'standard':
          // [0,1] normalization
          var buffer = inputBuffer as List;
          for (int y = 0; y < inputHeight; y++) {
            for (int x = 0; x < inputWidth; x++) {
              final pixel = resizedImage.getPixel(x, y);
              buffer[0][y][x][0] = pixel.r.toDouble() / 255.0;
              buffer[0][y][x][1] = pixel.g.toDouble() / 255.0;
              buffer[0][y][x][2] = pixel.b.toDouble() / 255.0;
            }
          }
          break;

        case 'normalized':
          // [-1,1] normalization
          var buffer = inputBuffer as List;
          for (int y = 0; y < inputHeight; y++) {
            for (int x = 0; x < inputWidth; x++) {
              final pixel = resizedImage.getPixel(x, y);
              buffer[0][y][x][0] = (pixel.r.toDouble() / 127.5) - 1.0;
              buffer[0][y][x][1] = (pixel.g.toDouble() / 127.5) - 1.0;
              buffer[0][y][x][2] = (pixel.b.toDouble() / 127.5) - 1.0;
            }
          }
          break;

        case 'imagenet':
          // ImageNet preprocessing (BGR + mean subtraction)
          const double meanR = 103.939;
          const double meanG = 116.779;
          const double meanB = 123.68;
          var buffer = inputBuffer as List;

          for (int y = 0; y < inputHeight; y++) {
            for (int x = 0; x < inputWidth; x++) {
              final pixel = resizedImage.getPixel(x, y);
              buffer[0][y][x][0] = pixel.b.toDouble() - meanB; // B
              buffer[0][y][x][1] = pixel.g.toDouble() - meanG; // G
              buffer[0][y][x][2] = pixel.r.toDouble() - meanR; // R
            }
          }
          break;

        case 'standard_bgr':
          // [0,1] normalization with BGR
          var buffer = inputBuffer as List;
          for (int y = 0; y < inputHeight; y++) {
            for (int x = 0; x < inputWidth; x++) {
              final pixel = resizedImage.getPixel(x, y);
              buffer[0][y][x][0] = pixel.b.toDouble() / 255.0;
              buffer[0][y][x][1] = pixel.g.toDouble() / 255.0;
              buffer[0][y][x][2] = pixel.r.toDouble() / 255.0;
            }
          }
          break;

        case 'normalized_bgr':
          // [-1,1] normalization with BGR
          var buffer = inputBuffer as List;
          for (int y = 0; y < inputHeight; y++) {
            for (int x = 0; x < inputWidth; x++) {
              final pixel = resizedImage.getPixel(x, y);
              buffer[0][y][x][0] = (pixel.b.toDouble() / 127.5) - 1.0;
              buffer[0][y][x][1] = (pixel.g.toDouble() / 127.5) - 1.0;
              buffer[0][y][x][2] = (pixel.r.toDouble() / 127.5) - 1.0;
            }
          }
          break;

        case 'raw':
          // [0, 255] raw pixel values
          var buffer = inputBuffer as List;
          for (int y = 0; y < inputHeight; y++) {
            for (int x = 0; x < inputWidth; x++) {
              final pixel = resizedImage.getPixel(x, y);
              if (inputType == TensorType.uint8) {
                 buffer[0][y][x][0] = pixel.r.toInt();
                 buffer[0][y][x][1] = pixel.g.toInt();
                 buffer[0][y][x][2] = pixel.b.toInt();
              } else {
                 buffer[0][y][x][0] = pixel.r.toDouble();
                 buffer[0][y][x][1] = pixel.g.toDouble();
                 buffer[0][y][x][2] = pixel.b.toDouble();
              }
            }
          }
          break;
      }

      debugPrint('Applied $method preprocessing');

      // Run inference
      final outputTensor = _interpreter!.getOutputTensor(0);
      final outputShape = outputTensor.shape;

      late List<dynamic> predictions;
      if (outputShape.length == 2) {
        predictions = List.generate(
          outputShape[0],
          (index) => List<double>.filled(outputShape[1], 0),
        );
      } else {
        predictions = List<double>.filled(outputShape[0], 0);
      }

      _interpreter!.run(inputBuffer, predictions);

      // Flatten predictions
      List<double> flatPredictions;
      if (predictions is List<List<double>>) {
        flatPredictions = predictions[0];
      } else {
        if (predictions.isNotEmpty && predictions.first is List) {
          flatPredictions = (predictions.first as List).cast<double>();
        } else {
          flatPredictions = predictions.map((e) => (e as double)).toList();
        }
      }

      debugPrint(
        'Raw predictions for $method: ${flatPredictions.map((p) => p.toStringAsFixed(6)).join(', ')}',
      );

      // Process predictions
      final scores = _processPredictions(flatPredictions);
      final top = scores.isNotEmpty ? scores.first : null;

      if (top != null) {
        debugPrint(
          '$method result: ${top.label} (${top.confidence.toStringAsFixed(1)}%)',
        );
        return ClassificationResult(
          boatType: top.label,
          confidence: top.confidence,
          scores: scores,
        );
      }

      return null;
    } catch (e) {
      debugPrint('Error in $method preprocessing: $e');
      return null;
    }
  }

  // Classify image from bytes
  Future<ClassificationResult?> classifyImageFromBytes(
    Uint8List imageBytes,
  ) async {
    if (!_isLoaded) {
      debugPrint('Model not loaded');
      return null;
    }

    try {
      if (_interpreter == null) {
        debugPrint('Model interpreter is null');
        return null;
      }

      final image = img.decodeImage(imageBytes);
      if (image == null) {
        debugPrint('Failed to decode image');
        return null;
      }

      return _classifyImage(image);
    } catch (e) {
      debugPrint('Error classifying image from bytes: $e');
      return null;
    }
  }

  // Internal classification method
  ClassificationResult? _classifyImage(img.Image image) {
    try {
      debugPrint('=== Starting Classification ===');
      debugPrint('Input image size: ${image.width}x${image.height}');

      // Get input tensor info
      final inputTensor = _interpreter!.getInputTensor(0);
      final inputShape = inputTensor.shape;
      debugPrint('Input tensor shape: $inputShape');

      int inputWidth = 224;
      int inputHeight = 224;

      if (inputShape.length >= 3) {
        inputHeight = inputShape[1];
        inputWidth = inputShape[2];
      } else if (inputShape.length >= 2) {
        inputHeight = inputShape[0];
        inputWidth = inputShape[1];
      }

      debugPrint('Expected input size: ${inputWidth}x$inputHeight');

      // Resize image to model input size
      final resizedImage = img.copyResize(
        image,
        width: inputWidth,
        height: inputHeight,
      );
      debugPrint(
        'Resized image to: ${resizedImage.width}x${resizedImage.height}',
      );

      // Convert to 4D float32 tensor [1, height, width, 3]
      // Use standard [0,1] normalization (most common for custom models)
      final inputBuffer = List.filled(
        1,
        List.filled(inputHeight, List.filled(inputWidth, List.filled(3, 0.0))),
      );

      for (int y = 0; y < inputHeight; y++) {
        for (int x = 0; x < inputWidth; x++) {
          final pixel = resizedImage.getPixel(x, y);

          // Normalize RGB values to [0,1] range
          inputBuffer[0][y][x][0] = pixel.r.toDouble() / 255.0; // R channel
          inputBuffer[0][y][x][1] = pixel.g.toDouble() / 255.0; // G channel
          inputBuffer[0][y][x][2] = pixel.b.toDouble() / 255.0; // B channel
        }
      }

      // Debug: Check first few pixel values and overall statistics
      debugPrint('=== PREPROCESSING DEBUG ===');
      var buffer = inputBuffer as List;
      debugPrint(
        'Pixel [0,0]: R=${buffer[0][0][0][0]}, G=${buffer[0][0][0][1]}, B=${buffer[0][0][0][2]}',
      );

      // Check image statistics
      double rSum = 0, gSum = 0, bSum = 0;
      int pixelCount = 0;
      for (int y = 0; y < math.min(10, inputHeight); y++) {
        for (int x = 0; x < math.min(10, inputWidth); x++) {
          rSum += (buffer[0][y][x][0] as num).toDouble();
          gSum += (buffer[0][y][x][1] as num).toDouble();
          bSum += (buffer[0][y][x][2] as num).toDouble();
          pixelCount++;
        }
      }
      debugPrint(
        'Sample pixel averages: R=${(rSum / pixelCount).toStringAsFixed(3)}, G=${(gSum / pixelCount).toStringAsFixed(3)}, B=${(bSum / pixelCount).toStringAsFixed(3)}',
      );
      debugPrint('=== END PREPROCESSING DEBUG ===');

      debugPrint(
        'Input buffer prepared: ${inputBuffer.length}x${inputBuffer[0].length}x${inputBuffer[0][0].length}x${inputBuffer[0][0][0].length} (float32)',
      );

      // Get output tensor shape to properly allocate output buffer
      final outputTensor = _interpreter!.getOutputTensor(0);
      final outputShape = outputTensor.shape;
      final outputType = outputTensor.type;
      debugPrint('Output tensor shape: $outputShape, type: $outputType');

      // Create output buffer with proper shape
      late List<dynamic> predictions;

      if (outputShape.length == 2) {
        // Output shape is [1, num_classes]
        debugPrint(
          '2D output detected: [${outputShape[0]}, ${outputShape[1]}]',
        );
        predictions = List.generate(
          outputShape[0],
          (index) => List<double>.filled(outputShape[1], 0),
        );
      } else if (outputShape.length == 1) {
        // Output shape is [num_classes]
        debugPrint('1D output detected: [${outputShape[0]}]');
        predictions = List<double>.filled(outputShape[0], 0);
      } else {
        debugPrint(
          'ERROR: Unexpected output shape length: ${outputShape.length}',
        );
        return null;
      }

      // Run inference
      debugPrint('Running inference...');
      _interpreter!.run(inputBuffer, predictions);
      debugPrint('Inference completed');

      // Flatten predictions if needed
      List<double> flatPredictions;
      if (predictions is List<List<double>>) {
        flatPredictions = predictions[0];
        debugPrint(
          'Flattened 2D predictions: ${flatPredictions.length} values',
        );
      } else {
        // Handle nested structure - TensorFlow Lite might return List<List<double>> as List<dynamic>
        if (predictions.isNotEmpty && predictions.first is List) {
          flatPredictions = (predictions.first as List).cast<double>();
          debugPrint(
            'Extracted nested List<double>: ${flatPredictions.length} values',
          );
        } else {
          // Convert List<dynamic> to List<double>
          flatPredictions = predictions.map((e) => (e as double)).toList();
          debugPrint(
            'Converted dynamic to double: ${flatPredictions.length} values',
          );
        }
      }

      debugPrint(
        'Predictions length: ${flatPredictions.length}, Labels length: ${_labels.length}',
      );

      // Debug: Print all prediction values before temperature scaling
      debugPrint('=== RAW PREDICTION VALUES (before temp scaling) ===');
      double maxScore = 0;
      double secondMaxScore = 0;
      for (int i = 0; i < flatPredictions.length; i++) {
        debugPrint(
          '  [$i] ${_labels[i]}: ${flatPredictions[i].toStringAsFixed(6)}',
        );
        if (flatPredictions[i] > maxScore) {
          secondMaxScore = maxScore;
          maxScore = flatPredictions[i];
        } else if (flatPredictions[i] > secondMaxScore) {
          secondMaxScore = flatPredictions[i];
        }
      }

      // Process predictions
      final scores = _processPredictions(flatPredictions);
      final top = scores.isNotEmpty ? scores.first : null;
      if (top == null) {
        debugPrint('ERROR: No valid predictions found');
        return null;
      }

      debugPrint(
        '✓ Top prediction: ${top.label} (${top.confidence.toStringAsFixed(1)}%)',
      );
      debugPrint('=== Classification Complete ===');

      return ClassificationResult(
        boatType: top.label,
        confidence: top.confidence,
        scores: scores,
      );
    } catch (e) {
      debugPrint('❌ ERROR in classification: $e');
      debugPrint('Stack trace: $e');
      return null;
    }
  }

  // Method to test different preprocessing approaches for debugging
  Future<void> testPreprocessingMethods(File imageFile) async {
    try {
      final imageBytes = await imageFile.readAsBytes();
      final image = img.decodeImage(imageBytes);

      if (image == null) {
        debugPrint('Failed to decode image for testing');
        return;
      }

      final inputTensor = _interpreter!.getInputTensor(0);
      final inputShape = inputTensor.shape;
      int inputWidth = 224;
      int inputHeight = 224;

      if (inputShape.length >= 3) {
        inputHeight = inputShape[1];
        inputWidth = inputShape[2];
      } else if (inputShape.length >= 2) {
        inputHeight = inputShape[0];
        inputWidth = inputShape[1];
      }

      final resizedImage = img.copyResize(
        image,
        width: inputWidth,
        height: inputHeight,
      );

      debugPrint('=== TESTING DIFFERENT PREPROCESSING METHODS ===');

      // Method 1: [0, 1] normalization (current)
      final buffer1 = _createInputBuffer(
        resizedImage,
        inputHeight,
        inputWidth,
        1,
      );
      final result1 = _runInference(buffer1);
      debugPrint(
        'Method 1 [0,1]: Top prediction = ${result1[0]}, confidence = ${result1[1].toStringAsFixed(2)}',
      );

      // Method 2: [0, 255] (raw pixel values)
      final buffer2 = _createInputBuffer(
        resizedImage,
        inputHeight,
        inputWidth,
        255,
      );
      final result2 = _runInference(buffer2);
      debugPrint(
        'Method 2 [0,255]: Top prediction = ${result2[0]}, confidence = ${result2[1].toStringAsFixed(2)}',
      );

      // Method 3: [-1, 1] normalization
      final buffer3 = _createInputBufferNormalized(
        resizedImage,
        inputHeight,
        inputWidth,
      );
      final result3 = _runInference(buffer3);
      debugPrint(
        'Method 3 [-1,1]: Top prediction = ${result3[0]}, confidence = ${result3[1].toStringAsFixed(2)}',
      );

      debugPrint('=== END PREPROCESSING TEST ===');
    } catch (e) {
      debugPrint('Error in preprocessing test: $e');
    }
  }

  // Test different temperature scaling values
  Future<void> testTemperatureScaling(File imageFile) async {
    try {
      final result = await classifyImage(imageFile);
      if (result == null) return;

      debugPrint('=== TEMPERATURE SCALING TEST ===');
      debugPrint('Testing different temperature values for the same image');

      final temperatures = [1.0, 1.5, 2.0, 2.5, 3.0, 4.0, 5.0];

      for (final temp in temperatures) {
        temperatureScale = temp;
        debugPrint('Temperature: $temp');
        await classifyImage(imageFile);
      }

      temperatureScale = 1.5;
      debugPrint(
        '=== END TEMPERATURE SCALING TEST (restored to default 1.5) ===',
      );
    } catch (e) {
      debugPrint('Error in temperature scaling test: $e');
    }
  }

  List<dynamic> _createInputBuffer(
    img.Image image,
    int height,
    int width,
    double scale,
  ) {
    final buffer = List.filled(
      1,
      List.filled(height, List.filled(width, List.filled(3, 0.0))),
    );

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final pixel = image.getPixel(x, y);
        buffer[0][y][x][0] = pixel.r.toInt() / scale;
        buffer[0][y][x][1] = pixel.g.toInt() / scale;
        buffer[0][y][x][2] = pixel.b.toInt() / scale;
      }
    }

    return buffer;
  }

  List<dynamic> _createInputBufferNormalized(
    img.Image image,
    int height,
    int width,
  ) {
    final buffer = List.filled(
      1,
      List.filled(height, List.filled(width, List.filled(3, 0.0))),
    );

    // Normalize to [-1, 1] range
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final pixel = image.getPixel(x, y);
        buffer[0][y][x][0] = (pixel.r.toInt() / 127.5) - 1.0;
        buffer[0][y][x][1] = (pixel.g.toInt() / 127.5) - 1.0;
        buffer[0][y][x][2] = (pixel.b.toInt() / 127.5) - 1.0;
      }
    }

    return buffer;
  }

  List<dynamic> _runInference(List<dynamic> inputBuffer) {
    final outputTensor = _interpreter!.getOutputTensor(0);
    final outputShape = outputTensor.shape;

    late List<dynamic> predictions;
    if (outputShape.length == 2) {
      predictions = List.generate(
        outputShape[0],
        (index) => List<double>.filled(outputShape[1], 0),
      );
    } else {
      predictions = List<double>.filled(outputShape[0], 0);
    }

    _interpreter!.run(inputBuffer, predictions);

    List<double> flatPredictions;
    if (predictions is List<List<double>>) {
      flatPredictions = predictions[0];
    } else {
      if (predictions.isNotEmpty && predictions.first is List) {
        flatPredictions = (predictions.first as List).cast<double>();
      } else {
        flatPredictions = predictions.map((e) => (e as double)).toList();
      }
    }

    int topIndex = 0;
    double maxScore = flatPredictions[0];
    for (int i = 1; i < flatPredictions.length; i++) {
      if (flatPredictions[i] > maxScore) {
        maxScore = flatPredictions[i];
        topIndex = i;
      }
    }

    return [topIndex, maxScore];
  }

  // Format class name to title case
  String _formatClassName(String className) {
    return className
        .split(' ')
        .map(
          (word) => word.isEmpty
              ? ''
              : word[0].toUpperCase() + word.substring(1).toLowerCase(),
        )
        .join(' ');
  }

  // Process predictions with proper handling of logits vs probabilities
  List<ClassificationScore> _processPredictions(List<double> predictions) {
    debugPrint('=== PROCESSING PREDICTIONS ===');
    debugPrint(
      'Raw predictions: ${predictions.map((p) => p.toStringAsFixed(6)).join(', ')}',
    );

    // Check if predictions are already probabilities (sum close to 1.0) or logits
    final sum = predictions.reduce((a, b) => a + b);
    debugPrint('Sum of predictions: $sum');

    List<double> probabilities;
    if (sum > 0.9 && sum < 1.1) {
      // Already probabilities, use directly
      debugPrint('Predictions appear to be already probabilities');
      probabilities = predictions;
    } else {
      // Raw logits, apply softmax
      debugPrint('Applying softmax to raw logits');
      probabilities = _softmax(predictions);
    }

    debugPrint(
      'Final probabilities: ${probabilities.map((p) => p.toStringAsFixed(6)).join(', ')}',
    );
    debugPrint(
      'Sum of probabilities: ${probabilities.reduce((a, b) => a + b)}',
    );

    // Create classification scores
    final scores = <ClassificationScore>[];
    for (int i = 0; i < probabilities.length && i < _labels.length; i++) {
      scores.add(
        ClassificationScore(
          label: _formatClassName(_labels[i]),
          confidence: probabilities[i] * 100.0, // Convert to percentage
        ),
      );
    }

    // Sort by confidence in descending order
    scores.sort((a, b) => b.confidence.compareTo(a.confidence));

    debugPrint('Top 3 predictions:');
    for (int i = 0; i < math.min(3, scores.length); i++) {
      debugPrint(
        '  ${i + 1}. ${scores[i].label}: ${scores[i].confidence.toStringAsFixed(1)}%',
      );
    }
    debugPrint('=== END PROCESSING ===');

    return scores;
  }

  // Softmax activation function
  List<double> _softmax(List<double> logits) {
    final maxLogit = logits.reduce(math.max);
    final expLogits = logits
        .map((logit) => math.exp(logit - maxLogit))
        .toList();
    final sumExp = expLogits.reduce((a, b) => a + b);
    return expLogits.map((exp) => exp / sumExp).toList();
  }

  // Dispose method to clean up resources
  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _labels.clear();
    _isLoaded = false;
  }
}

class ClassificationScore {
  final String label;
  final double confidence;

  ClassificationScore({required this.label, required this.confidence});
}

class ClassificationResult {
  final String boatType;
  final double confidence;
  final List<ClassificationScore> scores;

  ClassificationResult({
    required this.boatType,
    required this.confidence,
    required this.scores,
  });
}
