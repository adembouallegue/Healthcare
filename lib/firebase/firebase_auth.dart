import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:healthcare/pages/loginPage.dart';


  final String USER_COLLECTION = 'Users';


FirebaseAuth _auth = FirebaseAuth.instance;
class FirebaseAuthService{
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  //------------------------------------sign Up With Email And Password methode----------------------------------------//

    Future<User?> signUpWithEmailAndPassword(String email, String password, String username ,BuildContext context) async {
    try {
      UserCredential credential = await _auth.createUserWithEmailAndPassword(email: email, password: password);
      String user = credential.user!.uid;
      await _db.collection('Users').doc(user).set({

        'username': username,
        'email': email,
        'password':password,
      });

      print("all good");
  //------------------------------------showDialog catch----------------------------------------//

    } on FirebaseException catch (e) {
      print(e);

    }
    return null;
  }

  //------------------------------------sign In With Email And Password methode----------------------------------------//

    Future<User?> signInWithEmailAndPassword(String email,String password)async{
    try{
      UserCredential credential =await _auth.signInWithEmailAndPassword(email:email, password:password);
      return credential.user;
    }catch(e){
      print("somme error occured");
    }
    return null;
  }
  //------------------------------------signout methode----------------------------------------//
  Future<void> signOut(BuildContext context) async {
    try {
      await _auth.signOut();
      Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => loginPage()),
                    (route) => false,
                  );;print("l account tsaker");
    } catch (e) {
      print("Error signing out: $e");
    }
  }


  //------------------------------------change password methode----------------------------------------//

Future<void> updatePassword(String currentPassword, String newPassword) async {
  try {
    User? user = _auth.currentUser;
    if (user != null) {
      AuthCredential credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(newPassword);
      print('Password updated successfully');
    } else {
      throw FirebaseAuthException(
        code: 'user-not-found',
        message: 'No user signed in',
      );
    }
  } catch (e) {
    print('Error updating password: $e');
    throw e;
  }
}

}






