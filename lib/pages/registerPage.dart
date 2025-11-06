import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:healthcare/companent/my_button.dart';
import 'package:healthcare/companent/my_textfield.dart';
import 'package:healthcare/firebase/firebase_auth.dart';
import 'package:healthcare/pages/loginPage.dart';

class RegisterPage extends StatefulWidget {


  RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final FirebaseAuthService _auth = FirebaseAuthService();


  //------------------------------------text controller----------------------------------------//


  TextEditingController UsernameController = TextEditingController();

  TextEditingController emailController = TextEditingController();

  TextEditingController passwordController = TextEditingController();

  TextEditingController confirmPwController = TextEditingController();

  // String passwordErrorText = '';


  //------------------------------------dispose method----------------------------------------//


  void dispose() {
    UsernameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPwController.dispose();
    super.dispose();
  }


  //-------------------------------------register method-----------------------------------------//


  void register() async {
    String username = UsernameController.text;
    String email = emailController.text;
    String password = passwordController.text;
    String confirmpw = confirmPwController.text;

  //-------------------------------------valid email fonction-----------------------------------------//


    bool isValidEmail(String email) {
      RegExp emailRegex =
          RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
      return emailRegex.hasMatch(email);
    }

  //-------------------------------------fill all required fields.-----------------------------------------//

    if (UsernameController.text.isEmpty ||
        emailController.text.isEmpty ||
        passwordController.text.isEmpty ||
        confirmPwController.text.isEmpty) {
      showDialog(
          context: context,
          builder: (context) => AlertDialog(
                shape:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(30)),
                title: Text("Warning"),
                content: Text("Please fill in the required fields."),
                actions: [
                  TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      child: Text("OK",
                          style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .inversePrimary)))
                ],
              ));
    }

  //----------------------------------------Check email format--------------------------------------//


    else if (!isValidEmail(email)) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            shape: OutlineInputBorder(borderRadius: BorderRadius.circular(30)),
            title: Text("Invalid Email Format"),
            content: Text(
                "Please enter a valid email address ."),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(); // Close the dialog
                },
                child: Text("OK",
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.inversePrimary)),
              ),
            ],
          );
        },
      );
      return;
    }

  //----------------------------------------Check if password is less than 8 characters--------------------------------------//


    else if (password.length < 8) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            shape: OutlineInputBorder(
              borderRadius: BorderRadius.circular(30),
            ),
            title: Text("Password Too Short"),
            content: Text(
                "The password must be at least 8 characters long. Please choose a longer password."),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(); // Close the dialog
                },
                child: Text("OK",
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.inversePrimary)),
              ),
            ],
          );
        },
      );
      return;
    }

  //----------------------------------------Check if same password or not--------------------------------------//

    else if (password != confirmpw) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            shape: OutlineInputBorder(
              borderRadius: BorderRadius.circular(30),
            ),
            title: Text("Password Mismatch"),
            content:
                Text("The entered passwords do not match. Please try again."),
            actions: [
              TextButton(
                child: Text(
                  "OK",
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.inversePrimary),
                ),
                onPressed: () {
                  Navigator.of(context).pop(); 
                },
              ),
            ],
          );
        },
      );
      return;
    }
    else 

  //----------------------------------------signUpWithEmailAndPassword and go to login page--------------------------------------//

        showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
        ),
        title: Text("WELCOME !!"),
        content: Text("Your Account has been Added Successfully"),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close the dialog
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => loginPage()),
              );
            },
            child: Text("Ok",
                style: TextStyle(
                    color: Theme.of(context).colorScheme.inversePrimary)),
          ),
        ],
      ),
    );


    User? user = await _auth.signUpWithEmailAndPassword(
      email,
      password,
      username,
      context,
    );
     print(user);

  }
  //----------------------------------------page view--------------------------------------//

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

 //----------------------------------------logo--------------------------------------//


                Image.asset(
                  "images/icon.png",
                  width: 140,
                  height: 140,
                ),

 //----------------------------------------app name--------------------------------------//


                const Text(
                  "HealthCare",
                  style: TextStyle(
                      fontSize: 20, color: Color.fromARGB(220, 19, 105, 156)),
                ),
                const SizedBox(
                  height: 50,
                ),

 //----------------------------------------username text field--------------------------------------//

                MyTextField(
                    hintText: "Username",
                    obscureText: false,
                    controller: UsernameController),

                const SizedBox(
                  height: 20,
                ),

  //----------------------------------------email text field--------------------------------------//


                MyTextField(
                    hintText: "Email",
                    obscureText: false,
                    controller: emailController),

                const SizedBox(
                  height: 20,
                ),

  //----------------------------------------password text field--------------------------------------//

                MyTextField(
                    hintText: "Password",
                    obscureText: true,
                    controller: passwordController),
                const SizedBox(
                  height: 20,
                ),

  //----------------------------------------confirm password text field--------------------------------------//

                MyTextField(
                    hintText: "Confirm Password",
                    obscureText: true,
                    controller: confirmPwController),

                const SizedBox(
                  height: 20,
                ),

                const SizedBox(
                  height: 20,
                ),
  //----------------------------------------register button--------------------------------------//
                MyButton(text: "Register", onTap: register),
                const SizedBox(
                  height: 20,
                ),

  //----------------------------------------dont have account--------------------------------------//
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Already have an account?",
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.inversePrimary),
                    ),
  //----------------------------------------go to login page --------------------------------------//
                    GestureDetector(
                      onTap: () {
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(builder: (context) => loginPage()),
                          (route) => true,
                        );
                      },
                      child: const Text(
                        " Login here ",
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
        )
      )
    );
  }
}
