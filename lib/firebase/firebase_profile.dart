import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SettingsController extends GetxController {
  var username = 'Friend'.obs; // Default friendly name
  var isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    _loadUsername();
  }

  void _loadUsername() async {
    // Simple approach - just use email username
    try {
      var user = FirebaseAuth.instance.currentUser;
      if (user != null && user.email != null) {
        username.value = user.email!.split('@').first;
      }
    } catch (e) {
      print('Error getting username: $e');
    }
  }
}