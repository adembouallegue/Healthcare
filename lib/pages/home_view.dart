import 'package:dotted_dashed_line/dotted_dashed_line.dart';
import 'package:healthcare/pages/caloriecalculator.dart';
import 'package:healthcare/common_widget/round_button.dart';
import 'package:healthcare/common_widget/workout_row.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:simple_animation_progress_bar/simple_animation_progress_bar.dart';
import 'package:simple_circular_progress_bar/simple_circular_progress_bar.dart';
import 'package:healthcare/common/colo_extension.dart';
import 'activity_tracker_view.dart';
import 'finished_workout_view.dart';
import 'notification_view.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';

// Import workout files
import 'exercise_library.dart';
import 'workout_controller.dart';
import 'workout_timer_screen.dart';

class HealthData {
  String waterIntake;
  String sleep;
  String calories;
  String caloriesLeft;
  List<WaterUpdate> waterUpdates;
  double progressValue;
  double waterProgressValue;
  int calorieTarget;
  double waterTarget;

  // New BMI fields
  double height; // in cm
  double weight; // in kg
  double bmi;
  String bmiCategory;

  HealthData({
    required this.waterIntake,
    required this.sleep,
    required this.calories,
    required this.caloriesLeft,
    required this.waterUpdates,
    required this.progressValue,
    required this.waterProgressValue,
    required this.calorieTarget,
    required this.waterTarget,

    // New BMI fields with defaults
    this.height = 170.0, // default height
    this.weight = 70.0,  // default weight
    this.bmi = 0.0,
    this.bmiCategory = 'Normal',
  });

  // Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'waterIntake': waterIntake,
      'sleep': sleep,
      'calories': calories,
      'caloriesLeft': caloriesLeft,
      'waterUpdates': waterUpdates.map((update) => update.toMap()).toList(),
      'progressValue': progressValue,
      'waterProgressValue': waterProgressValue,
      'calorieTarget': calorieTarget,
      'waterTarget': waterTarget,

      // New BMI fields
      'height': height,
      'weight': weight,
      'bmi': bmi,
      'bmiCategory': bmiCategory,
      'lastUpdated': FieldValue.serverTimestamp(),
    };
  }

  // Create from Firestore data
  factory HealthData.fromMap(Map<String, dynamic> data) {
    List<WaterUpdate> waterUpdates = [];
    if (data['waterUpdates'] != null) {
      waterUpdates = (data['waterUpdates'] as List)
          .map((item) => WaterUpdate.fromMap(Map<String, String>.from(item)))
          .toList();
    } else {
      // Initialize with default water updates if none exist
      waterUpdates = [
        WaterUpdate(title: "● 6am - 8am", subtitle: "0ml"),
        WaterUpdate(title: "● 9am - 11am", subtitle: "0ml"),
        WaterUpdate(title: "● 11am - 2pm", subtitle: "0ml"),
        WaterUpdate(title: "● 2pm - 4pm", subtitle: "0ml"),
        WaterUpdate(title: "● 4pm - now", subtitle: "0ml"),
      ];
    }

    int calorieTarget = data['calorieTarget'] ?? 2400;
    int currentCalories = int.tryParse((data['calories'] ?? '0 kCal').split(' ')[0]) ?? 0;
    int caloriesLeftValue = calorieTarget - currentCalories;
    if (caloriesLeftValue < 0) caloriesLeftValue = 0;

    double waterTarget = (data['waterTarget'] ?? 4.0).toDouble();

    // Calculate BMI from height and weight
    double height = (data['height'] ?? 170.0).toDouble();
    double weight = (data['weight'] ?? 70.0).toDouble();
    double bmi = _calculateBMI(height, weight);
    String bmiCategory = _getBMICategory(bmi);

    return HealthData(
      waterIntake: data['waterIntake'] ?? '0.0 Liters',
      sleep: data['sleep'] ?? '8h 20m',
      calories: data['calories'] ?? '0 kCal',
      caloriesLeft: data['caloriesLeft'] ?? '${caloriesLeftValue}kCal\nleft',
      waterUpdates: waterUpdates,
      progressValue: (data['progressValue'] ?? 0.0).toDouble(),
      waterProgressValue: (data['waterProgressValue'] ?? 0.0).toDouble(),
      calorieTarget: calorieTarget,
      waterTarget: waterTarget,

      // New BMI fields
      height: height,
      weight: weight,
      bmi: bmi,
      bmiCategory: bmiCategory,
    );
  }

  // Calculate BMI: weight (kg) / (height (m) * height (m))
  static double _calculateBMI(double height, double weight) {
    if (height <= 0) return 0.0;
    double heightInMeters = height / 100; // convert cm to meters
    return double.parse((weight / (heightInMeters * heightInMeters)).toStringAsFixed(1));
  }

  // Get BMI category
  static String _getBMICategory(double bmi) {
    if (bmi < 18.5) return 'Underweight';
    if (bmi < 25) return 'Normal';
    if (bmi < 30) return 'Overweight';
    return 'Obese';
  }
}

class WaterUpdate {
  final String title;
  String subtitle;

  WaterUpdate({
    required this.title,
    required this.subtitle,
  });

  // Convert to Map
  Map<String, String> toMap() {
    return {
      'title': title,
      'subtitle': subtitle,
    };
  }

  // Create from Map
  factory WaterUpdate.fromMap(Map<String, String> data) {
    return WaterUpdate(
      title: data['title'] ?? '',
      subtitle: data['subtitle'] ?? '0ml',
    );
  }
}

class HealthDataController extends GetxController {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  var healthData = HealthData(
    waterIntake: "0.0 Liters",
    sleep: "8h 20m",
    calories: "0 kCal",
    caloriesLeft: "2400kCal\nleft",
    progressValue: 0.0,
    waterProgressValue: 0.0,
    waterUpdates: [],
    calorieTarget: 2400,
    waterTarget: 4.0,
    height: 170.0,
    weight: 70.0,
    bmi: 0.0,
    bmiCategory: "Normal",
  ).obs;

  var isLoading = true.obs;
  var lastResetDate = DateTime.now().obs;

  // Progress notifiers for circular progress bars
  ValueNotifier<double> progressNotifier = ValueNotifier(0.0);
  ValueNotifier<double> waterProgressNotifier = ValueNotifier(0.0);

  @override
  void onInit() {
    super.onInit();
    loadHealthData();
    _checkAndResetDailyData();
  }

  // Check if we need to reset data for new day
  void _checkAndResetDailyData() {
    final now = DateTime.now();
    final lastReset = lastResetDate.value;

    // Check if it's a new day (different day, month, or year)
    if (now.day != lastReset.day ||
        now.month != lastReset.month ||
        now.year != lastReset.year) {
      _resetDailyData();
    }
  }

  // Reset daily data to zero
  Future<void> _resetDailyData() async {
    print('🔄 Resetting daily data for new day');

    // Create fresh health data with zeros
    final newHealthData = HealthData(
      waterIntake: "0.0 Liters",
      sleep: healthData.value.sleep, // Keep sleep data
      calories: "0 kCal",
      caloriesLeft: "${healthData.value.calorieTarget}kCal\nleft",
      waterUpdates: [
        WaterUpdate(title: "● 6am - 8am", subtitle: "0ml"),
        WaterUpdate(title: "● 9am - 11am", subtitle: "0ml"),
        WaterUpdate(title: "● 11am - 2pm", subtitle: "0ml"),
        WaterUpdate(title: "● 2pm - 4pm", subtitle: "0ml"),
        WaterUpdate(title: "● 4pm - now", subtitle: "0ml"),
      ],
      progressValue: 0.0,
      waterProgressValue: 0.0,
      calorieTarget: healthData.value.calorieTarget, // Keep targets
      waterTarget: healthData.value.waterTarget, // Keep targets
      height: healthData.value.height, // Keep height/weight
      weight: healthData.value.weight,
      bmi: healthData.value.bmi,
      bmiCategory: healthData.value.bmiCategory,
    );

    // Update reactive values
    healthData.value = newHealthData;
    progressNotifier.value = 0.0;
    waterProgressNotifier.value = 0.0;
    lastResetDate.value = DateTime.now();

    // Save to Firestore
    await _saveHealthData();

    print('✅ Daily data reset complete');
  }

