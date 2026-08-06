import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:veil/export.dart';

class CreatePostScreen extends ConsumerStatefulWidget {
  const CreatePostScreen({super.key});

  @override
  ConsumerState<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends ConsumerState<CreatePostScreen> {
  final _contentController = TextEditingController();
  final _altTextController = TextEditingController();
  final _locationController = TextEditingController();
  final _hashtagController = TextEditingController();
  final _pollQuestionController = TextEditingController();
  final _pollOptionControllers = <TextEditingController>[];
  final _taggedUsersController = TextEditingController();

  List<XFile> _imageFiles = [];
  List<String> _imageUrls = [];
  List<String> _hashtags = [];
  List<String> _mentions = [];
  List<String> _taggedUsers = [];
  bool _isNSFW = false;
  bool _isLoading = false;
  String _audience = 'Public';
  String? _musicAttribution;
  String? _copyrightNotice;

  // For mention suggestions
  List<Map<String, dynamic>> _userSuggestions = [];
  bool _showSuggestions = false;
  int _mentionStartIndex = -1;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _addPollOption();
    _contentController.addListener(_onContentChanged);
  }

  void _onContentChanged() {
    final text = _contentController.text;
    final cursorPos = _contentController.selection.baseOffset;
    final atIndex = text.lastIndexOf('@', cursorPos);
    if (atIndex != -1) {
      final afterAt = text.substring(atIndex + 1, cursorPos);
      if (!afterAt.contains(' ')) {
        _mentionStartIndex = atIndex;
        _fetchUserSuggestions(afterAt);
        setState(() => _showSuggestions = true);
        return;
      }
    }
    setState(() => _showSuggestions = false);
  }

  Future<void> _fetchUserSuggestions(String query) async {
    if (query.length < 2) {
      setState(() => _userSuggestions = []);
      return;
    }
    try {
      final postService = ref.read(postServiceProvider);
      final results = await postService.searchUsers(query);
      setState(() => _userSuggestions = results);
    } catch (e) {
      setState(() => _userSuggestions = []);
    }
  }

  void _insertMention(Map<String, dynamic> user) {
    final username = user['username'] ?? '';
    if (username.isEmpty) return;
    final text = _contentController.text;
    final before = text.substring(0, _mentionStartIndex);
    final after = text.substring(_contentController.selection.baseOffset);
    final newText = '$before@$username $after';
    _contentController.text = newText;
    final newOffset = before.length + username.length + 2;
    _contentController.selection = TextSelection.fromPosition(
      TextPosition(offset: newOffset.toInt()),
    );
    if (!_mentions.contains(username)) {
      setState(() => _mentions.add(username));
    }
    setState(() => _showSuggestions = false);
  }

  void _addPollOption() {
    setState(() {
      _pollOptionControllers.add(TextEditingController());
    });
  }

  void _removePollOption(int index) {
    if (_pollOptionControllers.length > 2) {
      setState(() {
        _pollOptionControllers.removeAt(index);
      });
    }
  }

  Future<void> _pickImages() async {
    final List<XFile>? picked = await _picker.pickMultiImage(
      maxWidth: 1080, // 👈 Add this
      maxHeight: 1080, // 👈 And this
      imageQuality: 80, // 👈 Quality 80% (good balance)
    );
    if (picked != null && picked.isNotEmpty) {
      setState(() => _imageFiles.addAll(picked));
    }
  }

  void _addHashtag(String tag) {
    final clean = tag.trim().replaceAll('#', '');
    if (clean.isNotEmpty && !_hashtags.contains(clean)) {
      setState(() => _hashtags.add(clean));
      _hashtagController.clear();
    }
  }

  void _removeHashtag(String tag) => setState(() => _hashtags.remove(tag));

  void _addTaggedUser(String userId) {
    final clean = userId.trim();
    if (clean.isNotEmpty && !_taggedUsers.contains(clean)) {
      setState(() => _taggedUsers.add(clean));
      _taggedUsersController.clear();
    }
  }

