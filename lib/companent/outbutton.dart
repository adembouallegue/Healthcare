import 'package:flutter/material.dart';

class outButton extends StatelessWidget {
  final String text;
  final void Function()? onTap;
  const outButton({super.key, required this.text,required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(color: Colors.red,
        borderRadius: BorderRadius.circular(40)),
        height:50 ,
        width:150,
        child: Center(
          child: Text(text,      
          style:const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 15),
        ),
      ),
    ));
  }
}