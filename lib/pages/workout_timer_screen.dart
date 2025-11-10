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
    late Timer _timer;
    bool _isRunning = false;
    bool _isCompleted = false;

    @override
    void initState() {
      super.initState();
      _secondsRemaining = widget.duration * 60;
    }

    @override
    void dispose() {
      _timer.cancel();
      super.dispose();
    }

    void _startTimer() {
      setState(() {
        _isRunning = true;
      });

      _timer = Timer.periodic(Duration(seconds: 1), (timer) {
        setState(() {
          if (_secondsRemaining > 0) {
            _secondsRemaining--;
          } else {
            _timer.cancel();
            _isRunning = false;
            _isCompleted = true;
            widget.onComplete();
          }
        });
      });
    }

    void _pauseTimer() {
      setState(() {
        _isRunning = false;
      });
      _timer.cancel();
    }

    void _resetTimer() {
      setState(() {
        _secondsRemaining = widget.duration * 60;
        _isRunning = false;
        _isCompleted = false;
      });
      _timer.cancel();
    }

    String _formatTime(int seconds) {
      int minutes = seconds ~/ 60;
      int remainingSeconds = seconds % 60;
      return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
    }

    @override
    Widget build(BuildContext context) {
      final progress = 1.0 - (_secondsRemaining / (widget.duration * 60));

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
        child: Column(
          children: [
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

            if (_isCompleted)
              ElevatedButton(
                onPressed: () {
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
        ),
      );
    }
  }