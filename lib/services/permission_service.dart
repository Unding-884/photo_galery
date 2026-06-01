import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  Future<PermissionStatus> requestCameraPermission() async {
    final status = await Permission.camera.status;

    if (status.isGranted) {
      return status;
    }

    if (status.isDenied) {
      return await Permission.camera.request();
    }

    return status;
  }

  Future<PermissionStatus> requestGalleryPermission() async {
    final status = await Permission.photos.status;

    if (status.isGranted || status.isLimited) {
      return PermissionStatus.granted;
    }

    if (status.isDenied) {
      return await Permission.photos.request();
    }

    return status;
  }
}