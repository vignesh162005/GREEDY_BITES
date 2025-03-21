import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:logger/logger.dart';
import 'dart:io';
import '../services/user_service.dart';
import '../models/user_model.dart';
import 'package:firebase_storage/firebase_storage.dart';

class CompleteProfilePage extends StatefulWidget {
  final UserModel? initialData;
  final bool isNewUser;

  const CompleteProfilePage({
    super.key,
    this.initialData,
    this.isNewUser = false,
  });

  @override
  State<CompleteProfilePage> createState() => _CompleteProfilePageState();
}

class _CompleteProfilePageState extends State<CompleteProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  File? _imageFile;
  bool _isLoading = false;
  String? _imageUrl;
  
  // Initialize logger
  final _logger = Logger();

  @override
  void initState() {
    super.initState();
    _logger.i('Initializing CompleteProfilePage');
    try {
      if (widget.initialData != null) {
        _logger.d('Setting up form with initial data');
        _nameController.text = widget.initialData!.name;
        _emailController.text = widget.initialData!.email;
        _phoneController.text = widget.initialData!.phoneNumber ?? '';
        _addressController.text = widget.initialData!.address ?? '';
        _imageUrl = widget.initialData!.profileImageUrl;
      } else {
        _logger.d('Setting up form with Firebase user data');
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          _nameController.text = user.displayName ?? '';
          _emailController.text = user.email ?? '';
          _imageUrl = user.photoURL;
        }
      }
    } catch (e, stackTrace) {
      _logger.e('Error in initState: $e\nStackTrace: $stackTrace');
    }
  }

  @override
  void dispose() {
    _logger.d('Disposing CompleteProfilePage');
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    _logger.i('Attempting to pick image');
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 75,
      );

      if (pickedFile != null) {
        _logger.d('Image picked successfully: ${pickedFile.path}');
        setState(() {
          _imageFile = File(pickedFile.path);
        });
      } else {
        _logger.d('Image picking cancelled by user');
      }
    } catch (e, stackTrace) {
      _logger.e('Error picking image: $e\nStackTrace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e')),
        );
      }
    }
  }

  Future<String?> _uploadImage() async {
    if (_imageFile == null) return null;
    _logger.i('Attempting to upload image');

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _logger.w('No user found when trying to upload image');
        return null;
      }

      _logger.d('Uploading image to Firebase Storage');
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('user_profiles')
          .child('${user.uid}.jpg');

      await storageRef.putFile(_imageFile!);
      final downloadUrl = await storageRef.getDownloadURL();
      _logger.d('Image uploaded successfully: $downloadUrl');
      return downloadUrl;
    } catch (e, stackTrace) {
      _logger.e('Error uploading image: $e\nStackTrace: $stackTrace');
      return null;
    }
  }

  Future<void> _saveProfile() async {
    _logger.i('Attempting to save profile');
    if (!_formKey.currentState!.validate()) {
      _logger.w('Form validation failed');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _logger.e('No user found when trying to save profile');
        throw Exception('User not found');
      }

      _logger.d('Processing profile image');
      String? profileImageUrl = _imageUrl;
      if (_imageFile != null) {
        profileImageUrl = await _uploadImage();
        _logger.d('New profile image URL: $profileImageUrl');
      }

      // Merge existing metadata with updates
      _logger.d('Preparing user data for update');
      final metadata = {
        ...widget.initialData?.metadata ?? {},
        'updatedAt': DateTime.now().toIso8601String(),
        'lastUpdatedBy': 'user',
      };

      final userData = UserModel(
        id: user.uid,
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        username: _emailController.text.split('@')[0],
        phoneNumber: _phoneController.text.trim(),
        address: _addressController.text.trim(),
        profileImageUrl: profileImageUrl,
        createdAt: widget.initialData?.createdAt ?? DateTime.now(),
        lastLoginAt: DateTime.now(),
        isEmailVerified: user.emailVerified,
        metadata: metadata,
      );

      _logger.d('Updating user data in Firestore');
      await UserService.updateUser(userData);

      _logger.d('Updating Firebase Auth user profile');
      try {
        // Update Firebase Auth user profile using updateProfile method
        await user.updateProfile(
          displayName: _nameController.text.trim(),
          photoURL: profileImageUrl,
        );
        
        // Reload user to ensure we have the latest data
        await user.reload();
      } catch (e, stackTrace) {
        _logger.e('Error updating Firebase Auth profile: $e\nStackTrace: $stackTrace');
        // Continue execution as Firestore update was successful
      }

      _logger.i('Profile updated successfully');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
        
        if (widget.isNewUser) {
          _logger.d('Navigating new user to home page');
          Navigator.of(context).pushReplacementNamed('/home');
        } else {
          _logger.d('Returning to previous screen');
          Navigator.pop(context, true);
        }
      }
    } catch (e, stackTrace) {
      _logger.e('Error updating profile: $e\nStackTrace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating profile: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isNewUser ? 'Complete Your Profile' : 'Edit Profile'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Profile Image
              GestureDetector(
                onTap: _pickImage,
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 60,
                      backgroundImage: _imageFile != null
                          ? FileImage(_imageFile!)
                          : _imageUrl != null
                              ? NetworkImage(_imageUrl!)
                              : null,
                      child: _imageFile == null && _imageUrl == null
                          ? Text(
                              _nameController.text.isNotEmpty
                                  ? _nameController.text[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(fontSize: 40),
                            )
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Theme.of(context).primaryColor,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Full Name
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your name';
                  }
                  if (value.trim().length < 2) {
                    return 'Name must be at least 2 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Email
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                ),
                enabled: false, // Email cannot be changed
              ),
              const SizedBox(height: 16),

              // Phone Number
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone),
                ),
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your phone number';
                  }
                  if (!RegExp(r'^\+?[\d\s-]+$').hasMatch(value)) {
                    return 'Please enter a valid phone number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Address
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(
                  labelText: 'Address',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.location_on),
                ),
                maxLines: 3,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your address';
                  }
                  if (value.trim().length < 10) {
                    return 'Please enter a complete address';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Save Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveProfile,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save Profile'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 