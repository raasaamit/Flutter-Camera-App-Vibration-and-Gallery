import 'dart:io';
import 'package:camera/camera.dart';
import 'package:camera_app/screens/gallery_screen.dart';
import 'package:flutter/material.dart';
import 'package:vibration/vibration.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:gallery_saver/gallery_saver.dart';

class CameraScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  const CameraScreen({
    Key? key,
    required this.cameras,
  }) : super(key: key);

  @override
  _CameraScreenState createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;
  int selectedCamera = 0;
  List<File> capturedImages = [];

  @override
  void initState() {
    super.initState();
    initializeCamera(selectedCamera);
  }

  void initializeCamera(int cameraIndex) {
    try {
      _controller = CameraController(
        widget.cameras[cameraIndex],
        ResolutionPreset.medium,
      );

      _initializeControllerFuture = _controller.initialize().then((_) {
        if (!mounted) return;
        setState(() {});
      }).catchError((error) {
        print('Error initializing camera: $error');
      });
    } catch (e) {
      print('Error creating camera controller: $e');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<String> _getStoragePath() async {
    final Directory extDir = await getApplicationDocumentsDirectory();
    final String dirPath = '${extDir.path}/Pictures/CameraApp';
    await Directory(dirPath).create(recursive: true);
    return dirPath;
  }

  void _onCaptureButtonPressed() async {
    try {
      await _initializeControllerFuture;
      final XFile xFile = await _controller.takePicture();

      // Save the image to the gallery
      await GallerySaver.saveImage(xFile.path, albumName: "Camera App");

      // Read the image as bytes and save it in a new location if needed
      final String dirPath = await _getStoragePath();
      final String fileName = 'IMG_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final String filePath = path.join(dirPath, fileName);
      final File newImage = File(filePath);
      await newImage.writeAsBytes(await xFile.readAsBytes());

      setState(() {
        capturedImages.add(newImage);
      });

      if (await Vibration.hasVibrator() ?? false) {
        Vibration.vibrate(duration: 100);
      }

      // Optionally, you can delete the temporary file created by takePicture()
      await File(xFile.path).delete();

    } catch (e) {
      print('Error taking picture: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to capture image')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          FutureBuilder<void>(
            future: _initializeControllerFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.done) {
                return CameraPreview(_controller);
              } else {
                return Center(
                  child: CircularProgressIndicator(),
                );
              }
            },
          ),
          Spacer(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Camera switch button
                IconButton(
                  onPressed: () {
                    if (widget.cameras.length > 1) {
                      setState(() {
                        selectedCamera = selectedCamera == 0 ? 1 : 0;
                        initializeCamera(selectedCamera);
                      });
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('No secondary camera found'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                  icon: Icon(
                    Icons.switch_camera_rounded,
                    color: Colors.white,
                  ),
                ),
                // Capture button
                GestureDetector(
                  onTap: _onCaptureButtonPressed,
                  child: Container(
                    height: 60,
                    width: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                    ),
                  ),
                ),
                // Gallery button
                GestureDetector(
                  onTap: () {
                    if (capturedImages.isEmpty) return;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => GalleryScreen(
                          images: capturedImages.reversed.toList(),
                        ),
                      ),
                    );
                  },
                  child: Container(
                    height: 60,
                    width: 60,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white),
                      image: capturedImages.isNotEmpty
                          ? DecorationImage(
                        image: FileImage(capturedImages.last),
                        fit: BoxFit.cover,
                      )
                          : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Spacer(),
        ],
      ),
    );
  }
}
