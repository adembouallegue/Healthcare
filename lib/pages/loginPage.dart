import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:healthcare/companent/my_button.dart';
import 'package:healthcare/companent/my_textfield.dart';
import 'package:healthcare/firebase/firebase_auth.dart';
import 'package:healthcare/pages/chpsw.dart';
import 'package:healthcare/pages/home.dart';
import 'package:healthcare/pages/home_view.dart';
import 'package:healthcare/pages/registerPage.dart';


class loginPage extends StatefulWidget {

  loginPage({super.key});

  @override
  State<loginPage> createState() => _loginPageState();
}

class _loginPageState extends State<loginPage> {


  final FirebaseAuthService _auth = FirebaseAuthService();

  //------------------------------------text controller----------------------------------------//

  TextEditingController emailController = TextEditingController();
  TextEditingController passwordController = TextEditingController();
  @override
  void dispose(){
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  //------------------------------------login methode----------------------------------------//


  void login()async{

    String email = emailController.text;
    String password = passwordController.text;


  //------------------------------------user sign in and go to home page----------------------------------------//


    User? user =await _auth.signInWithEmailAndPassword(email, password);
    if(user != null){
      print("user is successfully signin");
      Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            HomeView(),
                      ));
    }else{
  //-------------------------------------fill all required fields and show dialog -----------------------------------------//

      if (emailController.text.isEmpty ||passwordController.text.isEmpty) {

      showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30)),
                title: Text("Warning"),
                content: Text("Please Enter All The Fields Correct"),
                actions: [
                  TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      child: Text("OK",style: TextStyle(color : Theme.of(context).colorScheme.inversePrimary)))
                ],
              ))
              ;
    }else{
  //-------------------------------------show dialog Email or password is incorrect-----------------------------------------//

      showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: OutlineInputBorder(borderRadius: BorderRadius.circular(30)),
            title: Text("Warning"),
            content: Text("Email or password is incorrect"),
            actions: [
              TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: Text("OK",
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.inversePrimary)))
                ],
          ),
        );
      }
    }
  }
  //-------------------------------------page view-----------------------------------------//

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(10.0),
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
  //-------------------------------------logo-----------------------------------------//

                Image.asset(
                  "images/icon.png",
                  width: 140,
                  height: 140,
                ),
  //-------------------------------------app name-----------------------------------------//

                const Text(
                  "HealthCare",
                  style: TextStyle(
                      fontSize: 20, color: Color.fromARGB(220, 19, 105, 156)),
                ),
                const SizedBox(
                  height: 50,
                ),
  //-------------------------------------username text field-----------------------------------------//

                MyTextField(
                    hintText: "Email",
                    obscureText: false,
                    controller: emailController),

                const SizedBox(
                  height: 20,
                ),
  //-------------------------------------password text field-----------------------------------------//

                MyTextField(
                    hintText: "Password",
                    obscureText: true,
                    controller: passwordController),
                const SizedBox(
                  height: 20,
                ),
  //-------------------------------------forget passward text and go to change password(chpsw)-----------------------------------------//

                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    GestureDetector(
                      onTap: (){
                        Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => chpsw()),
                    (route) => true,
                  );
                      },
                      child: const Text(
                        " Forgot password ",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )
                  ],
                ),
                const SizedBox(
                  height: 20,
                ),
  //-------------------------------------sign in button-----------------------------------------//

                MyButton(text: "Login", onTap: login),
                const SizedBox(
                  height: 20,
                ),
  //------------------------------------dont have account text and go to register page----------------------------------------//

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Don't have an account?",
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.inversePrimary),
                    ),
                    GestureDetector(
                      onTap: (){
                        Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => RegisterPage()),
                    (route) => true,
                  );
                      },
                      child: const Text(
                        " Register here ",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )
                  ],
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
