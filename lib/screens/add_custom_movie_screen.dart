import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../utils/snackbar_utils.dart';

class AddCustomMovieScreen extends StatefulWidget {
  const AddCustomMovieScreen({super.key});

  @override
  State<AddCustomMovieScreen> createState() => _AddCustomMovieScreenState();
}

class _AddCustomMovieScreenState extends State<AddCustomMovieScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firestoreService = FirestoreService();

  final _titleController = TextEditingController();
  final _yearController = TextEditingController();
  final _overviewController = TextEditingController();

  String _mediaType = 'movie'; // Default selection
  String? _base64Poster;
  bool _isSaving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _yearController.dispose();
    _overviewController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    try {
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 500,
        imageQuality: 70,
      );

      if (pickedFile == null) return;

      final bytes = await pickedFile.readAsBytes();
      setState(() {
        _base64Poster = base64Encode(bytes);
      });
    } catch (e) {
      if (mounted) {
        SnackbarUtils.showError(context, 'Failed to pick image: $e');
      }
    }
  }

  void _removeImage() {
    setState(() {
      _base64Poster = null;
    });
  }

  Future<void> _selectYear(BuildContext context) async {
    final DateTime now = DateTime.now();
    
    // Parse current value if exists to set initial selection
    final int currentYear = int.tryParse(_yearController.text) ?? now.year;
    final DateTime initialDate = DateTime(currentYear);

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select Year'),
          content: SizedBox(
            width: 300,
            height: 300,
            child: YearPicker(
              firstDate: DateTime(1800),
              lastDate: now, // Only current year and previous years
              selectedDate: initialDate,
              onChanged: (DateTime dateTime) {
                setState(() {
                  _yearController.text = dateTime.year.toString();
                });
                Navigator.pop(context);
              },
            ),
          ),
        );
      },
    );
  }

  Future<void> _saveCustomMovie() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = Provider.of<AuthService>(context, listen: false);
    final user = auth.currentUser;

    if (user == null) {
      SnackbarUtils.showError(context, 'You must be logged in to add a custom title.');
      return;
    }

    setState(() => _isSaving = true);

    try {
      // Release date can just be year-01-01 or just the year string
      final releaseYear = _yearController.text.trim();
      final releaseDate = releaseYear.isNotEmpty ? '$releaseYear-01-01' : null;

      await _firestoreService.addCustomMovie(
        user.uid,
        title: _titleController.text.trim(),
        type: _mediaType,
        releaseDate: releaseDate,
        overview: _overviewController.text.trim().isNotEmpty 
            ? _overviewController.text.trim() 
            : null,
        base64Poster: _base64Poster,
      );

      if (mounted) {
        SnackbarUtils.showSuccess(context, 'Custom title added successfully!');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        SnackbarUtils.showError(context, e);
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Custom Title'),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Media Type Selector using SegmentedButton
                Text(
                  'Media Type',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: 'movie',
                      label: Text('Movie'),
                      icon: Icon(Icons.movie_outlined),
                    ),
                    ButtonSegment(
                      value: 'tv',
                      label: Text('TV Series'),
                      icon: Icon(Icons.tv_outlined),
                    ),
                  ],
                  selected: {_mediaType},
                  onSelectionChanged: (newSelection) {
                    setState(() {
                      _mediaType = newSelection.first;
                    });
                  },
                  style: SegmentedButton.styleFrom(
                    selectedBackgroundColor: colorScheme.primaryContainer,
                    selectedForegroundColor: colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 24),

                // Poster Image Picker
                Text(
                  'Poster Image (Optional)',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: _base64Poster == null
                      ? InkWell(
                          onTap: _pickImage,
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            width: 150,
                            height: 220,
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: colorScheme.outlineVariant,
                                style: BorderStyle.solid,
                                width: 2,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.1),
                            ),
                            child: const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_photo_alternate_outlined, size: 48),
                                SizedBox(height: 12),
                                Text(
                                  'Choose Poster',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          ),
                        )
                      : Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Image.memory(
                                base64Decode(_base64Poster!),
                                width: 150,
                                height: 220,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.7),
                                  shape: BoxShape.circle,
                                ),
                                child: IconButton(
                                  icon: const Icon(Icons.close, color: Colors.white, size: 18),
                                  onPressed: _removeImage,
                                  constraints: const BoxConstraints(),
                                  padding: const EdgeInsets.all(6),
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
                const SizedBox(height: 24),

                // Title Input
                TextFormField(
                  controller: _titleController,
                  decoration: InputDecoration(
                    labelText: 'Title',
                    hintText: 'e.g., Money Heist',
                    prefixIcon: const Icon(Icons.title),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  textCapitalization: TextCapitalization.words,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a title';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Release Year Input
                TextFormField(
                  controller: _yearController,
                  readOnly: true, // Prevents keyboard input
                  onTap: () => _selectYear(context),
                  decoration: InputDecoration(
                    labelText: 'Release Year (Optional)',
                    hintText: 'Select Year',
                    prefixIcon: const Icon(Icons.calendar_today),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (value) {
                    if (value != null && value.isNotEmpty) {
                      final year = int.tryParse(value);
                      if (year == null || year < 1800 || year > DateTime.now().year) {
                        return 'Please select a valid year';
                      }
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Description/Overview Input
                TextFormField(
                  controller: _overviewController,
                  decoration: InputDecoration(
                    labelText: 'Description (Optional)',
                    hintText: 'Enter a short summary of the movie or series...',
                    prefixIcon: const Icon(Icons.description_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: 32),

                // Save Button
                FilledButton(
                  onPressed: _isSaving ? null : _saveCustomMovie,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Save Title',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
