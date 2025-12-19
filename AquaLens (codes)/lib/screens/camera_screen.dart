import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/classifier.dart';
import '../services/history.dart';
import 'result_screen.dart';
import '../main.dart';

class _WaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    var path = Path();
    path.lineTo(0, size.height - 40);
    var firstControlPoint = Offset(size.width / 4, size.height);
    var firstEndPoint = Offset(size.width / 2.25, size.height - 30);
    path.quadraticBezierTo(firstControlPoint.dx, firstControlPoint.dy,
        firstEndPoint.dx, firstEndPoint.dy);
    var secondControlPoint =
        Offset(size.width - (size.width / 3.25), size.height - 65);
    var secondEndPoint = Offset(size.width, size.height - 40);
    path.quadraticBezierTo(secondControlPoint.dx, secondControlPoint.dy,
        secondEndPoint.dx, secondEndPoint.dy);
    path.lineTo(size.width, size.height - 40);
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with SingleTickerProviderStateMixin {
  bool _isProcessing = false;
  bool _modelLoaded = false;
  final BoatClassifier _classifier = BoatClassifier();
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _initializeClassifier();
  }

  Future<void> _initializeClassifier() async {
    try {
      debugPrint('Camera Screen: Initializing classifier...');
      final loaded = await _classifier.loadModel();
      if (mounted) {
        setState(() {
          _modelLoaded = loaded;
        });
        if (!loaded) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Failed to load ML model. Check debug logs for details.',
              ),
              duration: Duration(seconds: 5),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Critical error initializing classifier: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Model initialization error: ${e.toString()}'),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _captureFromCamera() async {
    if (!_modelLoaded) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Model is still loading. Please wait...')),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
      );
      if (image != null) {
        final File imageFile = File(image.path);
        await _processImage(imageFile);
      } else {
        setState(() {
          _isProcessing = false;
        });
      }
    } catch (e) {
      debugPrint('Error capturing image: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _pickImageFromGallery() async {
    if (!_modelLoaded) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Model is still loading. Please wait...')),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
      );
      if (image != null) {
        final File imageFile = File(image.path);
        await _processImage(imageFile);
      } else {
        setState(() {
          _isProcessing = false;
        });
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _processImage(File imageFile) async {
    if (!_modelLoaded) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Model not loaded. Please wait...')),
        );
        setState(() {
          _isProcessing = false;
        });
      }
      return;
    }

    try {
      debugPrint('=== PROCESSING IMAGE ===');
      debugPrint('Image file: ${imageFile.path}');

      final result = await _classifier.classifyImage(imageFile);

      if (result == null || result.scores.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to classify image. Please try again.'),
            ),
          );
          setState(() {
            _isProcessing = false;
          });
        }
        return;
      }

      debugPrint('CLASSIFICATION RESULT:');
      debugPrint('  Boat type: ${result.boatType}');
      debugPrint('  Confidence: ${result.confidence.toStringAsFixed(1)}%');
      debugPrint('  All Boat Type Predictions:');
      for (int i = 0; i < result.scores.length; i++) {
        debugPrint(
          '    ${i + 1}. ${result.scores[i].label}: ${result.scores[i].confidence.toStringAsFixed(1)}%',
        );
      }
      debugPrint('=== END CLASSIFICATION ===');

      debugPrint('Running preprocessing diagnostic tests...');
      await _classifier.testPreprocessingMethods(imageFile);

      // Store in history
      if (mounted) {
        ClassificationHistory.instance.addResult(
          result: result,
          imagePath: imageFile.path,
        );
        setState(() {
          _isProcessing = false;
        });
        // Show pop-up results
        _showResultPopup(result, imageFile);
      }
    } catch (e) {
      debugPrint('Error processing image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Classification error: ${e.toString()}')),
        );
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  void _showResultPopup(ClassificationResult result, File imageFile) {
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black54,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 24,
          ),
          child: _ResultPopupDialog(result: result, imageFile: imageFile),
        );
      },
    );
  }

  @override
  void dispose() {
    _classifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;
    final backgroundColor = Theme.of(context).scaffoldBackgroundColor;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: _isProcessing
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Processing image...',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                // Header
                ClipPath(
                  clipper: _WaveClipper(),
                  child: Container(
                    padding: EdgeInsets.only(
                      top: MediaQuery.of(context).padding.top + 16,
                      bottom: 60, // Increased bottom padding for wave
                      left: 24,
                      right: 24,
                    ),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFE3F2FD), // Light blue background
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Image.asset(
                            'assets/boat_logo.png',
                            width: 48, // Resized to be larger
                            height: 48, // Resized to be larger
                            fit: BoxFit.contain,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'AquaLens',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                                ),
                              ),
                              Text(
                                'AI-Powered Image Classification',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? Colors.white70 : Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            ThemeController.instance.toggleTheme();
                          },
                          icon: Icon(
                            isDark ? Icons.light_mode : Icons.dark_mode,
                            color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                          ),
                          style: IconButton.styleFrom(
                            backgroundColor: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.white,
                            padding: const EdgeInsets.all(8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                // Main Content
                Expanded(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          const SizedBox(height: 20),
                          // Main Card
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(32),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E1E1E) : Colors.white, // Card background
                              borderRadius: BorderRadius.circular(32),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 20,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(24),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF2196F3), // Blue accent
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF2196F3).withValues(alpha: 0.3),
                                        blurRadius: 16,
                                        offset: const Offset(0, 8),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.directions_boat_filled,
                                    size: 48,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 32),
                                Text(
                                  'Welcome to AquaLens!',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Identify boat types instantly with AI-powered classification',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 16,
                                    height: 1.5,
                                    color: isDark ? Colors.white70 : Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(height: 48),
                                Row(
                                  children: [
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed: _modelLoaded ? _captureFromCamera : null,
                                        icon: const Icon(Icons.camera_alt),
                                        label: const Text('Camera'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF2196F3), // Blue
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(vertical: 16),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(16),
                                          ),
                                          elevation: 0,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: _modelLoaded ? _pickImageFromGallery : null,
                                        icon: const Icon(Icons.photo_library),
                                        label: const Text('Gallery'),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: isDark ? Colors.white : const Color(0xFF2196F3),
                                          side: BorderSide(
                                            color: isDark ? Colors.white24 : const Color(0xFF2196F3).withValues(alpha: 0.2),
                                          ),
                                          padding: const EdgeInsets.symmetric(vertical: 16),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(16),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          
                          if (!_modelLoaded) ...[
                            const SizedBox(height: 32),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2196F3).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Color(0xFF2196F3),
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Text(
                                    'Loading model...',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFF2196F3),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          const SizedBox(height: 32),
                          
                          // Action Buttons Row
                          Row(
                            children: [
                              Expanded(
                                child: _ActionButton(
                                  icon: Icons.info_outline,
                                  label: 'Info',
                                  onPressed: _showInfoBottomSheet,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _ActionButton(
                                  icon: Icons.history,
                                  label: 'History',
                                  onPressed: _showHistoryBottomSheet,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _ActionButton(
                                  icon: Icons.bar_chart,
                                  label: 'Analytics',
                                  onPressed: _showAnalyticsBottomSheet,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  void _showInfoBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _InfoBottomSheet(),
    );
  }

  void _showHistoryBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _HistoryBottomSheet(),
    );
  }

  void _showAnalyticsBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AnalyticsBottomSheet(),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isDark ? Colors.white : const Color(0xFF0D47A1);
    
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color.withValues(alpha: 0.2),
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: color,
              size: 28,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 13,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoBottomSheet extends StatelessWidget {
  const _InfoBottomSheet();

  String _getBoatDescription(String boatType) {
    switch (boatType.toLowerCase()) {
      case 'bamboo raft':
        return 'A traditional watercraft constructed from multiple bamboo poles lashed together with rope or vines. Features a flat, rectangular platform with a simple, open design. Typically 3-6 meters in length, these rafts have a shallow draft allowing navigation in very shallow waters. The bamboo construction provides natural buoyancy and flexibility. Commonly found in Southeast Asia, these rafts are used for short-distance transportation across rivers, fishing in shallow waters, and transporting goods to markets. They are lightweight, eco-friendly, and can be easily constructed from locally available materials.';
      case 'cargo boat':
        return 'A large commercial vessel designed specifically for transporting goods and merchandise across waterways. Characterized by a wide, boxy hull with a flat deck for cargo storage, these boats typically range from 20-100 meters in length. Features include large cargo holds, cranes or loading equipment, and a high freeboard for stability. The hull is usually made of steel or reinforced materials to withstand heavy loads. Essential for international trade, these vessels transport containers, bulk goods, and raw materials between ports. They operate on major shipping routes and are equipped with navigation systems for long-distance travel.';
      case 'ferry boat':
        return 'A passenger vessel designed to transport people and vehicles across bodies of water on regular scheduled routes. Features a wide, stable hull with multiple decks - lower deck for vehicles and upper deck for passengers. Typically 30-150 meters in length with a capacity for 50-500 passengers and numerous vehicles. Equipped with ramps for vehicle loading, seating areas, restrooms, and sometimes food service. The design prioritizes stability and safety for frequent crossings. Commonly operates on fixed routes between islands, across rivers, or connecting coastal areas. Used for daily commutes, tourism, and connecting communities separated by water.';
      case 'fishing boat':
        return 'A specialized vessel equipped with fishing equipment and storage facilities for commercial or recreational fishing. Features include fishing nets, rod holders, fish storage holds, and sometimes processing equipment. Typically 5-30 meters in length with a sturdy hull designed for various sea conditions. May have outriggers for stability, a raised bow for rough waters, and a flat working deck. Commercial versions often include refrigeration, fish finders, and navigation equipment. The design varies based on fishing method - trawling, longlining, or net fishing. Used by professional fishermen and recreational anglers for catching fish, with storage capacity for preserving the catch during extended trips.';
      case 'jet ski':
        return 'A small personal watercraft (PWC) powered by a jet propulsion system, typically 2-4 meters in length. Features a sleek, streamlined design with a narrow hull and handlebars for steering. The rider sits or stands on the craft, which can reach speeds of 50-70 mph. Characterized by its compact size, maneuverability, and high-speed capabilities. Made from fiberglass or composite materials for lightweight construction. Equipped with a powerful engine that draws water and expels it through a nozzle for propulsion. Popular for recreation, water sports, racing, and quick personal transportation on lakes, rivers, and coastal waters. Requires skill to operate safely.';
      case 'kayak':
        return 'A narrow, lightweight watercraft propelled by a double-bladed paddle, typically 2-5 meters in length. Features a closed or open cockpit design with the paddler sitting low inside the hull. The sleek, pointed bow and stern allow for efficient movement through water. Made from materials like fiberglass, plastic, or inflatable fabric. Sea kayaks are longer and more stable, while whitewater kayaks are shorter and more maneuverable. The design allows for quiet, efficient paddling with minimal water resistance. Popular for recreation, touring, fishing, whitewater sports, and exercise. Requires balance and paddling technique. Can be used solo or in tandem versions.';
      case 'sail boat':
        return 'A boat propelled primarily by wind power through sails mounted on one or more masts. Features a streamlined hull designed to minimize water resistance, with a keel or centerboard for stability. Typically 5-50 meters in length, with sail configurations varying from single-mast sloops to multi-mast schooners. The hull may be made of fiberglass, wood, or composite materials. Equipped with rigging, winches, and sailing hardware for controlling the sails. The design allows for silent, eco-friendly propulsion using wind energy. Used for recreation, racing, cruising, and traditional transportation. Requires knowledge of sailing techniques, wind patterns, and navigation. Offers a unique connection with nature and the elements.';
      case 'speed boat':
        return 'A high-performance motorboat designed for speed and agility, typically 5-15 meters in length. Features a sleek, aerodynamic hull with a pointed bow and powerful engine(s) capable of reaching 60-100+ mph. Characterized by its low profile, streamlined design, and often includes features like racing seats, safety harnesses, and performance instrumentation. The hull design may include deep-V shapes for rough water handling or flat bottoms for speed in calm conditions. Made from lightweight materials like fiberglass or carbon fiber. Equipped with powerful outboard or inboard engines. Used for racing, recreation, water sports, quick transportation, and entertainment. Requires skill and safety equipment for operation.';
      case 'tourist boat':
        return 'A vessel specifically designed for sightseeing and tourism, typically 10-50 meters in length. Features open decks for passenger viewing, comfortable seating, and often includes amenities like restrooms, snack bars, and shaded areas. The design prioritizes passenger comfort and visibility with large windows or open-air configurations. May have multiple levels for different viewing experiences. Equipped with audio systems for guided tours and safety equipment for passenger capacity. The hull is stable and designed for smooth rides in various water conditions. Used for scenic tours, wildlife viewing, historical site visits, and entertainment cruises. Operates on scheduled routes showcasing local attractions, landmarks, and natural beauty.';
      case 'yacht':
        return 'A luxury recreational vessel, typically 12-100+ meters in length, characterized by elegant design and premium amenities. Features include spacious cabins, dining areas, lounges, and often luxury facilities like hot tubs, gyms, and entertainment systems. The hull design is sleek and sophisticated, made from high-quality materials like fiberglass, aluminum, or composite. Equipped with powerful engines for cruising, advanced navigation systems, and sometimes sailing capabilities. The interior is lavishly appointed with fine finishes, modern technology, and comfortable furnishings. Used for leisure, entertainment, private cruising, corporate events, and luxury travel. Represents a symbol of wealth and lifestyle. Can accommodate guests and crew for extended voyages.';
      default:
        return 'A watercraft used for various purposes on water, designed to navigate rivers, lakes, and oceans for transportation, recreation, or commercial activities.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final boatClasses = [
      'Bamboo Raft',
      'Cargo Boat',
      'Ferry Boat',
      'Fishing Boat',
      'Jet Ski',
      'Kayak',
      'Sail Boat',
      'Speed Boat',
      'Tourist Boat',
      'Yacht',
    ];

    return DraggableScrollableSheet(
      expand: false,
      maxChildSize: 0.9,
      minChildSize: 0.4,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(24),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'App Information',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0D47A1),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.close, size: 28),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF0D47A1).withValues(alpha: 0.1),
                      const Color(0xFF1976D2).withValues(alpha: 0.05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFF0D47A1).withValues(alpha: 0.2),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'What is AquaLens?',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0D47A1),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'AquaLens uses advanced machine learning to identify and classify different types of watercraft. The app uses TensorFlow Lite for on-device inference, ensuring fast and private classification without requiring an internet connection.',
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.6,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Boat Classifications',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0D47A1),
                ),
              ),
              const SizedBox(height: 12),
              ...boatClasses.map((boat) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade200),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Theme(
                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      title: Text(
                        boat,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0D47A1),
                        ),
                      ),
                      leading: const Icon(Icons.directions_boat, color: Color(0xFF0D47A1)),
                      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      children: [
                        Text(
                          _getBoatDescription(boat),
                          style: const TextStyle(
                            fontSize: 14,
                            height: 1.5,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )),
            ],
          ),
        );
      },
    );
  }
}

