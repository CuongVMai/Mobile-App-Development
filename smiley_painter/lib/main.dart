// In-Class Activity 06 — Drawing with Flutter
// Student: Cuong Mai
// Date: September 26, 2026

import 'dart:math';

import 'package:flutter/material.dart';

void main() => runApp(const SmileyApp());

enum FaceType { classic, sleepy, surprised, bullseye }

class SmileyApp extends StatelessWidget {
  const SmileyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smiley Painter Lab',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: const DrawingPlayground(),
    );
  }
}

class DrawingPlayground extends StatefulWidget {
  const DrawingPlayground({super.key});

  @override
  State<DrawingPlayground> createState() => _DrawingPlaygroundState();
}

class _DrawingPlaygroundState extends State<DrawingPlayground> {
  double mood = 0.8;
  FaceType faceType = FaceType.classic;
  Color? customColor;
  final Random random = Random();

  String faceName(FaceType type) {
    switch (type) {
      case FaceType.classic:
        return 'Classic';
      case FaceType.sleepy:
        return 'Sleepy';
      case FaceType.surprised:
        return 'Surprised';
      case FaceType.bullseye:
        return 'Bullseye';
    }
  }

  String get moodName {
    if (mood < 0.35) return 'Sad';
    if (mood <= 0.7) return 'Calm';
    return 'Happy';
  }

  Color get faceColor {
    if (customColor != null) return customColor!;
    if (mood < 0.35) return Colors.lightBlue.shade200;
    if (mood <= 0.7) return Colors.yellow.shade600;
    return Colors.green.shade300;
  }

  void showFeedback(String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  void selectFace(FaceType type) {
    setState(() => faceType = type);
    showFeedback('${faceName(type)} selected.');
  }

  void cycleFace() {
    final nextIndex = (faceType.index + 1) % FaceType.values.length;
    selectFace(FaceType.values[nextIndex]);
  }

  void randomizeFace() {
    const colors = [
      Colors.pinkAccent,
      Colors.lightGreenAccent,
      Colors.lightBlueAccent,
      Colors.amber,
      Colors.deepOrangeAccent,
      Colors.purpleAccent,
    ];

    setState(() {
      mood = random.nextDouble();
      customColor = colors[random.nextInt(colors.length)];
    });

    final colorMessage = faceType == FaceType.bullseye
        ? 'Face color saved for the next face.'
        : 'Face color changed.';

    showFeedback(
      'Random mood: $moodName (${mood.toStringAsFixed(2)}). '
      '$colorMessage',
    );
  }

  Widget buildControls() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        DropdownButton<FaceType>(
          value: faceType,
          isExpanded: true,
          items: FaceType.values.map((type) {
            return DropdownMenuItem<FaceType>(
              value: type,
              child: Text(faceName(type)),
            );
          }).toList(),
          onChanged: (type) {
            if (type != null) selectFace(type);
          },
        ),
        const SizedBox(height: 12),
        Text(
          'Mood: $moodName — ${mood.toStringAsFixed(2)}',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        Slider(
          value: mood,
          label: mood.toStringAsFixed(2),
          onChanged: (value) {
            setState(() {
              mood = value;
              // Restore mood-based colors when the slider moves.
              customColor = null;
            });
          },
        ),
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [Text('Sad'), Text('Calm'), Text('Happy')],
        ),
        const SizedBox(height: 16),
        const Text(
          'Tap the drawing to switch designs.\n'
          'Long-press to randomize mood and face color.',
          textAlign: TextAlign.center,
        ),
        if (faceType == FaceType.bullseye) ...[
          const SizedBox(height: 8),
          const Text(
            'The bullseye keeps its three fixed colors.',
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('CustomPainter Smiley Lab')),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isLandscape = constraints.maxWidth > constraints.maxHeight;

            final drawing = LayoutBuilder(
              builder: (context, drawingConstraints) {
                final side = min(
                  drawingConstraints.maxWidth,
                  drawingConstraints.maxHeight,
                );

                return Center(
                  child: Semantics(
                    label: faceType == FaceType.bullseye
                        ? 'Three-circle bullseye'
                        : '${faceName(faceType)} face, $moodName mood',
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: cycleFace,
                      onLongPress: randomizeFace,
                      child: CustomPaint(
                        size: Size.square(side),
                        painter: SmileyPainter(
                          mood: mood,
                          faceType: faceType,
                          faceColor: faceColor,
                        ),
                      ),
                    ),
                  ),
                );
              },
            );

            final controls = SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: buildControls(),
            );

            if (isLandscape) {
              return Row(
                children: [
                  Expanded(child: drawing),
                  Expanded(child: controls),
                ],
              );
            }

