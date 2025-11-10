// exercise_library.dart
class Exercise {
  final String id;
  final String name;
  final String description;
  final String image;
  final String category;
  final String difficulty;
  final List<String> muscles;
  final String instructions;
  final int caloriesPerMinute;
  final int defaultDuration;

  Exercise({
    required this.id,
    required this.name,
    required this.description,
    required this.image,
    required this.category,
    required this.difficulty,
    required this.muscles,
    required this.instructions,
    required this.caloriesPerMinute,
    required this.defaultDuration,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'image': image,
      'category': category,
      'difficulty': difficulty,
      'muscles': muscles,
      'instructions': instructions,
      'caloriesPerMinute': caloriesPerMinute,
      'defaultDuration': defaultDuration,
    };
  }

  factory Exercise.fromMap(Map<String, dynamic> data) {
    return Exercise(
      id: data['id'] ?? '',
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      image: data['image'] ?? '',
      category: data['category'] ?? '',
      difficulty: data['difficulty'] ?? '',
      muscles: List<String>.from(data['muscles'] ?? []),
      instructions: data['instructions'] ?? '',
      caloriesPerMinute: data['caloriesPerMinute'] ?? 5,
      defaultDuration: data['defaultDuration'] ?? 10,
    );
  }

  int calculateCalories(int durationMinutes) {
    return caloriesPerMinute * durationMinutes;
  }
}

