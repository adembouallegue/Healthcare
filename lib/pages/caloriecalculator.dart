import 'dart:io';

import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';

class CalorieCalculator extends StatefulWidget {
  const CalorieCalculator({super.key});

  @override
  State<CalorieCalculator> createState() => _CalorieCalculatorState();
}

class _CalorieCalculatorState extends State<CalorieCalculator> {
  bool isLoading = false;
  String API_KEY = "AIzaSyDDw1M8z5UyCG-kk_3Dg5lnggVA52hy9jY"; // Put your API key here
  dynamic response;
  File? selectedFile;

  final ImagePicker _picker = ImagePicker();

  void pickImageFromGallery() async {
    final XFile? img = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 400,
    );

    if (img != null) {
      setState(() {
        selectedFile = File(img.path);
      });
    }
  }

  void takePictureWithCamera() async {
    final XFile? img = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 400,
    );

    if (img != null) {
      setState(() {
        selectedFile = File(img.path);
      });
    }
  }

  Widget buildFilePreview() {
    if (selectedFile == null) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.upload_file, size: 60, color: Colors.grey),
          SizedBox(height: 10),
          Text(
            'No file selected',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          SizedBox(height: 5),
          Text(
            'Pick an image from gallery or take a picture',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.blueGrey),
          ),
        ],
      );
    } else {
      return Image.file(
        selectedFile!,
        width: double.infinity,
        height: 250,
        fit: BoxFit.cover,
      );
    }
  }

  void calculateCalories() async {
    if (selectedFile == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Please select an image')));
      return;
    }

    setState(() {
      isLoading = true;
    });

    final model = GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: API_KEY,
      systemInstruction: Content.system(
        '''You are a nutrition expert. Based on the image of the food dish, identify the dish and estimate its total calorie count.
Include: Dish Name, Estimated Calories, Protein, Carbs, Fats, Ingredients breakdown, Confidence Level.''',
      ),
    );

    response = await model.generateContent([
      Content.multi([
        DataPart(
          lookupMimeType(selectedFile!.path) ?? 'application/octet-stream',
          await selectedFile!.readAsBytes(),
        ),
      ]),
    ]);

    setState(() {
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          "Calorie Calculator",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
        ),
        backgroundColor: Colors.blueAccent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text(
              'Upload an image or take a picture of a dish to calculate its calories.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.blueGrey),
            ),
            const SizedBox(height: 20),
            DottedBorder(
              borderType: BorderType.RRect,
              radius: const Radius.circular(12),
              dashPattern: const [6, 4],
              color: Colors.grey,
              child: Container(
                width: double.infinity,
                height: 250,
                padding: const EdgeInsets.all(12),
                child: buildFilePreview(),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: pickImageFromGallery,
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Pick Image'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      minimumSize: const Size(double.infinity, 50),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: takePictureWithCamera,
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Take Picture'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.lightBlue[700],
                      minimumSize: const Size(double.infinity, 50),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: calculateCalories,
              icon: const Icon(Icons.food_bank),
              label: const Text(
                'Calculate Calories',
                style: TextStyle(fontSize: 18),
              ),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                backgroundColor: Colors.lightBlue[400],
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator(color: Colors.blueAccent))
                  : response != null
                  ? Card(
                color: Colors.lightBlue[50],
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: SingleChildScrollView(
                    child: Text(
                      response.text,
                      style: const TextStyle(
                          fontSize: 14, height: 1.8,color: Colors.black),
                    ),
                  ),
                ),
              )
                  : const SizedBox(),
            ),
          ],
        ),
      ),
    );
  }
}
