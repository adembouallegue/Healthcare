// workout_controller.dart - Fixed version
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:healthcare/pages/home_view.dart';
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
    int? caloriesBurned,
    DateTime? completedAt,
  }) {
    return WorkoutSession(
      id: id,
      exerciseId: exerciseId,
      exerciseName: exerciseName,
      category: category,
      duration: duration,
      caloriesBurned: caloriesBurned ?? this.caloriesBurned,
      completedAt: completedAt ?? this.completedAt,
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

  // Add this for latest workouts
  var latestCompletedWorkouts = <WorkoutSession>[].obs;

  @override
  void onInit() {
    super.onInit();
    loadTodayWorkouts();
    loadLatestWorkouts();
  }

  Future<void> loadTodayWorkouts() async {
    try {
      isLoading(true);
      final user = _auth.currentUser;
      if (user == null) return;

      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);

      // First try with ordering
      try {
        final snapshot = await _firestore
            .collection('Users')
            .doc(user.uid)
            .collection('Workouts')
            .where('completedAt', isGreaterThanOrEqualTo: startOfDay.millisecondsSinceEpoch)
            .orderBy('completedAt', descending: true)
            .get();

        currentWorkoutSessions.assignAll(
            snapshot.docs.map((doc) => WorkoutSession.fromMap(doc.data())).toList()
        );
      } catch (e) {
        print('⚠️ Index error for today workouts, using fallback: $e');
        // Fallback: get without ordering and sort manually
        final snapshot = await _firestore
            .collection('Users')
            .doc(user.uid)
            .collection('Workouts')
            .where('completedAt', isGreaterThanOrEqualTo: startOfDay.millisecondsSinceEpoch)
            .get();

        final sessions = snapshot.docs
            .map((doc) => WorkoutSession.fromMap(doc.data()))
            .toList();

        sessions.sort((a, b) => b.completedAt.compareTo(a.completedAt));
        currentWorkoutSessions.assignAll(sessions);
      }

      _calculateTodayTotals();
    } catch (e) {
      print('❌ Error loading workouts: $e');
    } finally {
      isLoading(false);
    }
  }

  // Add this method to load latest workouts
  Future<void> loadLatestWorkouts() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      // First try with the compound query
      try {
        final snapshot = await _firestore
            .collection('Users')
            .doc(user.uid)
            .collection('Workouts')
            .where('isCompleted', isEqualTo: true)
            .orderBy('completedAt', descending: true)
            .limit(5)
            .get();

        latestCompletedWorkouts.assignAll(
            snapshot.docs.map((doc) => WorkoutSession.fromMap(doc.data())).toList()
        );
      } catch (e) {
        print('⚠️ Index error for latest workouts, using fallback: $e');

        // Fallback: get all completed workouts and sort manually
        final snapshot = await _firestore
            .collection('Users')
            .doc(user.uid)
            .collection('Workouts')
            .where('isCompleted', isEqualTo: true)
            .get();

        // Sort manually in memory and take latest 5
        final sessions = snapshot.docs
            .map((doc) => WorkoutSession.fromMap(doc.data()))
            .toList();

        sessions.sort((a, b) => b.completedAt.compareTo(a.completedAt));
        latestCompletedWorkouts.assignAll(sessions.take(5).toList());
      }

      print('✅ Loaded ${latestCompletedWorkouts.length} latest workouts');
    } catch (e) {
      print('❌ Error loading latest workouts: $e');

      // Final fallback: get all workouts and filter completed
      try {
        final snapshot = await _firestore
            .collection('Users')
            .doc(user.uid)
            .collection('Workouts')
            .get();

        final sessions = snapshot.docs
            .map((doc) => WorkoutSession.fromMap(doc.data()))
            .where((session) => session.isCompleted)
            .toList();

        sessions.sort((a, b) => b.completedAt.compareTo(a.completedAt));
        latestCompletedWorkouts.assignAll(sessions.take(5).toList());

        print('✅ Loaded ${latestCompletedWorkouts.length} latest workouts (final fallback)');
      } catch (e2) {
        print('❌ Error in final fallback: $e2');
      }
    }
  }

  void _calculateTodayTotals() {
    final completedSessions = currentWorkoutSessions.where((session) => session.isCompleted).toList();

    todayCaloriesBurned.value = completedSessions.fold(0, (sum, session) => sum + session.caloriesBurned);
    todayWorkoutTime.value = completedSessions.fold(0, (sum, session) => sum + session.duration);

    print('🔥 Today totals: ${todayCaloriesBurned.value} calories, ${todayWorkoutTime.value} minutes');
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

      // Create completed session
      final completedSession = session.copyWith(
        isCompleted: true,
        completedAt: DateTime.now(),
      );

      // Update local state
      final index = currentWorkoutSessions.indexWhere((s) => s.id == session.id);
      if (index != -1) {
        currentWorkoutSessions[index] = completedSession;
      }

      // Save to Firestore
      await _firestore
          .collection('Users')
          .doc(user.uid)
          .collection('Workouts')
          .doc(session.id)
          .set(completedSession.toMap());

      // Update health data calories
      _updateHealthDataCalories(completedSession.caloriesBurned);

      // Reload data
      _calculateTodayTotals();
      loadLatestWorkouts(); // Reload latest workouts

      print('✅ Workout completed: ${session.exerciseName} - ${session.caloriesBurned} calories');
      print('🔥 Total calories today: ${todayCaloriesBurned.value}');

    } catch (e) {
      print('❌ Error completing workout: $e');
    }
  }

  void _updateHealthDataCalories(int caloriesBurned) {
    try {
      final healthController = Get.find<HealthDataController>();

      // Parse current calories safely
      String currentCaloriesText = healthController.healthData.value.calories ?? '0 kCal';
      int currentCalories = int.tryParse(currentCaloriesText.split(' ')[0]) ?? 0;
      currentCalories += caloriesBurned;

      int calorieTarget = healthController.healthData.value.calorieTarget ?? 2400;
      int caloriesLeftValue = calorieTarget - currentCalories;
      if (caloriesLeftValue < 0) caloriesLeftValue = 0;

      double newProgress = (currentCalories / calorieTarget) * 100;

      // Update health data
      healthController.healthData.update((val) {
        val?.calories = "${currentCalories} kCal";
        val?.caloriesLeft = "${caloriesLeftValue}kCal\nleft";
        val?.progressValue = newProgress;
      });

      // Update progress notifier
      healthController.progressNotifier.value = newProgress;

      // Save the data
      healthController.saveHealthData();

      print('📊 Health data updated: $currentCalories calories, $newProgress% progress');

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

  // Get latest completed workouts for display
  List<WorkoutSession> getLatestCompletedWorkouts() {
    return latestCompletedWorkouts.take(3).toList(); // Show only last 3
  }
}