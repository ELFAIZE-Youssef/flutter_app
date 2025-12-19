import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;

class FruitClassifierPage extends StatefulWidget {
  const FruitClassifierPage({super.key});
  
  @override
  State<FruitClassifierPage> createState() => _FruitClassifierPageState();
}

class _FruitClassifierPageState extends State<FruitClassifierPage> {
  File? _image;
  late Interpreter _interpreter;
  
  // Labels définis directement dans le code
  final List<String> _labels = ['apple', 'banana', 'orange'];
  
  String _result = "";
  bool _modelLoaded = false;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    loadModel();
  }
// --- Chargement du Modèle TFLite ---
  Future<void> loadModel() async {
    try {
      _interpreter = await Interpreter.fromAsset("assets/models/fruit_classifier.tflite");

      print("=== Détails du modèle ===");
      print("Input shape: ${_interpreter.getInputTensor(0).shape}");
      print("Output shape: ${_interpreter.getOutputTensor(0).shape}");
      print("Input type: ${_interpreter.getInputTensor(0).type}");
      print("Output type: ${_interpreter.getOutputTensor(0).type}");
      print("Nombre de labels: ${_labels.length}");
      print("Labels: $_labels");

      setState(() {
        _modelLoaded = true;
      });
      
      print("Modèle chargé avec succès.");
    } catch (e) {
      print("Erreur model: $e");
      setState(() {
        _result = "Erreur de chargement du modèle";
      });
    }
  }
// --- Sélection d'Image ---
  Future<void> pickImage() async {
    final picker = ImagePicker();
    final XFile? picked = await picker.pickImage(source: ImageSource.gallery);

    if (picked != null) {
      setState(() {
        _image = File(picked.path);
        _result = "";
        _isProcessing = true;
      });
      await predictImage();
    }
  }
// --- Prédiction de l'Image ---
  Future<void> predictImage() async {
    if (_image == null) return;

    try {
      final bytes = await _image!.readAsBytes();
      
      // Décoder l'image
      img.Image? originalImage = img.decodeImage(bytes);
      if (originalImage == null) {
        throw Exception("Impossible de décoder l'image");
      }

      // Redimensionner à 32x32
      img.Image resizedImage = img.copyResize(originalImage, width: 32, height: 32);

      // Préparer l'input normalisé (1, 32, 32, 3)
      var input = List.generate(
        1,
        (_) => List.generate(
          32,
          (y) => List.generate(
            32,
            (x) {
              var pixel = resizedImage.getPixel(x, y);
              return [
                pixel.r / 255.0,
                pixel.g / 255.0,
                pixel.b / 255.0,
              ];
            },
          ),
        ),
      );

      // Préparer l'output (1, 3)
      var output = List.generate(1, (_) => List.filled(3, 0.0));

      print("Running inference avec image 32x32...");
      _interpreter.run(input, output);
      print("Inference terminée");

      // Afficher TOUTES les valeurs brutes
      print("=== Valeurs brutes de sortie ===");
      for (int i = 0; i < output[0].length; i++) {
        print("${_labels[i]}: ${output[0][i]}");
      }

      // Trouver la classe avec la valeur maximale
      double maxValue = output[0][0];
      int maxIndex = 0;
      
      for (int i = 1; i < output[0].length; i++) {
        if (output[0][i] > maxValue) {
          maxValue = output[0][i];
          maxIndex = i;
        }
      }

      // Calculer la confiance
      double confidence = maxValue * 100;

      setState(() {
        _result = "${_labels[maxIndex]}\nConfiance: ${confidence.toStringAsFixed(2)}%";
        _isProcessing = false;
      });
      
      print("=== Prédiction finale ===");
      print("Classe prédite: ${_labels[maxIndex]}");
      print("Valeur: $maxValue");
      print("Confiance: $confidence%");
      
    } catch (e, stackTrace) {
      print("Erreur prédiction: $e");
      print("StackTrace: $stackTrace");
      setState(() {
        _result = "Erreur: $e";
        _isProcessing = false;
      });
    }
  }
// --- Nettoyage ---
  @override
  void dispose() {
    _interpreter.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Fruit Classifier"),
        backgroundColor: Colors.teal,
        centerTitle: true,
      ),
      body: _modelLoaded
          ? SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 20),
                    Container(
                      width: double.infinity,
                      height: 300,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300, width: 2),
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.grey.shade50,
                      ),
                      child: _image == null
                          ? const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.image, size: 80, color: Colors.grey),
                                  SizedBox(height: 10),
                                  Text(
                                    "Aucune image sélectionnée",
                                    style: TextStyle(color: Colors.grey, fontSize: 16),
                                  ),
                                ],
                              ),
                            )
                          : ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.file(
                                _image!,
                                fit: BoxFit.contain,
                              ),
                            ),
                    ),
                    const SizedBox(height: 30),
                    ElevatedButton.icon(
                      onPressed: _isProcessing ? null : pickImage,
                      icon: const Icon(Icons.photo_library),
                      label: const Text("Choisir une image"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                        textStyle: const TextStyle(fontSize: 18),
                      ),
                    ),
                    const SizedBox(height: 30),
                    if (_isProcessing)
                      const CircularProgressIndicator()
                    else if (_result.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: _result.contains("Erreur") 
                              ? Colors.red.shade50 
                              : Colors.teal.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _result.contains("Erreur") 
                                ? Colors.red.shade200 
                                : Colors.teal.shade200, 
                            width: 2,
                          ),
                        ),
                        child: Column(
                          children: [
                            const Text(
                              "Résultat :",
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              _result,
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: _result.contains("Erreur") 
                                    ? Colors.red 
                                    : Colors.teal,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            )
          : const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 20),
                  Text("Chargement du modèle..."),
                ],
              ),
            ),
    );
  }
}