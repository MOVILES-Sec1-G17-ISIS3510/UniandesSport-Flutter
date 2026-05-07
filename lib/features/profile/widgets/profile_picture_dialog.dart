import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// Dialog/BottomSheet for selecting the source of the profile picture.
///
/// Presents two options:
/// 1. Take a photo with camera
/// 2. Select a photo from gallery
///
/// Returns:
/// - ImageSource.camera if user chooses camera
/// - ImageSource.gallery if user chooses gallery
/// - null if cancelled
///
/// Dependencies required in pubspec.yaml:
/// - image_picker: ^1.1.2
class ProfilePictureDialog {
  /// Shows a BottomSheet to select image source.
  ///
  /// [context]: current BuildContext
  /// Returns: Future<ImageSource?> with the user's selection
  static Future<ImageSource?> showPictureSourcePicker(
    BuildContext context,
  ) async {
    return showModalBottomSheet<ImageSource?>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // BottomSheet title
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    'Select profile picture',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),

                // Option: Take photo with camera
                ListTile(
                  leading: const Icon(Icons.camera_alt, color: Colors.blue),
                  title: const Text('Take a photo'),
                  subtitle: const Text('Use the device camera'),
                  onTap: () {
                    Navigator.of(context).pop(ImageSource.camera);
                  },
                ),

                // Option: Choose from gallery
                ListTile(
                  leading: const Icon(Icons.image, color: Colors.green),
                  title: const Text('Choose from gallery'),
                  subtitle: const Text('Select from the photo gallery'),
                  onTap: () {
                    Navigator.of(context).pop(ImageSource.gallery);
                  },
                ),

                // Option: Cancel
                ListTile(
                  leading: const Icon(Icons.close, color: Colors.grey),
                  title: const Text('Cancel'),
                  onTap: () {
                    Navigator.of(context).pop(null);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Shows an alternative AlertDialog to select the source.
  ///
  /// Uses a traditional dialog instead of a BottomSheet.
  /// Useful for platforms where BottomSheet is not ideal.
  ///
  /// [context]: current BuildContext
  /// Returns: Future<ImageSource?> with the user's selection
  static Future<ImageSource?> showPictureSourceDialog(
    BuildContext context,
  ) async {
    return showDialog<ImageSource?>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Change profile picture'),
          content: const Text('Where do you want to get the image from?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(null);
              },
              child: const Text('Cancel'),
            ),
            TextButton.icon(
              onPressed: () {
                Navigator.of(context).pop(ImageSource.camera);
              },
              icon: const Icon(Icons.camera_alt),
              label: const Text('Camera'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pop(ImageSource.gallery);
              },
              icon: const Icon(Icons.image),
              label: const Text('Gallery'),
            ),
          ],
        );
      },
    );
  }
}