class ExerciseLibrary {
  static List<Exercise> getAllExercises() {
    return [
      // PUSH EXERCISES
      Exercise(
        id: 'push_1',
        name: 'Bench Press',
        description: 'Compound exercise for chest, shoulders, and triceps',
        image: 'assets/img/bench_press.png',
        category: 'push',
        difficulty: 'beginner',
        muscles: ['Chest', 'Shoulders', 'Triceps'],
        instructions: '''
1. Lie on bench with feet flat on floor
2. Grip barbell slightly wider than shoulder width
3. Lower bar to chest slowly
4. Press bar back to starting position
5. Keep back flat and core engaged''',
        caloriesPerMinute: 8,
        defaultDuration: 15,
      ),
      Exercise(
        id: 'push_2',
        name: 'Overhead Press',
        description: 'Shoulder press for building strong deltoids',
        image: 'assets/img/overhead_press.png',
        category: 'push',
        difficulty: 'intermediate',
        muscles: ['Shoulders', 'Triceps', 'Upper Chest'],
        instructions: '''
1. Stand with feet shoulder-width apart
2. Hold barbell at shoulder level
3. Press bar overhead until arms are fully extended
4. Lower bar back to shoulders
5. Keep core tight throughout movement''',
        caloriesPerMinute: 6,
        defaultDuration: 12,
      ),
      Exercise(
        id: 'push_3',
        name: 'Push-ups',
        description: 'Bodyweight chest and core exercise',
        image: 'assets/img/pushups.png',
        category: 'push',
        difficulty: 'beginner',
        muscles: ['Chest', 'Shoulders', 'Triceps', 'Core'],
        instructions: '''
1. Hands slightly wider than shoulders
2. Keep body in straight line
3. Lower until chest nearly touches floor
4. Push back to starting position
5. Don't let hips sag''',
        caloriesPerMinute: 7,
        defaultDuration: 10,
      ),
      Exercise(
        id: 'push_4',
        name: 'Tricep Pushdown',
        description: 'Isolation exercise for tricep development',
        image: 'assets/img/tricep_pushdown.png',
        category: 'push',
        difficulty: 'beginner',
        muscles: ['Triceps'],
        instructions: '''
1. Stand facing cable machine
2. Grip bar with palms down
3. Keep elbows tucked at sides
4. Push bar down until arms are straight
5. Return slowly to starting position''',
        caloriesPerMinute: 4,
        defaultDuration: 10,
      ),

      // PULL EXERCISES
      Exercise(
        id: 'pull_1',
        name: 'Pull-ups',
        description: 'Bodyweight exercise for back and biceps',
        image: 'assets/img/pullups.png',
        category: 'pull',
        difficulty: 'intermediate',
        muscles: ['Back', 'Biceps', 'Forearms'],
        instructions: '''
1. Grip bar slightly wider than shoulders
2. Hang with arms fully extended
3. Pull body up until chin clears bar
4. Lower with control
5. Avoid swinging''',
        caloriesPerMinute: 9,
        defaultDuration: 12,
      ),
      Exercise(
        id: 'pull_2',
        name: 'Bent Over Rows',
        description: 'Compound back exercise',
        image: 'assets/img/bent_over_rows.png',
        category: 'pull',
        difficulty: 'intermediate',
        muscles: ['Back', 'Biceps', 'Rear Shoulders'],
        instructions: '''
1. Bend knees slightly, hinge at hips
2. Keep back straight, nearly parallel to floor
3. Pull barbell to lower chest
4. Squeeze shoulder blades together
5. Lower with control''',
        caloriesPerMinute: 7,
        defaultDuration: 15,
      ),
      Exercise(
        id: 'pull_3',
        name: 'Lat Pulldowns',
        description: 'Machine exercise for back width',
        image: 'assets/img/lat_pulldowns.png',
        category: 'pull',
        difficulty: 'beginner',
        muscles: ['Lats', 'Biceps', 'Back'],
        instructions: '''
1. Sit with thighs under pads
2. Grip bar wide, lean back slightly
3. Pull bar to upper chest
4. Squeeze lats at bottom
5. Return slowly''',
        caloriesPerMinute: 5,
        defaultDuration: 12,
      ),

      // LEG EXERCISES
      Exercise(
        id: 'legs_1',
        name: 'Barbell Squats',
        description: 'The king of leg exercises',
        image: 'assets/img/squats.png',
        category: 'legs',
        difficulty: 'intermediate',
        muscles: ['Quads', 'Glutes', 'Hamstrings'],
        instructions: '''
1. Bar rests on upper back, not neck
2. Feet shoulder-width apart
3. Descend until thighs parallel to floor
4. Keep chest up, back straight
5. Drive through heels to stand''',
        caloriesPerMinute: 10,
        defaultDuration: 20,
      ),
      Exercise(
        id: 'legs_2',
        name: 'Lunges',
        description: 'Unilateral leg exercise for balance',
        image: 'assets/img/lunges.png',
        category: 'legs',
        difficulty: 'beginner',
        muscles: ['Quads', 'Glutes', 'Hamstrings'],
        instructions: '''
1. Step forward with one leg
2. Lower until both knees at 90 degrees
3. Front knee shouldn't pass toes
4. Push back to starting position
5. Alternate legs''',
        caloriesPerMinute: 6,
        defaultDuration: 15,
      ),
      Exercise(
        id: 'legs_3',
        name: 'Romanian Deadlifts',
        description: 'Hamstring and glute focused exercise',
        image: 'assets/img/romanian_deadlift.png',
        category: 'legs',
        difficulty: 'intermediate',
        muscles: ['Hamstrings', 'Glutes', 'Lower Back'],
        instructions: '''
1. Stand with feet hip-width apart
2. Hinge at hips, keep back straight
3. Lower bar along legs
4. Stop when you feel hamstring stretch
5. Return to standing by squeezing glutes''',
        caloriesPerMinute: 8,
        defaultDuration: 15,
      ),
    ];
  }

  static List<Exercise> getExercisesByCategory(String category) {
    return getAllExercises().where((exercise) => exercise.category == category).toList();
  }

  static List<String> getCategories() {
    return ['push', 'pull', 'legs'];
  }

  static String getCategoryDisplayName(String category) {
    switch (category) {
      case 'push':
        return 'Push Exercises';
      case 'pull':
        return 'Pull Exercises';
      case 'legs':
        return 'Leg Exercises';
      default:
        return 'Exercises';
    }
  }

  static String getCategoryDescription(String category) {
    switch (category) {
      case 'push':
        return 'Exercises that involve pushing movements. Target chest, shoulders, and triceps.';
      case 'pull':
        return 'Exercises that involve pulling movements. Target back, biceps, and rear delts.';
      case 'legs':
        return 'Exercises for lower body development. Target quads, hamstrings, glutes, and calves.';
      default:
        return 'General exercises';
    }
  }
}