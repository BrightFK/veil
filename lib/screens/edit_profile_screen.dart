import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:veil/export.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  final String userId;
  const EditProfileScreen({super.key, required this.userId});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _displayNameController = TextEditingController();
  final _bioController = TextEditingController();
  final _websiteController = TextEditingController();

  String? _avatarUrl;
  File? _selectedImage;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final postService = ref.read(postServiceProvider);
      final data = await postService.getProfile(widget.userId);
      _usernameController.text = data['username'] ?? '';
      _displayNameController.text = data['display_name'] ?? '';
      _bioController.text = data['bio'] ?? '';
      _websiteController.text = data['website'] ?? '';
      _avatarUrl = data['avatar_url'];
      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load profile: $e')));
    }
  }

  // ========== REVERTED: Simple image picker (no crop) ==========
  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        _selectedImage = File(picked.path);
      });
    }
  }

  Future<String?> _uploadImage() async {
    if (_selectedImage == null) return _avatarUrl;

    final supabase = Supabase.instance.client;
    final userId = widget.userId;

    try {
      final fileName = '${userId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final fileBytes = await _selectedImage!.readAsBytes();
      final filePath = 'avatars/$fileName';

      await supabase.storage
          .from('avatars')
          .uploadBinary(
            filePath,
            fileBytes,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
          );

      final publicUrl = supabase.storage.from('avatars').getPublicUrl(filePath);
      return publicUrl;
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
      return null;
    }
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final postService = ref.read(postServiceProvider);

      String? newAvatarUrl = _avatarUrl;
      if (_selectedImage != null) {
        final uploaded = await _uploadImage();
        if (uploaded != null) {
          newAvatarUrl = uploaded;
        }
      }

      await postService.updateProfile(
        widget.userId,
        username: _usernameController.text.trim(),
        displayName: _displayNameController.text.trim(),
        bio: _bioController.text.trim(),
        website: _websiteController.text.trim(),
        avatarUrl: newAvatarUrl,
      );

      ref.read(refreshProfileProvider.notifier).state++;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile updated!')));
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Edit Profile',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _saveChanges,
            child: Text(
              _isSaving ? 'Saving...' : 'Save',
              style: TextStyle(
                color: _isSaving ? Colors.grey : Colors.blue,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    // ---- Avatar ----
                    Center(
                      child: Stack(
                        children: [
                          GestureDetector(
                            onTap: _pickImage,
                            child: Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.grey[800],
                                border: Border.all(color: Colors.grey[700]!),
                                image: _selectedImage != null
                                    ? DecorationImage(
                                        image: FileImage(_selectedImage!),
                                        fit: BoxFit.cover,
                                      )
                                    : (_avatarUrl != null
                                          ? DecorationImage(
                                              image: NetworkImage(_avatarUrl!),
                                              fit: BoxFit.cover,
                                            )
                                          : null),
                              ),
                              child:
                                  (_selectedImage == null && _avatarUrl == null)
                                  ? const Icon(
                                      Icons.person,
                                      color: Colors.grey,
                                      size: 50,
                                    )
                                  : null,
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Colors.purple, Colors.blue],
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.camera_alt,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ---- Username ----
                    TextFormField(
                      controller: _usernameController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Display Name',
                        labelStyle: const TextStyle(color: Colors.grey),
                        filled: true,
                        fillColor: Colors.grey[900],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      validator: (v) =>
                          v!.length >= 3 ? null : 'Min 3 characters',
                    ),
                    const SizedBox(height: 16),

                    // ---- Display Name ----
                    TextFormField(
                      controller: _displayNameController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Username',
                        labelStyle: const TextStyle(color: Colors.grey),
                        filled: true,
                        fillColor: Colors.grey[900],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ---- Bio ----
                    TextFormField(
                      controller: _bioController,
                      style: const TextStyle(color: Colors.white),
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'Bio',
                        labelStyle: const TextStyle(color: Colors.grey),
                        filled: true,
                        fillColor: Colors.grey[900],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
    );
  }
}