class _HistoryBottomSheet extends StatelessWidget {
  const _HistoryBottomSheet();

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      maxChildSize: 0.9,
      minChildSize: 0.4,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: ValueListenableBuilder<List<ClassificationHistoryEntry>>(
            valueListenable: ClassificationHistory.instance.entries,
            builder: (context, entries, _) {
              return ListView.builder(
                controller: scrollController,
                padding: const EdgeInsets.all(24),
                itemCount: entries.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Recent History',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0D47A1),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: const Icon(Icons.close, size: 28),
                        ),
                      ],
                    );
                  }

                  final entry = entries[index - 1];
                  return Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade200),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(
                              File(entry.imagePath),
                              width: 60,
                              height: 60,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  width: 60,
                                  height: 60,
                                  color: Colors.grey[200],
                                  child: const Icon(Icons.broken_image, color: Colors.grey),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  entry.boatType,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Color(0xFF0D47A1),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Confidence: ${entry.confidence.toStringAsFixed(1)}%',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            _getTimeAgo(entry.timestamp),
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  String _getTimeAgo(DateTime timestamp) {
    final difference = DateTime.now().difference(timestamp);
    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }
}

class _AnalyticsBottomSheet extends StatelessWidget {
  const _AnalyticsBottomSheet();

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      maxChildSize: 0.9,
      minChildSize: 0.4,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: ValueListenableBuilder<List<ClassificationHistoryEntry>>(
            valueListenable: ClassificationHistory.instance.entries,
            builder: (context, entries, _) {
              return ListView(
                controller: scrollController,
                padding: const EdgeInsets.all(24),
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Analytics',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0D47A1),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: const Icon(Icons.close, size: 28),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF0D47A1).withValues(alpha: 0.1),
                          const Color(0xFF1976D2).withValues(alpha: 0.05),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Total Scans',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${entries.length}',
                          style: const TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0D47A1),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (entries.isNotEmpty) ...[
                    const Text(
                      'Most Detected per Class',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0D47A1),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildBarChart(entries),
                    const SizedBox(height: 24),
                    const Text(
                      'Detailed Statistics',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0D47A1),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ..._getMostDetected(entries),
                  ] else
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Column(
                          children: [
                            Icon(
                              Icons.bar_chart,
                              size: 48,
                              color: Colors.grey[400],
                              ),
                            const SizedBox(height: 12),
                            Text(
                              'No scan data yet',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildBarChart(List<ClassificationHistoryEntry> entries) {
    final Map<String, int> boatCounts = {};
    for (final entry in entries) {
      boatCounts[entry.boatType] = (boatCounts[entry.boatType] ?? 0) + 1;
    }

    final sorted = boatCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    final top5 = sorted.take(5).toList();
    final maxCount = top5.isNotEmpty ? top5.first.value : 1;

    return SizedBox(
      height: 150,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: top5.map((entry) {
          final heightFactor = entry.value / maxCount;
          return Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                '${entry.value}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0D47A1),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                width: 30,
                height: 100 * heightFactor,
                decoration: BoxDecoration(
                  color: const Color(0xFF0D47A1),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: 60,
                child: Text(
                  entry.key.split(' ').first, // Shorten name
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  List<Widget> _getMostDetected(
    List<ClassificationHistoryEntry> entries,
  ) {
    final Map<String, int> boatCounts = {};
    for (final entry in entries) {
      boatCounts[entry.boatType] = (boatCounts[entry.boatType] ?? 0) + 1;
    }

    final sorted = boatCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sorted.map((entry) {
      final percentage = (entry.value / entries.length * 100).toStringAsFixed(1);
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                entry.key,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0D47A1),
                ),
              ),
            ),
            Text(
              '${entry.value} scans',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF0D47A1),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF0D47A1).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$percentage%',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0D47A1),
                ),
              ),
            ),
          ],
        ),
      );
    }).toList();
  }
}

