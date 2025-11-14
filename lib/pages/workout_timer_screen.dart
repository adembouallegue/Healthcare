// workout_timer_screen.dart
import 'package:flutter/material.dart';
import 'exercise_library.dart';
import 'workout_controller.dart';
import 'dart:async';

class WorkoutTimerScreen extends StatefulWidget {
  final Exercise exercise;
  final int duration;
  final WorkoutSession session;
  final VoidCallback onComplete;

  const WorkoutTimerScreen({
    super.key,
    required this.exercise,
    required this.duration,
    required this.session,
    required this.onComplete,
  });

  @override
  State<WorkoutTimerScreen> createState() => _WorkoutTimerScreenState();
}

class _WorkoutTimerScreenState extends State<WorkoutTimerScreen> {
  int _secondsRemaining = 0;
  Timer? _timer;
  bool _isRunning = false;
  bool _isCompleted = false;
  bool _hasError = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _initializeTimer();
  }

  void _initializeTimer() {
    try {
      print('=== TIMER INITIALIZATION ===');
      print('🎯 Exercise: ${widget.exercise.name}');
      print('⏱️ Requested Duration: ${widget.duration} minutes');
      print('🆔 Exercise ID: ${widget.exercise.id}');

      // Validate inputs
      if (widget.duration <= 0) {
        throw ArgumentError('Duration must be positive: ${widget.duration}');
      }

      if (widget.exercise.id.isEmpty) {
        throw ArgumentError('Exercise ID is empty');
      }

      _secondsRemaining = widget.duration * 60;
      print('✅ Timer initialized: $_secondsRemaining seconds ($_secondsRemaining)');
      print('============================');

    } catch (e, stackTrace) {
      print('❌ ERROR in timer initialization: $e');
      print('📝 Stack trace: $stackTrace');

      setState(() {
        _hasError = true;
        _errorMessage = 'Timer error: $e';
        _secondsRemaining = 600; // 10 minutes fallback
      });
    }
  }

  @override
  void dispose() {
    print('🛑 Disposing timer for: ${widget.exercise.name}');
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    try {
      print('▶️ Starting timer for: ${widget.exercise.name}');

      if (_secondsRemaining <= 0) {
        throw StateError('Invalid timer state: $_secondsRemaining seconds remaining');
      }

      setState(() {
        _isRunning = true;
        _hasError = false;
      });

      _timer?.cancel(); // Cancel any existing timer

      _timer = Timer.periodic(Duration(seconds: 1), (timer) {
        try {
          if (!mounted) {
            print('⚠️ Widget not mounted, cancelling timer');
            timer.cancel();
            return;
          }

          setState(() {
            if (_secondsRemaining > 0) {
              _secondsRemaining--;

              // Log every minute
              if (_secondsRemaining % 60 == 0) {
                print('⏰ ${_secondsRemaining ~/ 60} minutes remaining for ${widget.exercise.name}');
              }
            } else {
              // Timer completed
              print('✅ Timer completed for: ${widget.exercise.name}');
              _timer?.cancel();
              _isRunning = false;
              _isCompleted = true;

              // Call completion callback
              if (widget.onComplete != null) {
                widget.onComplete();
              } else {
                print('⚠️ onComplete callback is null');
              }
            }
          });
        } catch (e, stackTrace) {
          print('❌ ERROR in timer tick: $e');
          print('📝 Stack trace: $stackTrace');
          timer.cancel();

          if (mounted) {
            setState(() {
              _hasError = true;
              _errorMessage = 'Timer error: $e';
              _isRunning = false;
            });
          }
        }
      });

      print('✅ Timer started successfully');

    } catch (e, stackTrace) {
      print('❌ ERROR starting timer: $e');
      print('📝 Stack trace: $stackTrace');

      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Failed to start timer: $e';
          _isRunning = false;
        });
      }
    }
  }

  void _pauseTimer() {
    print('⏸️ Pausing timer for: ${widget.exercise.name}');
    try {
      setState(() {
        _isRunning = false;
      });
      _timer?.cancel();
      print('✅ Timer paused at $_secondsRemaining seconds');
    } catch (e) {
      print('❌ ERROR pausing timer: $e');
    }
  }

  void _resetTimer() {
    print('🔄 Resetting timer for: ${widget.exercise.name}');
    try {
      setState(() {
        _secondsRemaining = widget.duration * 60;
        _isRunning = false;
        _isCompleted = false;
        _hasError = false;
      });
      _timer?.cancel();
      print('✅ Timer reset to $_secondsRemaining seconds');
    } catch (e) {
      print('❌ ERROR resetting timer: $e');
    }
  }

  String _formatTime(int seconds) {
    try {
      if (seconds < 0) seconds = 0;
      int minutes = seconds ~/ 60;
      int remainingSeconds = seconds % 60;
      return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
    } catch (e) {
      return '00:00';
    }
  }

  double _getProgress() {
    try {
      if (widget.duration <= 0) return 0.0;
      final totalSeconds = widget.duration * 60;
      if (totalSeconds <= 0) return 0.0;
      return 1.0 - (_secondsRemaining / totalSeconds);
    } catch (e) {
      return 0.0;
    }
  }

  Widget _buildErrorWidget() {
    return Container(
      padding: EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            color: Colors.red,
            size: 50,
          ),
          SizedBox(height: 16),
          Text(
            'Timer Error',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
          ),
          SizedBox(height: 8),
          Text(
            _errorMessage,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
            ),
          ),
          SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: Text('Close'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimerWidget() {
    final progress = _getProgress();

    return Column(
      children: [
        // Exercise Header
        Text(
          widget.exercise.name,
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 8),
        Text(
          '${widget.exercise.calculateCalories(widget.duration)} calories',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
        SizedBox(height: 20),

        // Progress Circle
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 200,
              height: 200,
              child: CircularProgressIndicator(
                value: progress,
                strokeWidth: 12,
                backgroundColor: Colors.grey[300],
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF9DCEFF)),
              ),
            ),
            Column(
              children: [
                Text(
                  _formatTime(_secondsRemaining),
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Time remaining',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),

        SizedBox(height: 30),

        // Control Buttons
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            if (!_isCompleted) ...[
              ElevatedButton(
                onPressed: _isRunning ? _pauseTimer : _startTimer,
                child: Icon(
                  _isRunning ? Icons.pause : Icons.play_arrow,
                  size: 30,
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF9DCEFF),
                  foregroundColor: Colors.white,
                  shape: CircleBorder(),
                  padding: EdgeInsets.all(20),
                ),
              ),
              ElevatedButton(
                onPressed: _resetTimer,
                child: Icon(Icons.replay, size: 30),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey,
                  foregroundColor: Colors.white,
                  shape: CircleBorder(),
                  padding: EdgeInsets.all(20),
                ),
              ),
            ],
          ],
        ),

        Spacer(),

        // Instructions
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Instructions:',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 10),
                Text(
                  widget.exercise.instructions,
                  style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                ),
                SizedBox(height: 10),
                Text(
                  'Target Muscles: ${widget.exercise.muscles.join(', ')}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Completed Button
        if (_isCompleted)
          ElevatedButton(
            onPressed: () {
              print('🎉 Workout completed, closing timer');
              Navigator.of(context).pop();
            },
            child: Text(
              'Workout Completed!',
              style: TextStyle(fontSize: 18),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 40, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(25),
          topRight: Radius.circular(25),
        ),
      ),
      child: _hasError ? _buildErrorWidget() : _buildTimerWidget(),
    );
  }
}