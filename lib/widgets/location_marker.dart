import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';

/// Маркер текущей позиции со стрелкой направления
/// 
/// При движении показывает стрелку в направлении движения.
/// При остановке показывает направление компаса (куда направлен телефон).
class LocationMarker extends StatefulWidget {
  /// Направление движения в градусах (0-360), 0 = север
  final double movementHeading;
  
  /// Скорость в м/с
  final double speed;
  
  /// Показывать ли направление компаса при остановке
  final bool showCompassWhenStationary;
  
  /// Размер маркера
  final double size;

  const LocationMarker({
    super.key,
    this.movementHeading = 0,
    this.speed = 0,
    this.showCompassWhenStationary = true,
    this.size = 50,
  });

  @override
  State<LocationMarker> createState() => _LocationMarkerState();
}

class _LocationMarkerState extends State<LocationMarker>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  
  // Компас
  StreamSubscription<CompassEvent>? _compassSubscription;
  double _compassHeading = 0;
  bool _compassAvailable = false;
  
  // Порог скорости для определения движения (м/с)
  static const double _movementThreshold = 0.3; // ~1 км/ч
  
  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    
    _initCompass();
  }
  
  Future<void> _initCompass() async {
    try {
      // Проверяем доступность компаса
      _compassSubscription = FlutterCompass.events?.listen(
        (CompassEvent event) {
          if (event.heading != null && mounted) {
            setState(() {
              _compassHeading = event.heading!;
              _compassAvailable = true;
            });
          }
        },
        onError: (error) {
          debugPrint('Compass error: $error');
        },
      );
    } catch (e) {
      debugPrint('Compass not available: $e');
    }
  }
  
  @override
  void dispose() {
    _pulseController.dispose();
    _compassSubscription?.cancel();
    super.dispose();
  }
  
  /// Движется ли пользователь
  bool get _isMoving => widget.speed > _movementThreshold;
  
  /// Текущий heading для отображения
  double get _displayHeading {
    if (_isMoving) {
      // При движении используем направление движения
      return widget.movementHeading;
    } else if (widget.showCompassWhenStationary && _compassAvailable) {
      // При остановке используем компас
      return _compassHeading;
    }
    // Если нет компаса и не движемся - последнее известное направление
    return widget.movementHeading;
  }

  @override
  Widget build(BuildContext context) {
    final isMoving = _isMoving;
    final heading = _displayHeading;
    
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            // Внешний пульсирующий круг (только при движении)
            if (isMoving)
              Transform.scale(
                scale: _pulseAnimation.value,
                child: Container(
                  width: widget.size,
                  height: widget.size,
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            
            // Средний круг точности
            Container(
              width: widget.size * 0.6,
              height: widget.size * 0.6,
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
            ),
            
            // Стрелка направления
            Transform.rotate(
              angle: heading * math.pi / 180,
              child: CustomPaint(
                size: Size(widget.size * 0.5, widget.size * 0.5),
                painter: _ArrowPainter(
                  color: Colors.blue,
                  borderColor: Colors.white,
                  showArrow: isMoving || (_compassAvailable && widget.showCompassWhenStationary),
                ),
              ),
            ),
            
            // Точка в центре (только при остановке без компаса)
            if (!isMoving && !_compassAvailable)
              Container(
                width: widget.size * 0.35,
                height: widget.size * 0.35,
                decoration: BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white,
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Отрисовщик стрелки направления
class _ArrowPainter extends CustomPainter {
  final Color color;
  final Color borderColor;
  final bool showArrow;

  _ArrowPainter({
    required this.color,
    required this.borderColor,
    required this.showArrow,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (!showArrow) return;
    
    final center = Offset(size.width / 2, size.height / 2);
    final arrowLength = size.width * 0.45;
    final arrowWidth = size.width * 0.25;
    
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    
    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeJoin = StrokeJoin.round;
    
    // Стрелка направлена вверх (север)
    // Координаты: верхушка, левый угол, правый угол
    final path = Path();
    
    // Верхушка стрелки (север)
    path.moveTo(center.dx, center.dy - arrowLength);
    
    // Левый угол
    path.lineTo(center.dx - arrowWidth / 2, center.dy + arrowLength * 0.3);
    
    // Центр вогнутости
    path.lineTo(center.dx, center.dy + arrowLength * 0.1);
    
    // Правый угол
    path.lineTo(center.dx + arrowWidth / 2, center.dy + arrowLength * 0.3);
    
    path.close();
    
    canvas.drawPath(path, paint);
    canvas.drawPath(path, borderPaint);
    
    // Маленький круг в центре
    final centerCirclePaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(center, 4, centerCirclePaint);
  }

  @override
  bool shouldRepaint(covariant _ArrowPainter oldDelegate) {
    return color != oldDelegate.color ||
           borderColor != oldDelegate.borderColor ||
           showArrow != oldDelegate.showArrow;
  }
}