  // Modified loadHealthData to check for daily reset
  Future<void> loadHealthData() async {
    try {
      isLoading(true);
      final user = _auth.currentUser;
      if (user == null) return;

      final doc = await _firestore
          .collection('Users')
          .doc(user.uid)
          .collection('HealthData')
          .doc('daily')
          .get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;

        // Check last updated timestamp
        final lastUpdated = data['lastUpdated'] as Timestamp?;
        if (lastUpdated != null) {
          final lastUpdateDate = lastUpdated.toDate();
          final now = DateTime.now();

          // Check if data is from previous day
          if (lastUpdateDate.day != now.day ||
              lastUpdateDate.month != now.month ||
              lastUpdateDate.year != now.year) {
            // Data is from previous day, reset it
            print('📅 Data is from previous day, resetting...');
            await _resetDailyData();
          } else {
            // Data is from today, load normally
            healthData.value = HealthData.fromMap(data);
            progressNotifier.value = healthData.value.progressValue;
            waterProgressNotifier.value = healthData.value.waterProgressValue;

            // Update last reset date
            lastResetDate.value = lastUpdateDate;
            print('✅ Health data loaded from Firestore');
          }
        } else {
          // No timestamp, initialize fresh data
          await _initializeHealthData();
        }
      } else {
        // No document exists, initialize
        await _initializeHealthData();
      }
    } catch (e) {
      print('❌ Error loading health data: $e');
      await _initializeHealthData();
    } finally {
      isLoading(false);
    }
  }

  // Modified _initializeHealthData to include timestamp
  Future<void> _initializeHealthData() async {
    final user = _auth.currentUser;
    if (user == null) return;

    healthData.value.waterUpdates = [
      WaterUpdate(title: "● 6am - 8am", subtitle: "0ml"),
      WaterUpdate(title: "● 9am - 11am", subtitle: "0ml"),
      WaterUpdate(title: "● 11am - 2pm", subtitle: "0ml"),
      WaterUpdate(title: "● 2pm - 4pm", subtitle: "0ml"),
      WaterUpdate(title: "● 4pm - now", subtitle: "0ml"),
    ];

    healthData.value.calorieTarget = 2400;
    healthData.value.caloriesLeft = "2400kCal\nleft";
    healthData.value.waterTarget = 4.0;

    // Calculate initial BMI
    healthData.value.bmi = HealthData._calculateBMI(healthData.value.height, healthData.value.weight);
    healthData.value.bmiCategory = HealthData._getBMICategory(healthData.value.bmi);

    progressNotifier.value = 0.0;
    waterProgressNotifier.value = 0.0;
    lastResetDate.value = DateTime.now();

    await _saveHealthData();
    print('✅ Health data initialized in Firestore');
  }

  // Modified _saveHealthData to always include current timestamp
  Future<void> _saveHealthData() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // Ensure we have the latest timestamp
      final dataToSave = healthData.value.toMap();
      dataToSave['lastUpdated'] = FieldValue.serverTimestamp();

      await _firestore
          .collection('Users')
          .doc(user.uid)
          .collection('HealthData')
          .doc('daily')
          .set(dataToSave, SetOptions(merge: true));

      print('💾 Health data saved to Firestore');
    } catch (e) {
      print('❌ Error saving health data: $e');
    }
  }

  // Add periodic check in the HomeView
  void checkForDailyReset() {
    _checkAndResetDailyData();
  }

  // Add calories and save
  void addCalories() {
    // Create a new instance to trigger reactivity
    final newHealthData = HealthData(
      waterIntake: healthData.value.waterIntake,
      sleep: healthData.value.sleep,
      calories: healthData.value.calories,
      caloriesLeft: healthData.value.caloriesLeft,
      waterUpdates: List.from(healthData.value.waterUpdates),
      progressValue: healthData.value.progressValue,
      waterProgressValue: healthData.value.waterProgressValue,
      calorieTarget: healthData.value.calorieTarget,
      waterTarget: healthData.value.waterTarget,
      height: healthData.value.height,
      weight: healthData.value.weight,
      bmi: healthData.value.bmi,
      bmiCategory: healthData.value.bmiCategory,
    );

    int currentCalories = int.parse(newHealthData.calories.split(' ')[0]);
    currentCalories += 50;

    int caloriesLeftValue = newHealthData.calorieTarget - currentCalories;
    if (caloriesLeftValue < 0) {
      caloriesLeftValue = 0;
    }

    newHealthData.calories = "${currentCalories} kCal";
    newHealthData.caloriesLeft = "${caloriesLeftValue}kCal\nleft";

    double newProgress = newHealthData.calorieTarget > 0 ? (currentCalories / newHealthData.calorieTarget) * 100 : 0;
    newHealthData.progressValue = newProgress;

    // Update the reactive value
    healthData.value = newHealthData;
    progressNotifier.value = newProgress;

    _saveHealthData();
  }

  // Add water and save
  void addWater() {
    // Create a new instance to trigger reactivity
    final newHealthData = HealthData(
      waterIntake: healthData.value.waterIntake,
      sleep: healthData.value.sleep,
      calories: healthData.value.calories,
      caloriesLeft: healthData.value.caloriesLeft,
      waterUpdates: List.from(healthData.value.waterUpdates),
      progressValue: healthData.value.progressValue,
      waterProgressValue: healthData.value.waterProgressValue,
      calorieTarget: healthData.value.calorieTarget,
      waterTarget: healthData.value.waterTarget,
      height: healthData.value.height,
      weight: healthData.value.weight,
      bmi: healthData.value.bmi,
      bmiCategory: healthData.value.bmiCategory,
    );

    double currentWater = double.parse(newHealthData.waterIntake.split(' ')[0]);
    currentWater += 0.2;

    newHealthData.waterIntake = "${currentWater.toStringAsFixed(1)} Liters";

    // Use user's water target instead of fixed 4.0
    double newWaterProgress = (currentWater / newHealthData.waterTarget) * 100;
    if (newWaterProgress > 100) newWaterProgress = 100;

    newHealthData.waterProgressValue = newWaterProgress;

    if (newHealthData.waterUpdates.isNotEmpty) {
      WaterUpdate lastUpdate = newHealthData.waterUpdates.last;
      int currentML = int.parse(lastUpdate.subtitle.split('ml')[0]);
      currentML += 200;
      lastUpdate.subtitle = "${currentML}ml";
    }

    // Update the reactive value
    healthData.value = newHealthData;
    waterProgressNotifier.value = newWaterProgress;

    _saveHealthData();
  }

  // Update calorie target
  void updateCalorieTarget(int newTarget) {
    final newHealthData = HealthData(
      waterIntake: healthData.value.waterIntake,
      sleep: healthData.value.sleep,
      calories: healthData.value.calories,
      caloriesLeft: healthData.value.caloriesLeft,
      waterUpdates: List.from(healthData.value.waterUpdates),
      progressValue: healthData.value.progressValue,
      waterProgressValue: healthData.value.waterProgressValue,
      calorieTarget: newTarget,
      waterTarget: healthData.value.waterTarget,
      height: healthData.value.height,
      weight: healthData.value.weight,
      bmi: healthData.value.bmi,
      bmiCategory: healthData.value.bmiCategory,
    );

    // Recalculate calories left based on new target
    int currentCalories = int.parse(newHealthData.calories.split(' ')[0]);
    int caloriesLeftValue = newTarget - currentCalories;

    if (caloriesLeftValue < 0) {
      caloriesLeftValue = 0;
    }

    newHealthData.caloriesLeft = "${caloriesLeftValue}kCal\nleft";

    // Recalculate progress
    double newProgress = newTarget > 0 ? (currentCalories / newTarget) * 100 : 0;
    newHealthData.progressValue = newProgress;

    healthData.value = newHealthData;
    progressNotifier.value = newProgress;

    _saveHealthData();
  }

  // Update water target
  void updateWaterTarget(double newTarget) {
    final newHealthData = HealthData(
      waterIntake: healthData.value.waterIntake,
      sleep: healthData.value.sleep,
      calories: healthData.value.calories,
      caloriesLeft: healthData.value.caloriesLeft,
      waterUpdates: List.from(healthData.value.waterUpdates),
      progressValue: healthData.value.progressValue,
      waterProgressValue: healthData.value.waterProgressValue,
      calorieTarget: healthData.value.calorieTarget,
      waterTarget: newTarget,
      height: healthData.value.height,
      weight: healthData.value.weight,
      bmi: healthData.value.bmi,
      bmiCategory: healthData.value.bmiCategory,
    );

    // Recalculate water progress based on new target
    double currentWater = double.parse(newHealthData.waterIntake.split(' ')[0]);
    double newWaterProgress = (currentWater / newTarget) * 100;
    if (newWaterProgress > 100) newWaterProgress = 100;

    newHealthData.waterProgressValue = newWaterProgress;

    healthData.value = newHealthData;
    waterProgressNotifier.value = newWaterProgress;

    _saveHealthData();
  }

  // Update height and weight
  void updateHeightAndWeight(double newHeight, double newWeight) {
    final newHealthData = HealthData(
      waterIntake: healthData.value.waterIntake,
      sleep: healthData.value.sleep,
      calories: healthData.value.calories,
      caloriesLeft: healthData.value.caloriesLeft,
      waterUpdates: List.from(healthData.value.waterUpdates),
      progressValue: healthData.value.progressValue,
      waterProgressValue: healthData.value.waterProgressValue,
      calorieTarget: healthData.value.calorieTarget,
      waterTarget: healthData.value.waterTarget,

      // Update height and weight
      height: newHeight,
      weight: newWeight,
    );

    // Recalculate BMI
    newHealthData.bmi = HealthData._calculateBMI(newHeight, newWeight);
    newHealthData.bmiCategory = HealthData._getBMICategory(newHealthData.bmi);

    healthData.value = newHealthData;
    _saveHealthData();
  }

  // Update only height
  void updateHeight(double newHeight) {
    updateHeightAndWeight(newHeight, healthData.value.weight);
  }

  // Update only weight
  void updateWeight(double newWeight) {
    updateHeightAndWeight(healthData.value.height, newWeight);
  }

  // Get BMI description
  String getBMIDescription() {
    final bmi = healthData.value.bmi;
    final category = healthData.value.bmiCategory;

    switch (category) {
      case 'Underweight':
        return 'You are underweight. Consider consulting a nutritionist.';
      case 'Normal':
        return 'You have a normal weight. Keep up the good work!';
      case 'Overweight':
        return 'You are overweight. Regular exercise can help.';
      case 'Obese':
        return 'You are obese. Consider consulting a healthcare provider.';
      default:
        return 'Maintain a healthy lifestyle.';
    }
  }

  // Reset to default targets
  void resetCalorieTarget() {
    updateCalorieTarget(2400);
  }

  void resetWaterTarget() {
    updateWaterTarget(4.0);
  }

  void resetHeightWeight() {
    updateHeightAndWeight(170.0, 70.0);
  }

  // Manual reset for testing
  Future<void> manualDailyReset() async {
    await _resetDailyData();
  }

  // Public method to save health data
  Future<void> saveHealthData() async {
    await _saveHealthData();
  }
}

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  late SettingsController controller;
  late HealthDataController healthController;
  late WorkoutController workoutController;
  Timer? _dailyCheckTimer;

  List lastWorkoutArr = [
    {
      "name": "Full Body Workout",
      "image": "assets/img/Workout1.png",
      "kcal": "180",
      "time": "20",
      "progress": 0.3
    },
    {
      "name": "Lower Body Workout",
      "image": "assets/img/Workout2.png",
      "kcal": "200",
      "time": "30",
      "progress": 0.4
    },
    {
      "name": "Ab Workout",
      "image": "assets/img/Workout3.png",
      "kcal": "300",
      "time": "40",
      "progress": 0.7
    },
  ];
  List<int> showingTooltipOnSpots = [21];

  List<FlSpot> get allSpots => const [
    FlSpot(0, 20),
    FlSpot(1, 25),
    FlSpot(2, 40),
    FlSpot(3, 50),
    FlSpot(4, 35),
    FlSpot(5, 40),
    FlSpot(6, 30),
    FlSpot(7, 20),
    FlSpot(8, 25),
    FlSpot(9, 40),
    FlSpot(10, 50),
    FlSpot(11, 35),
    FlSpot(12, 50),
    FlSpot(13, 60),
    FlSpot(14, 40),
    FlSpot(15, 50),
    FlSpot(16, 20),
    FlSpot(17, 25),
    FlSpot(18, 40),
    FlSpot(19, 50),
    FlSpot(20, 35),
    FlSpot(21, 80),
    FlSpot(22, 30),
    FlSpot(23, 20),
    FlSpot(24, 25),
    FlSpot(25, 40),
    FlSpot(26, 50),
    FlSpot(27, 35),
    FlSpot(28, 50),
    FlSpot(29, 60),
    FlSpot(30, 40)
  ];

  @override
  void initState() {
    super.initState();
    controller = Get.put(SettingsController());
    healthController = Get.put(HealthDataController());
    workoutController = Get.put(WorkoutController());

    // Check for daily reset every minute
    _dailyCheckTimer = Timer.periodic(Duration(minutes: 1), (timer) {
      healthController.checkForDailyReset();
    });
  }

  @override
  void dispose() {
    _dailyCheckTimer?.cancel();
    super.dispose();
  }

  String _getTimeTo10PM() {
    DateTime now = DateTime.now();
    DateTime tenPM = DateTime(now.year, now.month, now.day, 22, 0);

    if (now.isAfter(tenPM)) {
      tenPM = tenPM.add(Duration(days: 1));
    }

    Duration difference = tenPM.difference(now);
    int hours = difference.inHours;
    int minutes = difference.inMinutes.remainder(60);

    return '${hours}h ${minutes}m';
  }

  void _showCalorieTargetDialog(BuildContext context) {
    TextEditingController targetController = TextEditingController(
      text: healthController.healthData.value.calorieTarget.toString(),
    );

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            "Set Daily Calorie Target",
            style: TextStyle(
              color: TColor.black,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Enter your daily calorie target:",
                style: TextStyle(
                  color: TColor.gray,
                ),
              ),
              SizedBox(height: 16),
              TextField(
                controller: targetController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  labelText: 'Calories',
                  suffixText: 'kCal',
                  labelStyle: TextStyle(color: TColor.gray),
                ),
              ),
              SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: Text(
                      'Cancel',
                      style: TextStyle(color: TColor.gray),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      int? newTarget = int.tryParse(targetController.text);
                      if (newTarget != null && newTarget > 0) {
                        healthController.updateCalorieTarget(newTarget);
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Calorie target updated to $newTarget kCal'),
                            backgroundColor: TColor.primaryColor1,
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Please enter a valid number greater than 0'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
                    child: Text('Save'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: TColor.primaryColor1,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _showWaterTargetDialog(BuildContext context) {
    TextEditingController targetController = TextEditingController(
      text: healthController.healthData.value.waterTarget.toStringAsFixed(1),
    );

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            "Set Daily Water Target",
            style: TextStyle(
              color: TColor.black,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Enter your daily water target:",
                style: TextStyle(
                  color: TColor.gray,
                ),
              ),
              SizedBox(height: 16),
              TextField(
                controller: targetController,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  labelText: 'Water',
                  suffixText: 'Liters',
                  labelStyle: TextStyle(color: TColor.gray),
                ),
              ),
              SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: Text(
                      'Cancel',
                      style: TextStyle(color: TColor.gray),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      double? newTarget = double.tryParse(targetController.text);
                      if (newTarget != null && newTarget > 0) {
                        healthController.updateWaterTarget(newTarget);
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Water target updated to ${newTarget.toStringAsFixed(1)}L'),
                            backgroundColor: TColor.secondaryColor1,
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Please enter a valid number greater than 0'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
                    child: Text('Save'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: TColor.secondaryColor1,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _showBMIDialog(BuildContext context) {
    TextEditingController heightController = TextEditingController(
      text: healthController.healthData.value.height.toStringAsFixed(0),
    );
    TextEditingController weightController = TextEditingController(
      text: healthController.healthData.value.weight.toStringAsFixed(1),
    );

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            "Update BMI",
            style: TextStyle(
              color: TColor.black,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Enter your height and weight to calculate your BMI:",
                  style: TextStyle(
                    color: TColor.gray,
                  ),
                ),
                SizedBox(height: 16),
                TextField(
                  controller: heightController,
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    labelText: 'Height',
                    suffixText: 'cm',
                    labelStyle: TextStyle(color: TColor.gray),
                  ),
                ),
                SizedBox(height: 12),
                TextField(
                  controller: weightController,
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    labelText: 'Weight',
                    suffixText: 'kg',
                    labelStyle: TextStyle(color: TColor.gray),
                  ),
                ),
                SizedBox(height: 16),
                Obx(() {
                  final healthData = healthController.healthData.value;
                  return Column(
                    children: [
                      Text(
                        "Current BMI: ${healthData.bmi}",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: TColor.primaryColor1,
                        ),
                      ),
                      Text(
                        "Category: ${healthData.bmiCategory}",
                        style: TextStyle(
                          fontSize: 14,
                          color: TColor.gray,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        healthController.getBMIDescription(),
                        style: TextStyle(
                          fontSize: 12,
                          color: TColor.gray,
                          fontStyle: FontStyle.italic,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  );
                }),
                SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: Text(
                        'Cancel',
                        style: TextStyle(color: TColor.gray),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        double? newHeight = double.tryParse(heightController.text);
                        double? newWeight = double.tryParse(weightController.text);

                        if (newHeight != null && newWeight != null &&
                            newHeight > 0 && newWeight > 0) {
                          healthController.updateHeightAndWeight(newHeight, newWeight);
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('BMI updated successfully!'),
                              backgroundColor: TColor.primaryColor1,
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Please enter valid height and weight values'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      },
                      child: Text('Calculate & Save'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: TColor.primaryColor1,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ========== WORKOUT SECTION WIDGETS ==========

  // Workout Section Widget
  Widget _buildWorkoutSection(Size media) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Today's Workout",
              style: TextStyle(
                color: TColor.black,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            Obx(() {
              return Text(
                "${workoutController.todayCaloriesBurned.value} cal burned",
                style: TextStyle(
                  color: TColor.primaryColor1,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              );
            }),
          ],
        ),
        SizedBox(height: media.width * 0.03),
        _buildWorkoutCategorySelector(),
        SizedBox(height: media.width * 0.03),
        _buildExerciseList(media),
      ],
    );
  }

  // Workout Category Selector
  Widget _buildWorkoutCategorySelector() {
    return Container(
      height: 50,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: ExerciseLibrary.getCategories().map((category) {
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Obx(() => ChoiceChip(
              label: Text(
                ExerciseLibrary.getCategoryDisplayName(category),
                style: TextStyle(
                  color: workoutController.selectedCategory.value == category
                      ? Colors.white
                      : TColor.black,
                ),
              ),
              selected: workoutController.selectedCategory.value == category,
              onSelected: (selected) {
                workoutController.selectedCategory.value = category;
              },
              selectedColor: TColor.primaryColor1,
              backgroundColor: Colors.grey[200],
            )),
          );
        }).toList(),
      ),
    );
  }

  // Exercise List
  Widget _buildExerciseList(Size media) {
    return Obx(() {
      final exercises = workoutController.getExercisesBySelectedCategory();

      return Column(
        children: exercises.map((exercise) => _buildExerciseCard(exercise, media)).toList(),
      );
    });
  }

  // Individual Exercise Card
// Individual Exercise Card with better image handling
  Widget _buildExerciseCard(Exercise exercise, Size media) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Exercise Image with fallback
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: _getCategoryColor(exercise.category).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: _buildExerciseImage(exercise),
            ),
          ),
          SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        exercise.name,
                        style: TextStyle(
                          color: TColor.black,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    _buildDifficultyBadge(exercise.difficulty),
                  ],
                ),
                SizedBox(height: 4),
                Text(
                  exercise.description,
                  style: TextStyle(
                    color: TColor.gray,
                    fontSize: 12,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    _buildExerciseTag(
                      '${exercise.caloriesPerMinute} cal/min',
                      TColor.primaryColor1,
                    ),
                    _buildExerciseTag(
                      '${exercise.defaultDuration} min',
                      TColor.secondaryColor1,
                    ),
                    ...exercise.muscles.take(2).map((muscle) =>
                        _buildExerciseTag(
                          muscle,
                          _getMuscleColor(muscle),
                        )
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Start Button
          IconButton(
            onPressed: () {
              _startExerciseWorkout(exercise);
            },
            icon: Icon(
              Icons.play_arrow_rounded,
              color: TColor.primaryColor1,
              size: 30,
            ),
            style: IconButton.styleFrom(
              backgroundColor: TColor.primaryColor1.withOpacity(0.1),
              padding: EdgeInsets.all(12),
            ),
          ),
        ],
      ),
    );
  }

// Build exercise image with fallback
  Widget _buildExerciseImage(Exercise exercise) {
    // Try to load the image, if it fails show an icon
    try {
      return Image.asset(
        exercise.image,
        width: 70,
        height: 70,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _buildExerciseIcon(exercise.category);
        },
      );
    } catch (e) {
      return _buildExerciseIcon(exercise.category);
    }
  }

// Fallback exercise icon based on category
  Widget _buildExerciseIcon(String category) {
    IconData icon;
    Color color;

    switch (category) {
      case 'push':
        icon = Icons.fitness_center;
        color = TColor.primaryColor1;
        break;
      case 'pull':
        icon = Icons.arrow_upward;
        color = Colors.blue;
        break;
      case 'legs':
        icon = Icons.directions_run;
        color = Colors.green;
        break;
      default:
        icon = Icons.fitness_center;
        color = TColor.primaryColor1;
    }

    return Container(
      color: color.withOpacity(0.1),
      child: Center(
        child: Icon(
          icon,
          color: color,
          size: 30,
        ),
      ),
    );
  }

// Difficulty badge with colors and icons
  Widget _buildDifficultyBadge(String difficulty) {
    Color color;
    String text;
    IconData icon;

    switch (difficulty) {
      case 'beginner':
        color = Colors.green;
        text = 'Beginner';
        icon = Icons.trending_flat;
        break;
      case 'intermediate':
        color = Colors.orange;
        text = 'Intermediate';
        icon = Icons.trending_up;
        break;
      case 'advanced':
        color = Colors.red;
        text = 'Advanced';
        icon = Icons.trending_up;
        break;
      default:
        color = Colors.grey;
        text = difficulty;
        icon = Icons.fitness_center;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: color,
            size: 12,
          ),
          SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

// Get category color
  Color _getCategoryColor(String category) {
    switch (category) {
      case 'push':
        return TColor.primaryColor1;
      case 'pull':
        return Colors.blue;
      case 'legs':
        return Colors.green;
      default:
        return TColor.primaryColor1;
    }
  }

// Get muscle color
  Color _getMuscleColor(String muscle) {
    switch (muscle.toLowerCase()) {
      case 'chest':
        return Colors.red;
      case 'shoulders':
        return Colors.orange;
      case 'triceps':
        return Colors.purple;
      case 'back':
        return Colors.blue;
      case 'biceps':
        return Colors.green;
      case 'quads':
        return Colors.deepOrange;
      case 'glutes':
        return Colors.pink;
      case 'hamstrings':
        return Colors.brown;
      case 'calves':
        return Colors.cyan;
      case 'core':
        return Colors.teal;
      default:
        return TColor.gray;
    }
  }
  Widget _buildExerciseTag(String text, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Color _getDifficultyColor(String difficulty) {
    switch (difficulty) {
      case 'beginner':
        return Colors.green;
      case 'intermediate':
        return Colors.orange;
      case 'advanced':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  // Start Exercise Workout
  void _startExerciseWorkout(Exercise exercise) {
    int selectedDuration = exercise.defaultDuration;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text("Start ${exercise.name}"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text("Select workout duration:"),
                  SizedBox(height: 16),
                  DropdownButton<int>(
                    value: selectedDuration,
                    items: [5, 10, 15, 20, 25, 30].map((duration) {
                      return DropdownMenuItem<int>(
                        value: duration,
                        child: Text("$duration minutes - ${exercise.calculateCalories(duration)} calories"),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedDuration = value!;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text("Cancel"),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _showWorkoutTimer(exercise, selectedDuration);
                  },
                  child: Text("Start Workout"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: TColor.primaryColor1,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Workout Timer Screen
  void _showWorkoutTimer(Exercise exercise, int duration) {
    final session = workoutController.startWorkout(exercise, duration);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return WorkoutTimerScreen(
          exercise: exercise,
          duration: duration,
          session: session,
          onComplete: () {
            workoutController.completeWorkout(session);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Great! ${exercise.calculateCalories(duration)} calories added to your progress!'),
                backgroundColor: TColor.primaryColor1,
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    var media = MediaQuery.of(context).size;

    final lineBarsData = [
      LineChartBarData(
        showingIndicators: showingTooltipOnSpots,
        spots: allSpots,
        isCurved: false,
        barWidth: 3,
        belowBarData: BarAreaData(
          show: true,
          gradient: LinearGradient(colors: [
            TColor.primaryColor2.withOpacity(0.4),
            TColor.primaryColor1.withOpacity(0.1),
          ], begin: Alignment.topCenter, end: Alignment.bottomCenter),
        ),
        dotData: FlDotData(show: false),
        gradient: LinearGradient(
          colors: TColor.primaryG,
        ),
      ),
    ];

    final tooltipsOnBar = lineBarsData[0];

    return Scaffold(
      backgroundColor: TColor.white,
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          healthController.manualDailyReset();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Daily data reset!'),
              backgroundColor: TColor.primaryColor1,
            ),
          );
        },
        child: Icon(Icons.refresh),
        backgroundColor: TColor.primaryColor1,
        mini: true,
      ),
      body: Obx(() {
        if (healthController.isLoading.value) {
          return Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(TColor.primaryColor1),
            ),
          );
        }

        return SingleChildScrollView(
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FutureBuilder(
                            future: controller.getData,
                            builder: (BuildContext context, AsyncSnapshot snapshot) {
                              if (snapshot.connectionState == ConnectionState.waiting) {
                                return Text(
                                  'Loading...',
                                  style: TextStyle(
                                      color: TColor.black,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700
                                  ),
                                );
                              }

                              if (snapshot.hasError) {
                                return Text(
                                  'Error Loading',
                                  style: TextStyle(
                                      color: TColor.black,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700
                                  ),
                                );
                              }

                              return Obx(() => Text(
                                'Hello, ${controller.username.value}!',
                                style: TextStyle(
                                    color: TColor.black,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700
                                ),
                              ));
                            },
                          ),
                          SizedBox(height: 4),
                          Text(
                            "Ready to workout?",
                            style: TextStyle(
                              color: TColor.gray,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const NotificationView(),
                              ),
                            );
                          },
                          icon: Image.asset(
                            "assets/img/notification_active.png",
                            width: 25,
                            height: 25,
                            fit: BoxFit.fitHeight,
                          ))
                    ],
                  ),
                  SizedBox(
                    height: media.width * 0.05,
                  ),

                  // BMI SECTION
                  Container(
                    height: media.width * 0.35,
                    decoration: BoxDecoration(
                        gradient: LinearGradient(colors: TColor.primaryG),
                        borderRadius: BorderRadius.circular(media.width * 0.075)),
                    child: Stack(alignment: Alignment.center, children: [
                      Image.asset(
                        "assets/img/bg_dots.png",
                        height: media.width * 0.35,
                        width: double.maxFinite,
                        fit: BoxFit.fitHeight,
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: 15, horizontal: 20),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              flex: 3,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "BMI (Body Mass Index)",
                                    style: TextStyle(
                                        color: TColor.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700),
                                  ),
                                  SizedBox(height: 4),
                                  Obx(() => Text(
                                    "Your BMI: ${healthController.healthData.value.bmi}",
                                    style: TextStyle(
                                        color: TColor.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold),
                                  )),
                                  SizedBox(height: 2),
                                  Obx(() => Text(
                                    healthController.healthData.value.bmiCategory,
                                    style: TextStyle(
                                        color: TColor.white.withOpacity(0.7),
                                        fontSize: 10),
                                  )),
                                  SizedBox(height: 4),
                                  Obx(() => Text(
                                    "${healthController.healthData.value.height.toStringAsFixed(0)}cm • ${healthController.healthData.value.weight.toStringAsFixed(1)}kg",
                                    style: TextStyle(
                                        color: TColor.white.withOpacity(0.7),
                                        fontSize: 9),
                                  )),
                                  SizedBox(height: 6),
                                  SizedBox(
                                      width: 100,
                                      height: 25.4,
                                      child: RoundButton(
                                          title: "Update BMI",
                                          type: RoundButtonType.bgSGradient,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w400,
                                          onPressed: () {
                                            _showBMIDialog(context);
                                          }))
                                ],
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: AspectRatio(
                                aspectRatio: 1,
                                child: PieChart(
                                  PieChartData(
                                    pieTouchData: PieTouchData(
                                      touchCallback:
                                          (FlTouchEvent event, pieTouchResponse) {},
                                    ),
                                    startDegreeOffset: 250,
                                    borderData: FlBorderData(
                                      show: false,
                                    ),
                                    sectionsSpace: 1,
                                    centerSpaceRadius: 0,
                                    sections: showingSections(),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    ]),
                  ),

                  SizedBox(
                    height: media.width * 0.05,
                  ),

                  // WORKOUT SECTION
                  // _buildWorkoutSection(media),

                  SizedBox(
                    height: media.width * 0.05,
                  ),

                  // TODAY TARGET SECTION
                  Container(
                    padding:
                    const EdgeInsets.symmetric(vertical: 15, horizontal: 15),
                    decoration: BoxDecoration(
                      color: TColor.primaryColor2.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Today Target",
                          style: TextStyle(
                              color: TColor.black,
                              fontSize: 14,
                              fontWeight: FontWeight.w700),
                        ),
                        SizedBox(
                          width: 70,
                          height: 25,
                          child: RoundButton(
                            title: "Check",
                            type: RoundButtonType.bgGradient,
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                  const ActivityTrackerView(),
                                ),
                              );
                            },
                          ),
                        )
                      ],
                    ),
                  ),
                  SizedBox(
                    height: media.width * 0.05,
                  ),
                  Container(
                    padding:
                    const EdgeInsets.symmetric(vertical: 15, horizontal: 15),
                    decoration: BoxDecoration(
                      color: TColor.primaryColor2.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Calorie calculator",
                          style: TextStyle(
                              color: TColor.black,
                              fontSize: 14,
                              fontWeight: FontWeight.w700),
                        ),
                        SizedBox(
                          width: 70,
                          height: 25,
                          child: RoundButton(
                            title: "calc",
                            type: RoundButtonType.bgGradient,
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                  const CalorieCalculator(),
                                ),
                              );
                            },
                          ),
                        )
                      ],
                    ),
                  ),
                  SizedBox(
                    height: media.width * 0.05,
                  ),
                  Text(
                    "Activity Status",
                    style: TextStyle(
                        color: TColor.black,
                        fontSize: 16,
                        fontWeight: FontWeight.w700),
                  ),
                  SizedBox(
                    height: media.width * 0.02,
                  ),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(25),
                    child: Container(
                      height: media.width * 0.4,
                      width: double.maxFinite,
                      decoration: BoxDecoration(
                        color: TColor.primaryColor2.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: Stack(
                        alignment: Alignment.topLeft,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: 20, horizontal: 20),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Heart Rate",
                                  style: TextStyle(
                                      color: TColor.black,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700),
                                ),
                                ShaderMask(
                                  blendMode: BlendMode.srcIn,
                                  shaderCallback: (bounds) {
                                    return LinearGradient(
                                        colors: TColor.primaryG,
                                        begin: Alignment.centerLeft,
                                        end: Alignment.centerRight)
                                        .createShader(Rect.fromLTRB(
                                        0, 0, bounds.width, bounds.height));
                                  },
                                  child: Text(
                                    "78 BPM",
                                    style: TextStyle(
                                        color: TColor.white.withOpacity(0.7),
                                        fontWeight: FontWeight.w700,
                                        fontSize: 18),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          LineChart(
                            LineChartData(
                              showingTooltipIndicators:
                              showingTooltipOnSpots.map((index) {
                                return ShowingTooltipIndicators([
                                  LineBarSpot(
                                    tooltipsOnBar,
                                    lineBarsData.indexOf(tooltipsOnBar),
                                    tooltipsOnBar.spots[index],
                                  ),
                                ]);
                              }).toList(),
                              lineTouchData: LineTouchData(
                                enabled: true,
                                handleBuiltInTouches: false,
                                touchCallback: (FlTouchEvent event,
                                    LineTouchResponse? response) {
                                  if (response == null ||
                                      response.lineBarSpots == null) {
                                    return;
                                  }
                                  if (event is FlTapUpEvent) {
                                    final spotIndex =
                                        response.lineBarSpots!.first.spotIndex;
                                    showingTooltipOnSpots.clear();
                                    setState(() {
                                      showingTooltipOnSpots.add(spotIndex);
                                    });
                                  }
                                },
                                mouseCursorResolver: (FlTouchEvent event,
                                    LineTouchResponse? response) {
                                  if (response == null ||
                                      response.lineBarSpots == null) {
                                    return SystemMouseCursors.basic;
                                  }
                                  return SystemMouseCursors.click;
                                },
                                getTouchedSpotIndicator:
                                    (LineChartBarData barData,
                                    List<int> spotIndexes) {
                                  return spotIndexes.map((index) {
                                    return TouchedSpotIndicatorData(
                                      FlLine(
                                        color: Colors.red,
                                      ),
                                      FlDotData(
                                        show: true,
                                        getDotPainter:
                                            (spot, percent, barData, index) =>
                                            FlDotCirclePainter(
                                              radius: 3,
                                              color: Colors.white,
                                              strokeWidth: 3,
                                              strokeColor: TColor.secondaryColor1,
                                            ),
                                      ),
                                    );
                                  }).toList();
                                },
                                touchTooltipData: LineTouchTooltipData(
                                  getTooltipColor: (spot) => TColor.secondaryColor1,
                                  tooltipRoundedRadius: 20,
                                  getTooltipItems:
                                      (List<LineBarSpot> lineBarsSpot) {
                                    return lineBarsSpot.map((lineBarSpot) {
                                      return LineTooltipItem(
                                        "${lineBarSpot.x.toInt()} mins ago",
                                        const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      );
                                    }).toList();
                                  },
                                ),
                              ),
                              lineBarsData: lineBarsData,
                              minY: 0,
                              maxY: 130,
                              titlesData: FlTitlesData(
                                show: false,
                              ),
                              gridData: FlGridData(show: false),
                              borderData: FlBorderData(
                                show: true,
                                border: Border.all(
                                  color: Colors.transparent,
                                ),
                              ),
                            ),
                          )
                        ],
                      ),
                    ),
                  ),
                  SizedBox(
                    height: media.width * 0.05,
                  ),

                  // WATER AND CALORIES SECTION
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: media.width * 0.95,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                vertical: 20, horizontal: 15),
                            decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(25),
                                boxShadow: const [
                                  BoxShadow(color: Colors.black12, blurRadius: 2)
                                ]),
                            child: _buildWaterIntakeSection(media),
                          ),
                        ),
                        SizedBox(
                          width: media.width * 0.05,
                        ),
                        Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _buildSleepCard(media),
                                SizedBox(
                                  height: media.width * 0.05,
                                ),
                                _buildCaloriesCard(media),
                              ],
                            ))
                      ],
                    ),
                  ),
                  _buildWorkoutSection(media),

                  SizedBox(
                    height: media.width * 0.05,
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Workout Progress",
                        style: TextStyle(
                            color: TColor.black,
                            fontSize: 16,
                            fontWeight: FontWeight.w700),
                      ),
                      Container(
                          height: 30,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: TColor.primaryG),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton(
                              items: ["Weekly", "Monthly"]
                                  .map((name) => DropdownMenuItem(
                                value: name,
                                child: Text(
                                  name,
                                  style: TextStyle(
                                      color: TColor.gray, fontSize: 14),
                                ),
                              ))
                                  .toList(),
                              onChanged: (value) {},
                              icon: Icon(Icons.expand_more, color: TColor.white),
                              hint: Text(
                                "Weekly",
                                textAlign: TextAlign.center,
                                style:
                                TextStyle(color: TColor.white, fontSize: 12),
                              ),
                            ),
                          )),
                    ],
                  ),
                  SizedBox(
                    height: media.width * 0.05,
                  ),
                  Container(
                      padding: const EdgeInsets.only(left: 15),
                      height: media.width * 0.5,
                      width: double.maxFinite,
                      child: LineChart(
                        LineChartData(
                          showingTooltipIndicators:
                          showingTooltipOnSpots.map((index) {
                            return ShowingTooltipIndicators([
                              LineBarSpot(
                                tooltipsOnBar,
                                lineBarsData.indexOf(tooltipsOnBar),
                                tooltipsOnBar.spots[index],
                              ),
                            ]);
                          }).toList(),
                          lineTouchData: LineTouchData(
                            enabled: true,
                            handleBuiltInTouches: false,
                            touchCallback: (FlTouchEvent event,
                                LineTouchResponse? response) {
                              if (response == null ||
                                  response.lineBarSpots == null) {
                                return;
                              }
                              if (event is FlTapUpEvent) {
                                final spotIndex =
                                    response.lineBarSpots!.first.spotIndex;
                                showingTooltipOnSpots.clear();
                                setState(() {
                                  showingTooltipOnSpots.add(spotIndex);
                                });
                              }
                            },
                            mouseCursorResolver: (FlTouchEvent event,
                                LineTouchResponse? response) {
                              if (response == null ||
                                  response.lineBarSpots == null) {
                                return SystemMouseCursors.basic;
                              }
                              return SystemMouseCursors.click;
                            },
                            getTouchedSpotIndicator: (LineChartBarData barData,
                                List<int> spotIndexes) {
                              return spotIndexes.map((index) {
                                return TouchedSpotIndicatorData(
                                  FlLine(
                                    color: Colors.transparent,
                                  ),
                                  FlDotData(
                                    show: true,
                                    getDotPainter:
                                        (spot, percent, barData, index) =>
                                        FlDotCirclePainter(
                                          radius: 3,
                                          color: Colors.white,
                                          strokeWidth: 3,
                                          strokeColor: TColor.secondaryColor1,
                                        ),
                                  ),
                                );
                              }).toList();
                            },
                            touchTooltipData: LineTouchTooltipData(
                              getTooltipColor: (spot) => TColor.secondaryColor1,
                              tooltipRoundedRadius: 20,
                              getTooltipItems: (List<LineBarSpot> lineBarsSpot) {
                                return lineBarsSpot.map((lineBarSpot) {
                                  return LineTooltipItem(
                                    "${lineBarSpot.x.toInt()} mins ago",
                                    const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  );
                                }).toList();
                              },
                            ),
                          ),
                          lineBarsData: lineBarsData1,
                          minY: -0.5,
                          maxY: 110,
                          titlesData: FlTitlesData(
                              show: true,
                              leftTitles: AxisTitles(),
                              topTitles: AxisTitles(),
                              bottomTitles: AxisTitles(
                                sideTitles: bottomTitles,
                              ),
                              rightTitles: AxisTitles(
                                sideTitles: rightTitles,
                              )),
                          gridData: FlGridData(
                            show: true,
                            drawHorizontalLine: true,
                            horizontalInterval: 25,
                            drawVerticalLine: false,
                            getDrawingHorizontalLine: (value) {
                              return FlLine(
                                color: TColor.gray.withOpacity(0.15),
                                strokeWidth: 2,
                              );
                            },
                          ),
                          borderData: FlBorderData(
                            show: true,
                            border: Border.all(
                              color: Colors.transparent,
                            ),
                          ),
                        ),
                      )),
                  SizedBox(
                    height: media.width * 0.05,
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Latest Workout",
                        style: TextStyle(
                            color: TColor.black,
                            fontSize: 16,
                            fontWeight: FontWeight.w700),
                      ),
                      TextButton(
                        onPressed: () {},
                        child: Text(
                          "See More",
                          style: TextStyle(
                              color: TColor.gray,
                              fontSize: 14,
                              fontWeight: FontWeight.w700),
                        ),
                      )
                    ],
                  ),
                  ListView.builder(
                      padding: EdgeInsets.zero,
                      physics: const NeverScrollableScrollPhysics(),
                      shrinkWrap: true,
                      itemCount: lastWorkoutArr.length,
                      itemBuilder: (context, index) {
                        var wObj = lastWorkoutArr[index] as Map? ?? {};
                        return InkWell(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                  const FinishedWorkoutView(),
                                ),
                              );
                            },
                            child: WorkoutRow(wObj: wObj));
                      }),
                  SizedBox(
                    height: media.width * 0.1,
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildWaterIntakeSection(Size media) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Water Intake",
                style: TextStyle(
                    color: TColor.black,
                    fontSize: 12,
                    fontWeight: FontWeight.w700),
              ),
              GestureDetector(
                onTap: () {
                  _showWaterTargetDialog(context);
                },
                child: Container(
                  padding: EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: TColor.secondaryColor1.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.settings,
                    color: TColor.secondaryColor1,
                    size: 16,
                  ),
                ),
              ),
            ],
          ),
          GestureDetector(
            onDoubleTap: healthController.addWater,
            child: ShaderMask(
              blendMode: BlendMode.srcIn,
              shaderCallback: (bounds) {
                return LinearGradient(
                    colors: TColor.primaryG,
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight)
                    .createShader(Rect.fromLTRB(0, 0, bounds.width, bounds.height));
              },
              child: Obx(() => Text(
                healthController.healthData.value.waterIntake,
                style: TextStyle(
                    color: TColor.white.withOpacity(0.7),
                    fontWeight: FontWeight.w700,
                    fontSize: 14),
              )),
            ),
          ),
          SizedBox(height: 30),
          Container(
            height: media.width * 0.6,
            child: Center(
              child: GestureDetector(
                onDoubleTap: healthController.addWater,
                child: Obx(() => Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    Container(
                      width: media.width * 0.25,
                      height: media.width * 0.5,
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        border: Border.all(
                          color: TColor.secondaryColor1.withOpacity(0.6),
                          width: 3,
                        ),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(media.width * 0.06),
                          topRight: Radius.circular(media.width * 0.06),
                          bottomLeft: Radius.circular(media.width * 0.06),
                          bottomRight: Radius.circular(media.width * 0.06),
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(media.width * 0.06),
                          topRight: Radius.circular(media.width * 0.06),
                          bottomLeft: Radius.circular(media.width * 0.06),
                          bottomRight: Radius.circular(media.width * 0.06),
                        ),
                        child: Stack(
                          children: [
                            Align(
                              alignment: Alignment.bottomCenter,
                              child: AnimatedContainer(
                                duration: Duration(milliseconds: 500),
                                width: media.width * 0.23,
                                height: (media.width * 0.47) * (healthController.healthData.value.waterProgressValue / 100),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      TColor.secondaryColor1.withOpacity(0.9),
                                      TColor.secondaryColor2.withOpacity(0.9),
                                      TColor.secondaryColor1.withOpacity(0.9),
                                    ],
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                  ),
                                  borderRadius: BorderRadius.only(
                                    bottomLeft: Radius.circular(media.width * 0.05),
                                    bottomRight: Radius.circular(media.width * 0.05),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      top: media.width * 0.5,
                      child: Container(
                        width: media.width * 0.15,
                        height: media.width * 0.04,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(
                            color: TColor.secondaryColor1.withOpacity(0.6),
                            width: 3,
                          ),
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(media.width * 0.03),
                            topRight: Radius.circular(media.width * 0.03),
                            bottomLeft: Radius.circular(media.width * 0.03),
                            bottomRight: Radius.circular(media.width * 0.03),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: media.width * 0.54,
                      child: Container(
                        width: media.width * 0.1,
                        height: media.width * 0.02,
                        decoration: BoxDecoration(
                          color: TColor.secondaryColor1,
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(media.width * 0.015),
                            topRight: Radius.circular(media.width * 0.015),
                            bottomLeft: Radius.circular(media.width * 0.015),
                            bottomRight: Radius.circular(media.width * 0.015),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 6,
                              offset: Offset(0, 3),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      left: media.width * 0.27,
                      top: 0,
                      bottom: 0,

                      child: Container(
                        width: media.width * 0.06,
                        child: Obx(() => Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildWaterMarker("${healthController.healthData.value.waterTarget.toInt()}L", media),
                            _buildWaterMarker("${(healthController.healthData.value.waterTarget * 0.75).toInt()}L", media),
                            _buildWaterMarker("${(healthController.healthData.value.waterTarget * 0.5).toInt()}L", media),
                            _buildWaterMarker("${(healthController.healthData.value.waterTarget * 0.25).toInt()}L", media),
                            _buildWaterMarker("0L", media),
                          ],
                        )),
                      ),
                    ),
                    Positioned(
                      bottom: (media.width * 0.47) * (healthController.healthData.value.waterProgressValue / 100),
                      left: media.width * 0.015,
                      right: media.width * 0.015,
                      child: Container(
                        height: 6,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              TColor.secondaryColor1.withOpacity(0.8),
                              TColor.secondaryColor2.withOpacity(0.6),
                              TColor.secondaryColor1.withOpacity(0.4),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                    Positioned(
                      right: media.width * 0.28,
                      top: (media.width * 0.47) * (1 - healthController.healthData.value.waterProgressValue / 100) - 20,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: TColor.secondaryColor1.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(6),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 6,
                              offset: Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Obx(() => Text(
                          healthController.healthData.value.waterIntake,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        )),
                      ),
                    ),
                    Positioned(
                      top: media.width * 0.1,
                      left: 0,
                      right: 0,
                      child: Container(
                        height: media.width * 0.2,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(media.width * 0.03),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.water_drop,
                              color: TColor.secondaryColor1.withOpacity(0.3),
                              size: media.width * 0.06,
                            ),
                            SizedBox(height: 4),
                            Text(
                              "H2O",
                              style: TextStyle(
                                color: TColor.secondaryColor1.withOpacity(0.4),
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                )),
              ),
            ),
          ),
          const SizedBox(height: 45),
        ],
      ),
    );
  }

  Widget _buildWaterMarker(String text, Size media) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 1,
            color: TColor.gray.withOpacity(0.6),
          ),
          SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: TColor.gray,
              fontSize: 8,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSleepCard(Size media) {
    return Container(
      width: double.maxFinite,
      height: media.width * 0.4,
      padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 15),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(25),
          boxShadow: const [
            BoxShadow(color: Colors.black12, blurRadius: 2)
          ]),
      child: StreamBuilder(
        stream: Stream.periodic(Duration(seconds: 1)),
        builder: (context, snapshot) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Time to 10 PM",
                style: TextStyle(
                    color: TColor.black,
                    fontSize: 11,
                    fontWeight: FontWeight.w700),
              ),
              ShaderMask(
                blendMode: BlendMode.srcIn,
                shaderCallback: (bounds) {
                  return LinearGradient(
                      colors: TColor.primaryG,
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight)
                      .createShader(Rect.fromLTRB(0, 0, bounds.width, bounds.height));
                },
                child: Text(
                  _getTimeTo10PM(),
                  style: TextStyle(
                      color: TColor.white.withOpacity(0.7),
                      fontWeight: FontWeight.w700,
                      fontSize: 12),
                ),
              ),
              const Spacer(),
              Image.asset("assets/img/sleep_grap.png",
                  width: double.maxFinite,
                  fit: BoxFit.fitWidth)
            ],
          );
        },
      ),
    );
  }

  Widget _buildCaloriesCard(Size media) {
    return Container(
      width: double.maxFinite,
      height: media.width * 0.45,
      padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 15),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(25),
          boxShadow: const [
            BoxShadow(color: Colors.black12, blurRadius: 2)
          ]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Calories",
                style: TextStyle(
                    color: TColor.black,
                    fontSize: 11,
                    fontWeight: FontWeight.w700),
              ),
              GestureDetector(
                onTap: () {
                  _showCalorieTargetDialog(context);
                },
                child: Container(
                  padding: EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: TColor.primaryColor1.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    Icons.settings,
                    color: TColor.primaryColor1,
                    size: 14,
                  ),
                ),
              ),
            ],
          ),
          ShaderMask(
            blendMode: BlendMode.srcIn,
            shaderCallback: (bounds) {
              return LinearGradient(
                  colors: TColor.primaryG,
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight)
                  .createShader(Rect.fromLTRB(0, 0, bounds.width, bounds.height));
            },
            child: Obx(() => Text(
              healthController.healthData.value.calories,
              style: TextStyle(
                  color: TColor.white.withOpacity(0.7),
                  fontWeight: FontWeight.w700,
                  fontSize: 12),
            )),
          ),
          SizedBox(height: 6),
          Expanded(
            child: GestureDetector(
              onDoubleTap: healthController.addCalories,
              child: Container(
                alignment: Alignment.center,
                child: SizedBox(
                  width: media.width * 0.2,
                  height: media.width * 0.2,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SimpleCircularProgressBar(
                        progressStrokeWidth: 8,
                        backStrokeWidth: 8,
                        progressColors: TColor.primaryG,
                        backColor: Colors.grey.shade100,
                        valueNotifier: healthController.progressNotifier,
                        startAngle: -180,
                        onGetText: (value) {
                          return Text('');
                        },
                      ),
                      Container(
                        width: media.width * 0.15,
                        height: media.width * 0.15,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: TColor.primaryG),
                          borderRadius: BorderRadius.circular(media.width * 0.075),
                        ),
                        child: Obx(() => Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              healthController.healthData.value.caloriesLeft.split('\n')[0],
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: TColor.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              "left",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: TColor.white,
                                fontSize: 8,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        )),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          )
        ],
      ),
    );
  }

  List<PieChartSectionData> showingSections() {
    final bmiValue = healthController.healthData.value.bmi;
    final bmiCategory = healthController.healthData.value.bmiCategory;

    double bmiSectionValue;
    Color bmiColor;

    if (bmiValue < 18.5) {
      bmiSectionValue = 25;
      bmiColor = Colors.blue;
    } else if (bmiValue < 25) {
      bmiSectionValue = 33;
      bmiColor = Colors.green;
    } else if (bmiValue < 30) {
      bmiSectionValue = 50;
      bmiColor = Colors.orange;
    } else {
      bmiSectionValue = 66;
      bmiColor = Colors.red;
    }

    return List.generate(
      2,
          (i) {
        switch (i) {
          case 0:
            return PieChartSectionData(
                color: bmiColor,
                value: bmiSectionValue,
                title: '',
                radius: 40,
                titlePositionPercentageOffset: 0.55,
                badgeWidget: Text(
                  healthController.healthData.value.bmi.toStringAsFixed(1),
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700),
                ));
          case 1:
            return PieChartSectionData(
              color: Colors.white,
              value: 100 - bmiSectionValue,
              title: '',
              radius: 30,
              titlePositionPercentageOffset: 0.55,
            );

          default:
            throw Error();
        }
      },
    );
  }

  LineTouchData get lineTouchData1 => LineTouchData(
    handleBuiltInTouches: true,
    touchTooltipData: LineTouchTooltipData(
      getTooltipColor: (spot) => Colors.blueGrey.withOpacity(0.8),
    ),
  );

  List<LineChartBarData> get lineBarsData1 => [
    lineChartBarData1_1,
    lineChartBarData1_2,
  ];

  LineChartBarData get lineChartBarData1_1 => LineChartBarData(
    isCurved: true,
    gradient: LinearGradient(colors: [
      TColor.primaryColor2.withOpacity(0.5),
      TColor.primaryColor1.withOpacity(0.5),
    ]),
    barWidth: 4,
    isStrokeCapRound: true,
    dotData: FlDotData(show: false),
    belowBarData: BarAreaData(show: false),
    spots: const [
      FlSpot(1, 35),
      FlSpot(2, 70),
      FlSpot(3, 40),
      FlSpot(4, 80),
      FlSpot(5, 25),
      FlSpot(6, 70),
      FlSpot(7, 35),
    ],
  );

  LineChartBarData get lineChartBarData1_2 => LineChartBarData(
    isCurved: true,
    gradient: LinearGradient(colors: [
      TColor.secondaryColor2.withOpacity(0.5),
      TColor.secondaryColor1.withOpacity(0.5),
    ]),
    barWidth: 2,
    isStrokeCapRound: true,
    dotData: FlDotData(show: false),
    belowBarData: BarAreaData(
      show: false,
    ),
    spots: const [
      FlSpot(1, 80),
      FlSpot(2, 50),
      FlSpot(3, 90),
      FlSpot(4, 40),
      FlSpot(5, 80),
      FlSpot(6, 35),
      FlSpot(7, 60),
    ],
  );

  SideTitles get rightTitles => SideTitles(
    getTitlesWidget: rightTitleWidgets,
    showTitles: true,
    interval: 20,
    reservedSize: 40,
  );

  Widget rightTitleWidgets(double value, TitleMeta meta) {
    String text;
    switch (value.toInt()) {
      case 0:
        text = '0%';
        break;
      case 20:
        text = '20%';
        break;
      case 40:
        text = '40%';
        break;
      case 60:
        text = '60%';
        break;
      case 80:
        text = '80%';
        break;
      case 100:
        text = '100%';
        break;
      default:
        return Container();
    }

    return Text(text,
        style: TextStyle(
          color: TColor.gray,
          fontSize: 12,
        ),
        textAlign: TextAlign.center);
  }

  SideTitles get bottomTitles => SideTitles(
    showTitles: true,
    reservedSize: 32,
    interval: 1,
    getTitlesWidget: bottomTitleWidgets,
  );

  Widget bottomTitleWidgets(double value, TitleMeta meta) {
    var style = TextStyle(
      color: TColor.gray,
      fontSize: 12,
    );
    Widget text;
    switch (value.toInt()) {
      case 1:
        text = Text('Sun', style: style);
        break;
      case 2:
        text = Text('Mon', style: style);
        break;
      case 3:
        text = Text('Tue', style: style);
        break;
      case 4:
        text = Text('Wed', style: style);
        break;
      case 5:
        text = Text('Thu', style: style);
        break;
      case 6:
        text = Text('Fri', style: style);
        break;
      case 7:
        text = Text('Sat', style: style);
        break;
      default:
        text = const Text('');
        break;
    }

    return SideTitleWidget(
      axisSide: meta.axisSide,
      space: 10,
      child: text,
    );
  }
}

