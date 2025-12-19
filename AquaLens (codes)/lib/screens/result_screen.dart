import 'dart:io';
import 'package:flutter/material.dart';
import '../services/classifier.dart';

class ResultScreen extends StatelessWidget {
  final ClassificationResult result;
  final File imageFile;

  const ResultScreen({
    super.key,
    required this.result,
    required this.imageFile,
  });

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

  String _getTypicalUsage(String boatType) {
    switch (boatType.toLowerCase()) {
      case 'bamboo raft':
        return 'Transportation, Fishing, Traditional Use';
      case 'cargo boat':
        return 'Commercial Transport, Trade, Logistics';
      case 'ferry boat':
        return 'Passenger Transport, Vehicle Transport, Public Transit';
      case 'fishing boat':
        return 'Commercial Fishing, Recreational Fishing';
      case 'jet ski':
        return 'Recreation, Water Sports, Personal Transport';
      case 'kayak':
        return 'Recreation, Touring, Whitewater Sports, Exercise';
      case 'sail boat':
        return 'Recreation, Racing, Sailing, Traditional Transport';
      case 'speed boat':
        return 'Racing, Recreation, Water Sports, Quick Transport';
      case 'tourist boat':
        return 'Sightseeing, Tourism, Passenger Tours';
      case 'yacht':
        return 'Luxury Cruising, Entertainment, Leisure, Private Use';
      default:
        return 'Various water activities';
    }
  }

  Color _getConfidenceColor(double confidence) {
    if (confidence >= 95) return const Color(0xFF4CAF50); // Green
    if (confidence >= 80) return const Color(0xFFFF9800); // Orange
    return const Color(0xFFF44336); // Red
  }

  String _getAccuracyRating(double confidence) {
    if (confidence >= 95) return 'Excellent';
    if (confidence >= 85) return 'Very Good';
    if (confidence >= 70) return 'Good';
    if (confidence >= 60) return 'Fair';
    return 'Low';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = Theme.of(context).scaffoldBackgroundColor;
    final textColor = isDark ? Colors.white : const Color(0xFF1A1A1A);
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final accentColor = const Color(0xFF2196F3);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: isDark ? Colors.white : Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Analysis Results',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black,
            fontSize: 18,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Title + main image card
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      result.boatType,
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: accentColor,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: Container(
                          height: 280,
                          width: double.infinity,
                          color: isDark ? Colors.grey[900] : Colors.grey[200],
                          child: Image.file(imageFile, fit: BoxFit.cover),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Results row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Expanded(
                      child: _MetricCard(
                        label: 'Confidence',
                        value: '${result.confidence.toStringAsFixed(1)}%',
                        color: _getConfidenceColor(result.confidence),
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _MetricCard(
                        label: 'Rating',
                        value: _getAccuracyRating(result.confidence),
                        color: accentColor,
                        isDark: isDark,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Probability Distribution
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Probability Distribution',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 20),
                      ...result.scores.take(5).map((score) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    score.label,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                      fontSize: 15,
                                      color: textColor,
                                    ),
                                  ),
                                  Text(
                                    '${score.confidence.toStringAsFixed(1)}%',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: _getConfidenceColor(score.confidence),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: score.confidence / 100,
                                  backgroundColor: isDark ? Colors.grey[800] : Colors.grey[100],
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    _getConfidenceColor(score.confidence),
                                  ),
                                  minHeight: 8,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Info Cards
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    _InfoCard(
                      title: 'Typical Usage',
                      content: _getTypicalUsage(result.boatType),
                      icon: Icons.directions_boat,
                      isDark: isDark,
                      accentColor: accentColor,
                    ),
                    const SizedBox(height: 16),
                    _InfoCard(
                      title: 'Description',
                      content: _getBoatDescription(result.boatType),
                      icon: Icons.info_outline,
                      isDark: isDark,
                      accentColor: accentColor,
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Done Button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.check),
                  label: const Text('Done'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool isDark;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: color.withValues(alpha: 0.2),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white60 : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final String content;
  final IconData icon;
  final bool isDark;
  final Color accentColor;

  const _InfoCard({
    required this.title,
    required this.content,
    required this.icon,
    required this.isDark,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 24, color: accentColor),
              ),
              const SizedBox(width: 16),
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            content,
            style: TextStyle(
              fontSize: 15,
              height: 1.6,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