            return Column(
              children: [
                Expanded(child: drawing),
                SizedBox(
                  height: min(280.0, constraints.maxHeight * 0.48),
                  child: controls,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class SmileyPainter extends CustomPainter {
  SmileyPainter({
    required this.mood,
    required this.faceType,
    required this.faceColor,
  });

  final double mood;
  final FaceType faceType;
  final Color faceColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // Leave enough space above the face for the hat.
    final radius = size.shortestSide * 0.35;

    // Micro-activity: three concentric circles.
    if (faceType == FaceType.bullseye) {
      canvas.drawCircle(center, radius, Paint()..color = Colors.red);
      canvas.drawCircle(center, radius * 0.65, Paint()..color = Colors.white);
      canvas.drawCircle(center, radius * 0.3, Paint()..color = Colors.blue);
      return;
    }

    final facePaint = Paint()
      ..color = faceColor
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = Colors.black87
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.035;

    final eyePaint = Paint()
      ..color = Colors.black87
      ..style = PaintingStyle.fill;

    final linePaint = Paint()
      ..color = Colors.black87
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.04
      ..strokeCap = StrokeCap.round;

    // Draw the face and border first.
    canvas.drawCircle(center, radius, facePaint);
    canvas.drawCircle(center, radius, borderPaint);

    // Micro-activity: red rectangular crown and brim.
    // Temporarily move this whole block above the face drawing
    // calls to test layering, then move it back here.
    if (faceType == FaceType.classic) {
      final hatPaint = Paint()..color = Colors.red;

      // Tall crown.
      canvas.drawRect(
        Rect.fromCenter(
          center: center + Offset(0, -radius * 1.1),
          width: radius * 0.75,
          height: radius * 0.4,
        ),
        hatPaint,
      );

      // Wide brim overlapping the top of the face.
      canvas.drawRect(
        Rect.fromCenter(
          center: center + Offset(0, -radius * 0.95),
          width: radius * 1.2,
          height: radius * 0.25,
        ),
        hatPaint,
      );
    }

    final leftEye = center + Offset(-radius * 0.35, -radius * 0.25);
    final rightEye = center + Offset(radius * 0.35, -radius * 0.25);

    switch (faceType) {
      case FaceType.classic:
        canvas.drawCircle(leftEye, radius * 0.09, eyePaint);
        canvas.drawCircle(rightEye, radius * 0.09, eyePaint);
        drawMoodMouth(canvas, center, radius, linePaint);
        break;

      case FaceType.sleepy:
        // Closed eyes.
        for (final eye in [leftEye, rightEye]) {
          final eyeRect = Rect.fromCenter(
            center: eye,
            width: radius * 0.3,
            height: radius * 0.15,
          );

          canvas.drawArc(eyeRect, 0, pi, false, linePaint);
        }

        drawMoodMouth(canvas, center, radius, linePaint, softness: 0.45);
        break;

      case FaceType.surprised:
        // Larger eyes.
        canvas.drawCircle(leftEye, radius * 0.14, eyePaint);
        canvas.drawCircle(rightEye, radius * 0.14, eyePaint);

        // Open mouth.
        final mouthRect = Rect.fromCenter(
          center: center + Offset(0, radius * 0.35),
          width: radius * 0.3,
          height: radius * (0.28 + mood * 0.28),
        );

        canvas.drawOval(mouthRect, eyePaint);

        // Raised eyebrows.
        for (final eye in [leftEye, rightEye]) {
          canvas.drawLine(
            eye + Offset(-radius * 0.12, -radius * 0.23),
            eye + Offset(radius * 0.12, -radius * 0.23),
            linePaint,
          );
        }
        break;

      case FaceType.bullseye:
        // Already drawn above.
        break;
    }
  }

  void drawMoodMouth(
    Canvas canvas,
    Offset center,
    double radius,
    Paint paint, {
    double softness = 1.0,
  }) {
    final width = radius * 1.1 * softness;

    if (mood < 0.35) {
      final sadness = (0.35 - mood) / 0.35;

      final mouthRect = Rect.fromCenter(
        center: center + Offset(0, radius * 0.45),
        width: width,
        height: radius * (0.18 + sadness * 0.4) * softness,
      );

      // Upper arc makes a frown.
      canvas.drawArc(mouthRect, 1.15 * pi, 0.7 * pi, false, paint);
    } else {
      final happiness = (mood - 0.35) / 0.65;

      final mouthRect = Rect.fromCenter(
        center: center + Offset(0, radius * 0.2),
        width: width,
        height: radius * (0.12 + happiness * 0.7) * softness,
      );

      // Lower arc makes a smile.
      canvas.drawArc(mouthRect, 0.15 * pi, 0.7 * pi, false, paint);
    }
  }

  @override
  bool shouldRepaint(covariant SmileyPainter oldDelegate) {
    return oldDelegate.mood != mood ||
        oldDelegate.faceType != faceType ||
        oldDelegate.faceColor != faceColor;
  }
}