class SettingsController extends GetxController {
  @override
  void onInit() {
    getData = getUserData();
    super.onInit();
  }
  var isLoading = false.obs;
  var currentUser = FirebaseAuth.instance.currentUser;
  var username = ''.obs;
  var email = ''.obs;
  Future? getData;

  getUserData() async {
    try {
      isLoading(true);
      print("=== DEBUG START ===");
      print("🔄 Current User UID: ${currentUser?.uid}");
      print("📧 Current User Email: ${currentUser?.email}");

      DocumentSnapshot<Map<String, dynamic>> user = await FirebaseFirestore
          .instance
          .collection("Users")
          .doc(currentUser!.uid)
          .get();

      print("📄 Document exists: ${user.exists}");

      if (user.exists) {
        var UserData = user.data();
        print("📊 User Data: $UserData");

        if (UserData != null && UserData.containsKey('username')) {
          username.value = UserData['username'] ?? "";
          print("✅ Username found: ${username.value}");
        } else {
          print("❌ Username field not found - creating it");
          await _createUserDocument();
        }
      } else {
        print("❌ User document does not exist - CREATING NOW");
        await _createUserDocument();
      }

      email.value = currentUser!.email ?? "";
      print("=== DEBUG END ===");
    } catch (e) {
      print("❌ ERROR: $e");
      username.value = "User";
    } finally {
      isLoading(false);
    }
  }

  Future<void> _createUserDocument() async {
    try {
      print("🛠️ Creating user document...");

      String generatedUsername = currentUser!.email?.split('@').first ?? "User";

      await FirebaseFirestore.instance
          .collection("Users")
          .doc(currentUser!.uid)
          .set({

        'username': generatedUsername,
        'email': currentUser!.email,
        'createdAt': FieldValue.serverTimestamp(),
      });

      print("✅ User document created with username: $generatedUsername");
      username.value = generatedUsername;

    } catch (e) {
      print("❌ Error creating user document: $e");
      username.value = "User";
    }
  }
}