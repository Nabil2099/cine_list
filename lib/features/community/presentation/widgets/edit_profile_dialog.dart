import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/models/user_profile_model.dart';
import 'user_avatar_widget.dart';

class ProfileEditResult {
  const ProfileEditResult({
    required this.displayName,
    required this.bio,
    required this.avatarKey,
    this.photoBase64,
    this.clearPhoto = false,
  });

  final String displayName;
  final String bio;
  final String avatarKey;
  final String? photoBase64;
  final bool clearPhoto;
}

/// Dialog allowing the user to customize their display name, bio, and avatar.
class EditProfileDialog extends StatefulWidget {
  const EditProfileDialog({super.key, required this.initialProfile});

  final UserProfileModel initialProfile;

  static Future<ProfileEditResult?> show(
    BuildContext context, {
    required UserProfileModel initialProfile,
  }) {
    return showDialog<ProfileEditResult>(
      context: context,
      builder: (_) => EditProfileDialog(initialProfile: initialProfile),
    );
  }

  @override
  State<EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<EditProfileDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _bioController;
  late String _selectedAvatar;
  String? _photoBase64;
  bool _clearPhoto = false;
  bool _pickingImage = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.initialProfile.displayName,
    );
    _bioController = TextEditingController(text: widget.initialProfile.bio);
    _selectedAvatar = widget.initialProfile.avatarKey;
    _photoBase64 = widget.initialProfile.photoBase64;
  }

  Future<void> _pickPhoto() async {
    if (_pickingImage) return;
    setState(() => _pickingImage = true);
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 256,
        maxHeight: 256,
        imageQuality: 65,
      );
      if (picked != null && mounted) {
        final bytes = await picked.readAsBytes();
        if (bytes.lengthInBytes > 280000) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Please choose a smaller image (under 280 KB).'),
              ),
            );
          }
          return;
        }
        setState(() {
          _photoBase64 = base64Encode(bytes);
          _clearPhoto = false;
        });
      }
    } on MissingPluginException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Image picker requires a full app rebuild (stop & run flutter run).',
            ),
          ),
        );
      }
    } on PlatformException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.code == 'photo_access_denied'
                  ? 'Photo library permission denied.'
                  : 'Could not pick image: ${e.message ?? e.code}',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not pick image: $e')));
      }
    } finally {
      if (mounted) setState(() => _pickingImage = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(
        'Edit Profile',
        style: TextStyle(color: AppColors.khakiBeige),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                UserAvatar(
                  avatarKey: _selectedAvatar,
                  photoBase64: _photoBase64,
                  radius: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _pickingImage ? null : _pickPhoto,
                        icon: const Icon(Icons.photo_camera_outlined, size: 16),
                        label: Text(
                          _pickingImage ? 'Loading...' : 'Upload Photo',
                        ),
                      ),
                      if (_photoBase64 != null && _photoBase64!.isNotEmpty)
                        TextButton(
                          onPressed: () => setState(() {
                            _photoBase64 = null;
                            _clearPhoto = true;
                          }),
                          child: const Text(
                            'Remove',
                            style: TextStyle(color: AppColors.error),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Text(
              'Or Choose Preset Avatar',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: AvatarPreset.presets.map((preset) {
                final selected = preset.key == _selectedAvatar;
                return GestureDetector(
                  onTap: () => setState(() => _selectedAvatar = preset.key),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: preset.color.withValues(
                            alpha: selected ? 0.32 : 0.14,
                          ),
                          border: Border.all(
                            color: selected
                                ? AppColors.pacificBlue
                                : preset.color.withValues(alpha: 0.4),
                            width: selected ? 2.2 : 1,
                          ),
                        ),
                        child: Icon(preset.icon, color: preset.color, size: 22),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        preset.label,
                        style: TextStyle(
                          color: selected
                              ? AppColors.pacificBlue
                              : AppColors.textMuted,
                          fontSize: 10.5,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              maxLength: 32,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Display Name',
                hintText: 'Your name in Community',
                counterText: '',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _bioController,
              maxLines: 3,
              maxLength: 160,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Bio',
                hintText: 'Tell others your favorite genres or films...',
                counterStyle: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.pacificBlue,
            foregroundColor: AppColors.black,
          ),
          onPressed: () {
            Navigator.of(context).pop(
              ProfileEditResult(
                displayName: _nameController.text.trim(),
                bio: _bioController.text.trim(),
                avatarKey: _selectedAvatar,
                photoBase64: _photoBase64,
                clearPhoto: _clearPhoto,
              ),
            );
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
