import 'package:flutter/material.dart';
import 'package:healthcare/companent/my_button.dart';
import 'package:healthcare/companent/my_textfield.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:healthcare/pages/loginPage.dart';

class chpsw extends StatefulWidget {
  const chpsw({super.key});

  @override
  State<chpsw> createState() => _chpswState();
}

class _chpswState extends State<chpsw> {
  final emailController = TextEditingController();
  FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void dispose() {
    emailController.dispose();
    super.dispose();
  }
//--------------------------------------password reset methode-----------------------------------------//

  Future<void> passwordreset() async {
    try {
      await _auth.sendPasswordResetEmail(email: emailController.text.trim());
//----------------------showDialog check your email to change password and go to login page-------------------------//

      showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
        ),
        title: Text("Done"),
        content: Text("check your email to change password"),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); 
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
    } on FirebaseException catch (e) {
      print(e);
//----------------------showDialog catch error in the email-------------------------//

      showDialog(context: context, builder: (context){
        return AlertDialog(
          content: Text(e.message.toString()),
        );});
      
    }
  }


  //--------------------------------------page view-----------------------------------------//

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.background,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Image.asset(
            'images/icon.png',
            height: 70,
          ),
        ),
        centerTitle: true,
        title: Text(
          'Forgot Password',
          style: TextStyle(
            color: Color.fromARGB(220, 23, 119, 175),
          ),
        ),
        
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(10.0),
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
//----------------------logo-------------------------//

                Image.asset(
                  "images/icon.png",
                  width: 140,
                  height: 140,
                ),
//----------------------app name-------------------------//

                const Text(
                  "HealthCare",
                  style: TextStyle(
                      fontSize: 20,
                      color: Color.fromARGB(220, 19, 105, 156)),
                ),
                const SizedBox(
                  height: 50,
                ),
//----------------------Enter your email and we will send you a password link text-------------------------//

                const Text(
                  "Enter your email and we will send you a password link changer ",
                  style: TextStyle(fontSize: 20),
                  textAlign: TextAlign.center,
                ),
//-----------------------email TextField------------------------//

                MyTextField(
                    hintText: "Email",
                    obscureText: false,
                    controller: emailController),
                SizedBox(height: 10,),
//-----------------------go to login page------------------------//

                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    GestureDetector(
                      onTap: (){
                        Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => loginPage()),
                    (route) => true,
                  );
                      },
                      child: const Text(
                        " back to the login page ",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )
                  ],
                ),
                SizedBox(height: 10,),
//-----------------------eget password button------------------------//

                MyButton(text: 'get password', onTap: passwordreset),
                SizedBox(height: 10,),
                 
              ],
            ),
          ),
        ),
      ),
    );
  }
}