class _ResultPopupDialog extends StatelessWidget {
  final ClassificationResult result;
  final File imageFile;

  const _ResultPopupDialog({required this.result, required this.imageFile});

  Color _getConfidenceColor(double confidence) {
    if (confidence >= 80) return const Color(0xFF4CAF50);
    if (confidence >= 60) return const Color(0xFFFF9800);
    return const Color(0xFFF44336);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header with close button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Classification Results',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0D47A1),
                      letterSpacing: 0.3,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 24),
                    color: Colors.grey[600],
                    onPressed: () => Navigator.of(context).pop(),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.grey[100],
                      padding: const EdgeInsets.all(8),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Image preview
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  height: 220,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Image.file(
                    imageFile,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return const Center(
                        child: Icon(
                          Icons.error_outline,
                          size: 48,
                          color: Colors.grey,
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Top prediction card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF0D47A1).withValues(alpha: 0.1),
                      const Color(0xFF1976D2).withValues(alpha: 0.05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFF0D47A1).withValues(alpha: 0.3),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0D47A1).withValues(alpha: 0.1),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      result.boatType,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0D47A1),
                        letterSpacing: 0.3,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: _getConfidenceColor(
                          result.confidence,
                        ).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${result.confidence.toStringAsFixed(1)}% Confidence',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: _getConfidenceColor(result.confidence),
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // All predictions graph
              const Text(
                'All Boat Types & Accuracy',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0D47A1),
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Column(
                  children: result.scores.map((score) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  score.label,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                    letterSpacing: 0.1,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                '${score.confidence.toStringAsFixed(1)}%',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: _getConfidenceColor(score.confidence),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: LinearProgressIndicator(
                              value: score.confidence / 100,
                              minHeight: 10,
                              backgroundColor: Colors.grey[300],
                              valueColor: AlwaysStoppedAnimation<Color>(
                                _getConfidenceColor(score.confidence),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 24),
              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: const BorderSide(
                          color: Color(0xFF0D47A1),
                          width: 2,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        'Close',
                        style: TextStyle(
                          color: Color(0xFF0D47A1),
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ResultScreen(
                              result: result,
                              imageFile: imageFile,
                            ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0D47A1),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 4,
                      ),
                      child: const Text(
                        'View Details',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
