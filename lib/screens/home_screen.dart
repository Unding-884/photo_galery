import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/permission_service.dart';
import 'photo_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() =>
      _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final PermissionService _permissionService =
  PermissionService();

  final ImagePicker _picker = ImagePicker();

  List<String> _images = [];

  bool _loading = false;

  bool _selectionMode = false;

  final Set<int> _selectedIndexes = {};

  @override
  void initState() {
    super.initState();
    _loadImages();
  }

  Future<void> _loadImages() async {
    final prefs =
    await SharedPreferences.getInstance();

    setState(() {
      _images =
          prefs.getStringList("images") ?? [];
    });
  }

  Future<void> _saveImages() async {
    final prefs =
    await SharedPreferences.getInstance();

    await prefs.setStringList(
      "images",
      _images,
    );
  }

  Future<void> _pickCamera() async {
    final permission =
    await _permissionService
        .requestCameraPermission();

    if (!permission.isGranted) {
      _handlePermission(permission);
      return;
    }

    final image = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );

    if (image != null) {
      await _processImage(image);
    }
  }

  Future<void> _pickGallery() async {
    final permission =
    await _permissionService
        .requestGalleryPermission();

    if (!permission.isGranted) {
      _handlePermission(permission);
      return;
    }

    final image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );

    if (image != null) {
      await _processImage(image);
    }
  }

  Future<void> _processImage(XFile image) async {
    setState(() {
      _loading = true;
    });

    try {
      final saved = await _saveImage(image.path);

      _images.add(saved);

      await _saveImages();

      setState(() {});
    } catch (e) {
      debugPrint("Error saving image: $e");
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<String> _saveImage(
      String source,
      ) async {
    final dir =
    await getApplicationDocumentsDirectory();

    final photoDir = Directory(
      "${dir.path}/photos",
    );

    if (!await photoDir.exists()) {
      await photoDir.create();
    }

    final fileName =
        "photo_${DateTime.now().millisecondsSinceEpoch}.jpg";

    final path =
        "${photoDir.path}/$fileName";

    await File(source).copy(path);

    return path;
  }

  Future<void> _deletePhoto(
      int index,
      ) async {
    final file = File(_images[index]);

    if (await file.exists()) {
      await file.delete();
    }

    _images.removeAt(index);

    await _saveImages();

    setState(() {});
  }

  Future<void> _deleteSelected() async {
    final indexes =
    _selectedIndexes.toList()
      ..sort((a, b) => b.compareTo(a));

    for (final index in indexes) {
      await _deletePhoto(index);
    }

    _selectedIndexes.clear();

    _selectionMode = false;

    setState(() {});
  }

  void _handlePermission(
      PermissionStatus status,
      ) {
    if (status.isPermanentlyDenied) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title:
          const Text("Permission"),
          content: const Text(
            "Open settings?",
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text("No"),
            ),
            TextButton(
              onPressed: () {
                openAppSettings();
              },
              child: const Text("Yes"),
            ),
          ],
        ),
      );
    }
  }

  void _showSourcePicker() {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(
                Icons.camera_alt,
              ),
              title: const Text(
                "Camera",
              ),
              onTap: () {
                Navigator.pop(context);
                _pickCamera();
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.photo,
              ),
              title: const Text(
                "Gallery",
              ),
              onTap: () {
                Navigator.pop(context);
                _pickGallery();
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.cancel,
              ),
              title: const Text(
                "Cancel",
              ),
              onTap: () {
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment:
        MainAxisAlignment.center,
        children: [
          Icon(
            Icons.photo_library_outlined,
            size: 120,
            color: Colors.grey,
          ),
          SizedBox(height: 16),
          Text(
            "No Photos Yet",
          ),
        ],
      ),
    );
  }

  Widget _grid() {
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _images.length,
      gridDelegate:
      const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemBuilder: (_, index) {
        final selected =
        _selectedIndexes.contains(
          index,
        );

        return GestureDetector(
          onLongPress: () {
            setState(() {
              _selectionMode = true;
              _selectedIndexes.add(index);
            });
          },
          onTap: () {
            if (_selectionMode) {
              setState(() {
                if (selected) {
                  _selectedIndexes
                      .remove(index);
                } else {
                  _selectedIndexes
                      .add(index);
                }

                if (_selectedIndexes
                    .isEmpty) {
                  _selectionMode = false;
                }
              });

              return;
            }

            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    PhotoDetailScreen(
                      imagePath:
                      _images[index],
                      index: index,
                      onDelete: () =>
                          _deletePhoto(
                            index,
                          ),
                    ),
              ),
            );
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              Hero(
                tag: "photo_$index",
                child: ClipRRect(
                  borderRadius:
                  BorderRadius.circular(
                    12,
                  ),
                  child: Image.file(
                    File(
                      _images[index],
                    ),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              if (selected)
                Container(
                  color: Colors.redAccent
                      .withValues(
                    alpha: 0.4,
                  ),
                  child: const Icon(
                    Icons.check_circle,
                    color: Colors.white,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(
      BuildContext context,
      ) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor:
        Colors.redAccent,
        foregroundColor:
        Colors.white,
        title:
        const Text("📷 My Photos"),
        actions: [
          if (_selectionMode)
            IconButton(
              onPressed:
              _deleteSelected,
              icon: const Icon(
                Icons.delete,
              ),
            ),
          IconButton(
            onPressed:
            _showSourcePicker,
            icon: const Icon(
              Icons.add_a_photo,
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(
        child:
        CircularProgressIndicator(
          color:
          Colors.redAccent,
        ),
      )
          : _images.isEmpty
          ? _emptyState()
          : _grid(),
    );
  }
}