  // =============================================================
  // SUBMIT POST – WITH REAL IMAGE UPLOAD
  // =============================================================
  Future<void> _submitPost() async {
    final content = _contentController.text.trim();
    if (content.isEmpty && _imageFiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add content or an image')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userId = ref.read(authProvider).user?.id;
      if (userId == null) throw Exception('Not logged in');

      // ----- 1. Upload images to Supabase Storage -----
      List<String> uploadedUrls = [];
      if (_imageFiles.isNotEmpty) {
        final supabase = Supabase.instance.client;
        // Check if bucket exists (optional, but helpful)
        try {
          await supabase.storage.from('post_images').list();
        } catch (e) {
          throw Exception(
            'Storage bucket "post_images" does not exist or is not accessible. Please create it in Supabase dashboard.',
          );
        }

        for (final file in _imageFiles) {
          try {
            final timestamp = DateTime.now().millisecondsSinceEpoch;
            final fileName = file.name.isNotEmpty ? file.name : 'image.jpg';
            final path =
                '${userId}_${timestamp}_${fileName.replaceAll(' ', '_')}';
            final fileBytes = await file.readAsBytes();
            await supabase.storage
                .from('post_images')
                .uploadBinary(path, fileBytes);
            final publicUrl = supabase.storage
                .from('post_images')
                .getPublicUrl(path);
            uploadedUrls.add(publicUrl);
            print('✅ Uploaded: $publicUrl');
          } catch (e) {
            print('❌ Failed to upload image: $e');
            // If any image fails, abort the whole post
            throw Exception('Failed to upload image: $e');
          }
        }
      }

      // ----- If images were selected but none uploaded, abort -----
      if (_imageFiles.isNotEmpty && uploadedUrls.isEmpty) {
        throw Exception(
          'No images were uploaded successfully. Please try again.',
        );
      }

      // ----- 2. Build poll (unchanged) -----
      final pollOptions = _pollOptionControllers
          .map((c) => c.text.trim())
          .where((t) => t.isNotEmpty)
          .toList();
      Map<String, dynamic>? pollJson;
      if (_pollQuestionController.text.isNotEmpty && pollOptions.isNotEmpty) {
        pollJson = {
          'question': _pollQuestionController.text,
          'options': pollOptions
              .map((opt) => ({'text': opt, 'votes': 0}))
              .toList(),
          'totalVotes': 0,
          'endsAt': DateTime.now()
              .add(const Duration(days: 7))
              .toIso8601String(),
        };
      }

      // ----- 3. Build final data -----
      final postData = {
        'user_id': userId,
        'content': content,
        'image_urls':
            uploadedUrls, // Now guaranteed to have URLs if images were picked
        'hashtags': _hashtags,
        'mentions': _mentions,
        'tagged_users': _taggedUsers,
        'location': _locationController.text.trim().isEmpty
            ? null
            : _locationController.text.trim(),
        'audience': _audience,
        'alt_text': _altTextController.text.trim().isEmpty
            ? null
            : _altTextController.text.trim(),
        'is_nsfw': _isNSFW,
        'poll': pollJson,
        'music_attribution': _musicAttribution,
        'copyright_notice': _copyrightNotice,
      };

      final postService = ref.read(postServiceProvider);
      await postService.createPostFromMap(postData);

      // Refresh feed & profile
      ref.read(refreshProfileProvider.notifier).state++;
      ref.read(feedProvider.notifier).fetchPosts(refresh: true);
      Navigator.pop(context);
    } catch (e) {
      print('❌ Error: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('❌ Error: $e')));
    } finally {
      setState(() => _isLoading = false);
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
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Create Post',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _submitPost,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Post',
                    style: TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ---- Content ----
                  TextField(
                    controller: _contentController,
                    style: const TextStyle(color: Colors.white),
                    maxLines: 5,
                    decoration: InputDecoration(
                      hintText: 'What\'s on your mind? (@ to mention)',
                      hintStyle: const TextStyle(color: Colors.grey),
                      filled: true,
                      fillColor: Colors.grey[900],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ---- Audience chips ----
                  Wrap(
                    spacing: 8,
                    children: ['Public', 'Friends', 'Private'].map((label) {
                      final isSelected = _audience == label;
                      return ChoiceChip(
                        label: Text(label),
                        selected: isSelected,
                        onSelected: (_) => setState(() => _audience = label),
                        backgroundColor: Colors.grey[800],
                        selectedColor: Colors.blue,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : Colors.grey,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // ---- Alt text ----
                  TextField(
                    controller: _altTextController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Alt text (optional)',
                      hintStyle: const TextStyle(color: Colors.grey),
                      filled: true,
                      fillColor: Colors.grey[900],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ---- Location ----
                  TextField(
                    controller: _locationController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Location (optional)',
                      hintStyle: const TextStyle(color: Colors.grey),
                      prefixIcon: const Icon(
                        Icons.location_on,
                        color: Colors.grey,
                      ),
                      filled: true,
                      fillColor: Colors.grey[900],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ---- Hashtags ----
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _hashtagController,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'Add hashtag (e.g. tech)',
                            hintStyle: const TextStyle(color: Colors.grey),
                            filled: true,
                            fillColor: Colors.grey[900],
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          onSubmitted: _addHashtag,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle, color: Colors.blue),
                        onPressed: () => _addHashtag(_hashtagController.text),
                      ),
                    ],
                  ),
                  Wrap(
                    spacing: 4,
                    children: _hashtags.map((tag) {
                      return Chip(
                        label: Text('#$tag'),
                        onDeleted: () => _removeHashtag(tag),
                        backgroundColor: Colors.blue.withOpacity(0.2),
                        labelStyle: const TextStyle(color: Colors.blue),
                        deleteIcon: const Icon(
                          Icons.close,
                          color: Colors.blue,
                          size: 16,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // ---- Tagged Users ----
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _taggedUsersController,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'Tag user ID (UUID)',
                            hintStyle: const TextStyle(color: Colors.grey),
                            filled: true,
                            fillColor: Colors.grey[900],
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          onSubmitted: _addTaggedUser,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle, color: Colors.blue),
                        onPressed: () =>
                            _addTaggedUser(_taggedUsersController.text),
                      ),
                    ],
                  ),
                  Wrap(
                    spacing: 4,
                    children: _taggedUsers.map((uid) {
                      return Chip(
                        label: Text(uid.substring(0, 8)),
                        onDeleted: () =>
                            setState(() => _taggedUsers.remove(uid)),
                        backgroundColor: Colors.purple.withOpacity(0.2),
                        labelStyle: const TextStyle(color: Colors.purple),
                        deleteIcon: const Icon(
                          Icons.close,
                          color: Colors.purple,
                          size: 16,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // ---- Images ----
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _pickImages,
                          icon: const Icon(
                            Icons.photo_library,
                            color: Colors.white,
                          ),
                          label: const Text('Pick Images'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey[800],
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${_imageFiles.length} selected',
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                  if (_imageFiles.isNotEmpty)
                    SizedBox(
                      height: 80,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _imageFiles.length,
                        itemBuilder: (context, index) {
                          return Stack(
                            children: [
                              Container(
                                width: 80,
                                height: 80,
                                margin: const EdgeInsets.only(right: 8),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  image: DecorationImage(
                                    image: FileImage(
                                      File(_imageFiles[index].path),
                                    ),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 0,
                                right: 8,
                                child: IconButton(
                                  icon: const Icon(
                                    Icons.close,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _imageFiles.removeAt(index);
                                    });
                                  },
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 16),

                  // ---- NSFW ----
                  Row(
                    children: [
                      Switch(
                        value: _isNSFW,
                        onChanged: (val) => setState(() => _isNSFW = val),
                        activeColor: Colors.red,
                      ),
                      const Text(
                        'Mark as NSFW (sensitive content)',
                        style: TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ---- Poll ----
                  const Text(
                    'Poll (optional)',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _pollQuestionController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Poll question',
                      hintStyle: const TextStyle(color: Colors.grey),
                      filled: true,
                      fillColor: Colors.grey[900],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ..._pollOptionControllers.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final ctrl = entry.value;
                    return Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: ctrl,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: 'Option ${idx + 1}',
                              hintStyle: const TextStyle(color: Colors.grey),
                              filled: true,
                              fillColor: Colors.grey[900],
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.remove_circle,
                            color: Colors.red,
                          ),
                          onPressed: () => _removePollOption(idx),
                        ),
                      ],
                    );
                  }),
                  TextButton(
                    onPressed: _addPollOption,
                    child: const Text('Add option'),
                  ),
                  const SizedBox(height: 16),

                  // ---- Music attribution ----
                  TextField(
                    onChanged: (val) => setState(
                      () => _musicAttribution = val.isEmpty ? null : val,
                    ),
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Music attribution (optional)',
                      hintStyle: const TextStyle(color: Colors.grey),
                      filled: true,
                      fillColor: Colors.grey[900],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ---- Copyright ----
                  TextField(
                    onChanged: (val) => setState(
                      () => _copyrightNotice = val.isEmpty ? null : val,
                    ),
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Copyright notice (optional)',
                      hintStyle: const TextStyle(color: Colors.grey),
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
            // ---- Mention suggestions ----
            if (_showSuggestions && _userSuggestions.isNotEmpty)
              Positioned(
                top: 100,
                left: 16,
                right: 16,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[900],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[800]!),
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _userSuggestions.length,
                    itemBuilder: (context, index) {
                      final user = _userSuggestions[index];
                      return ListTile(
                        leading: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.purple, Colors.blue],
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              (user['username'] ?? '')[0].toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        title: Text(
                          user['display_name'] ?? user['username'] ?? '',
                          style: const TextStyle(color: Colors.white),
                        ),
                        subtitle: Text(
                          '@${user['username'] ?? ''}',
                          style: const TextStyle(color: Colors.grey),
                        ),
                        onTap: () => _insertMention(user),
                      );
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
