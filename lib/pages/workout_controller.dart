// workout_controller.dart
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';

// Import the Exercise class from exercise_library
import 'exercise_library.dart';

class WorkoutSession {
  final String id;
  final String exerciseId;
  final String exerciseName;
  final String category;
  final int duration;
  final int caloriesBurned;
  final DateTime completedAt;
  final bool isCompleted;

  WorkoutSession({
    required this.id,
    required this.exerciseId,
    required this.exerciseName,
    required this.category,
    required this.duration,
    required this.caloriesBurned,
    required this.completedAt,
    this.isCompleted = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'exerciseId': exerciseId,
      'exerciseName': exerciseName,
      'category': category,
      'duration': duration,
      'caloriesBurned': caloriesBurned,
      'completedAt': completedAt.millisecondsSinceEpoch,
      'isCompleted': isCompleted,
    };
  }

  factory WorkoutSession.fromMap(Map<String, dynamic> data) {
    return WorkoutSession(
      id: data['id'] ?? '',
      exerciseId: data['exerciseId'] ?? '',
      exerciseName: data['exerciseName'] ?? '',
      category: data['category'] ?? '',
      duration: data['duration'] ?? 0,
      caloriesBurned: data['caloriesBurned'] ?? 0,
      completedAt: DateTime.fromMillisecondsSinceEpoch(data['completedAt'] ?? 0),
      isCompleted: data['isCompleted'] ?? false,
    );
  }
}

// Extension for copyWith method
extension WorkoutSessionCopyWith on WorkoutSession {
  WorkoutSession copyWith({
    bool? isCompleted,
  }) {
    return WorkoutSession(
      id: id,
      exerciseId: exerciseId,
      exerciseName: exerciseName,
      category: category,
      duration: duration,
      caloriesBurned: caloriesBurned,
      completedAt: completedAt,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}

class WorkoutController extends GetxController {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  var selectedCategory = 'push'.obs;
  var currentWorkoutSessions = <WorkoutSession>[].obs;
  var isLoading = false.obs;
  var todayCaloriesBurned = 0.obs;
  var todayWorkoutTime = 0.obs;

  @override
  void onInit() {
    super.onInit();
    loadTodayWorkouts();
  }

  Future<void> loadTodayWorkouts() async {
    try {
      isLoading(true);
      final user = _auth.currentUser;
      if (user == null) return;

      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);

      final snapshot = await _firestore
          .collection('Users')
          .doc(user.uid)
          .collection('Workouts')
          .where('completedAt', isGreaterThanOrEqualTo: startOfDay.millisecondsSinceEpoch)
          .get();

      currentWorkoutSessions.assignAll(
          snapshot.docs.map((doc) => WorkoutSession.fromMap(doc.data())).toList()
      );

      _calculateTodayTotals();
    } catch (e) {
      print('❌ Error loading workouts: $e');
    } finally {
      isLoading(false);
    }
  }

  void _calculateTodayTotals() {
    todayCaloriesBurned.value = currentWorkoutSessions
        .where((session) => session.isCompleted)
        .fold(0, (sum, session) => sum + session.caloriesBurned);

    todayWorkoutTime.value = currentWorkoutSessions
        .where((session) => session.isCompleted)
        .fold(0, (sum, session) => sum + session.duration);
  }

  WorkoutSession startWorkout(Exercise exercise, int duration) {
    final session = WorkoutSession(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      exerciseId: exercise.id,
      exerciseName: exercise.name,
      category: exercise.category,
      duration: duration,
      caloriesBurned: exercise.calculateCalories(duration),
      completedAt: DateTime.now(),
      isCompleted: false,
    );

    currentWorkoutSessions.add(session);
    return session;
  }

  Future<void> completeWorkout(WorkoutSession session) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final index = currentWorkoutSessions.indexWhere((s) => s.id == session.id);
      if (index != -1) {
        currentWorkoutSessions[index] = session.copyWith(isCompleted: true);
      }

      await _firestore
          .collection('Users')
          .doc(user.uid)
          .collection('Workouts')
          .doc(session.id)
          .set(session.copyWith(isCompleted: true).toMap());

      _updateHealthDataCalories(session.caloriesBurned);
      _calculateTodayTotals();

      print('✅ Workout completed: ${session.exerciseName} - ${session.caloriesBurned} calories');
    } catch (e) {
      print('❌ Error completing workout: $e');
    }
  }

  void _updateHealthDataCalories(int caloriesBurned) {
    try {
      // Use dynamic typing to avoid import conflicts
      dynamic healthController = Get.find(tag: 'HealthDataController');

      // Access properties using string keys to avoid type issues
      var healthData = healthController.healthData.value;

      // Parse current calories safely
      String currentCaloriesText = healthData.calories ?? '0 kCal';
      int currentCalories = int.tryParse(currentCaloriesText.split(' ')[0]) ?? 0;
      currentCalories += caloriesBurned;

      int calorieTarget = healthData.calorieTarget ?? 2400;
      int caloriesLeftValue = calorieTarget - currentCalories;
      if (caloriesLeftValue < 0) caloriesLeftValue = 0;

      double newProgress = (currentCalories / calorieTarget) * 100;

      // Update using the update method
      healthController.healthData.update((val) {
        val.calories = "${currentCalories} kCal";
        val.caloriesLeft = "${caloriesLeftValue}kCal\nleft";
        val.progressValue = newProgress;
      });

      // Update progress notifier
      healthController.progressNotifier.value = newProgress;

      // Save the data
      healthController.saveHealthData();
    } catch (e) {
      print('❌ Error updating health data: $e');
      print('⚠️ Health controller might not be initialized yet');
    }
  }

  List<Exercise> getExercisesBySelectedCategory() {
    return ExerciseLibrary.getExercisesByCategory(selectedCategory.value);
  }

  double getTodayWorkoutProgress() {
    final totalSessions = currentWorkoutSessions.length;
    final completedSessions = currentWorkoutSessions.where((s) => s.isCompleted).length;

    return totalSessions > 0 ? completedSessions / totalSessions : 0.0;
  }
}