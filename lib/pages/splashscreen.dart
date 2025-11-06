import 'package:flutter/material.dart';
import 'package:healthcare/companent/my_button.dart';
import 'package:healthcare/pages/loginPage.dart';
  //------------------------------------page view----------------------------------------//

class splashscreenPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.background,
      
  //------------------------------------appbar----------------------------------------//
      body: Center(
            child: Padding(
                padding: const EdgeInsets.all(10.0),
                child: SingleChildScrollView(
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
  //------------------------------------logo----------------------------------------//
                    SizedBox(height:80 ,),

                      Image.asset(
                        "images/icon.png",
                        width: 140,
                        height: 140,
                      ),

  //------------------------------------app name----------------------------------------//
                      const Text(
                        "HealthCare",
                        style: TextStyle(
                            fontSize: 28,
                            color: Color.fromARGB(220, 19, 105, 156)),
                      ),
                      const SizedBox(
                        height: 50,
                      ),SizedBox(height:50 ,),
  //------------------------------------feedbackmail----------------------------------------//
                      const Text(
                        "Welcome to HealthCare! ",
                        style: TextStyle(
                            fontSize: 28, )
                      ),
                      SizedBox(height:20 ,),
                      const Text(
                        "Your personal health companion.HealthCare helps you eat better, move smarter, and live longer",
                        style: TextStyle(
                            fontSize: 18, )
                      ),
                      SizedBox(height:150 ,),
                        //------------------------------------chatguide----------------------------------------//
                    MyButton(text: "GO START", onTap:() {Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => loginPage()),
                    );}),
                    
                    ]
                  )
                )
              )
            )
          );
  }
}
