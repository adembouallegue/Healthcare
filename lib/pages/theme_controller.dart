import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:healthcare/theme/dark_mode.dart';
import 'package:healthcare/theme/light_mode.dart';

class ThemeController extends GetxController {
  var isDarkMode = false.obs;

  ThemeData get currentTheme => isDarkMode.value ? darkMode : lighMode;

  void toggleTheme() {
    isDarkMode.value = !isDarkMode.value;
    Get.changeThemeMode(isDarkMode.value ? ThemeMode.dark : ThemeMode.light);
  }

  void setTheme(bool darkMode) {
    isDarkMode.value = darkMode;
    Get.changeThemeMode(darkMode ? ThemeMode.dark : ThemeMode.light);
  }
}