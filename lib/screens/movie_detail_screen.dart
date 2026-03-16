import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:animate_do/animate_do.dart';
import '../models/movie.dart';
import '../models/video_edit.dart';
import '../services/auth_service.dart';
import '../services/tmdb_service.dart';
import '../providers/user_data_provider.dart';
import '../utils/snackbar_utils.dart';
import 'video_player_screen.dart';

class MovieDetailScreen extends StatefulWidget {
  final Movie movie;

  const MovieDetailScreen({super.key, required this.movie});

  @override
  State<MovieDetailScreen> createState() => _MovieDetailScreenState();
}

class _MovieDetailScreenState extends State<MovieDetailScreen> {
  bool _isOverviewExpanded = false;
  int? _seasonCount;
  final TmdbService _tmdbService = TmdbService();

  @override
  void initState() {
    super.initState();
    _fetchSeasonCount();
  }

  Future<void> _fetchSeasonCount() async {
    final type = widget.movie.type;
    if (type == 'tv' || type == 'series') {
      final count = await _tmdbService.getTvSeasonCount(widget.movie.id);
      if (mounted && count != null) {
        setState(() => _seasonCount = count);
      }
    }
  }

  Future<void> _promptLogin() async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Login Required'),
        content: const Text(
          'You need to be logged in to perform this action.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _guardedAction(AuthService auth, VoidCallback action) {
    if (auth.currentUser != null) {
      action();
    } else {
      _promptLogin();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Consumer2<AuthService, UserDataProvider>(
          builder: (context, authService, userDataProvider, _) {
            final user = authService.currentUser;
            final isFavorite =
                userDataProvider.favoriteIds.contains(widget.movie.uniqueId) ||
                userDataProvider.favoriteIds.contains(widget.movie.id);
            final isWatched =
                userDataProvider.watchedIds.contains(widget.movie.uniqueId) ||
                userDataProvider.watchedIds.contains(widget.movie.id);

            return Column(
              children: [
                // Fixed Header (Hero Image + Title)
                Flexible(
                  flex: 0,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.45,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FadeIn(
                          duration: const Duration(milliseconds: 600),
                          child: Flexible(child: _buildHeroSection()),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: FadeInLeft(
                              duration: const Duration(milliseconds: 600),
                              delay: const Duration(milliseconds: 200),
                              child: Text(
                                widget.movie.title,
                                style: Theme.of(context).textTheme.headlineSmall
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Scrollable content (Metadata, Overview, Chips)
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Metadata Row
                        FadeIn(
                          duration: const Duration(milliseconds: 600),
                          delay: const Duration(milliseconds: 400),
                          child: _buildMetadataRow(),
                        ),
                        const SizedBox(height: 16),

                        // Overview with See More
                        FadeIn(
                          duration: const Duration(milliseconds: 600),
                          delay: const Duration(milliseconds: 600),
                          child: _buildOverview(),
                        ),
                        const SizedBox(height: 24),

                        // Status chips
                        if (isFavorite || isWatched)
                          Wrap(
                            spacing: 8,
                            children: [
                              if (isFavorite)
                                const Chip(
                                  avatar: Icon(
                                    Icons.favorite,
                                    color: Colors.red,
                                    size: 18,
                                  ),
                                  label: Text('In Favorites'),
                                ),
                              if (isWatched)
                                const Chip(
                                  avatar: Icon(
                                    Icons.visibility,
                                    color: Colors.green,
                                    size: 18,
                                  ),
                                  label: Text('Watched'),
                                ),
                            ],
                          ),

                        // Video Collection Section
                        if (user != null)
                          _buildVideoSection(user.uid, userDataProvider),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),

                // Bottom Action Bar
                _buildBottomBar(
                  authService: authService,
                  userDataProvider: userDataProvider,
                  user: user,
                  isFavorite: isFavorite,
                  isWatched: isWatched,
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeroSection() {
    return Consumer2<AuthService, UserDataProvider>(
      builder: (context, auth, userData, _) {
        final customPoster = userData.customPosters[widget.movie.uniqueId];
        final hasTmdbImage =
            widget.movie.backdropPath != null ||
            widget.movie.posterPath != null;
        final imagePath =
            customPoster ??
            widget.movie.backdropPath ??
            widget.movie.posterPath;

        return Stack(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
              child: Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxHeight: 320),
                child: imagePath != null
                    ? _buildImage(imagePath)
                    : GestureDetector(
                        onTap: () {
                          if (auth.currentUser != null) {
                            _pickAndUploadPoster(
                              auth.currentUser!.uid,
                              userData,
                            );
                          } else {
                            _promptLogin();
                          }
                        },
                        child: Container(
                          color: Colors.grey[900],
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.add_photo_alternate_outlined,
                                  size: 60,
                                  color: Colors.white38,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Tap to add poster',
                                  style: TextStyle(
                                    color: Colors.white38,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
              ),
            ),
            Positioned(
              top: 8,
              left: 12,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
            // Show remove button if custom poster is uploaded
            if (customPoster != null && !hasTmdbImage)
              Positioned(
                top: 8,
                right: 12,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(
                      Icons.delete_outline,
                      color: Colors.redAccent,
                    ),
                    onPressed: () {
                      if (auth.currentUser != null) {
                        userData.removeCustomPoster(
                          auth.currentUser!.uid,
                          widget.movie,
                        );
                      }
                    },
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildMetadataRow() {
    final movie = widget.movie;
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (movie.releaseYear != null)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
              const SizedBox(width: 4),
              Text(
                movie.releaseYear!,
                style: const TextStyle(color: Colors.grey, fontSize: 14),
              ),
            ],
          ),
        if (movie.voteAverage > 0)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.star, size: 16, color: Colors.amber),
              const SizedBox(width: 4),
              Text(
                '${movie.voteAverage.toStringAsFixed(1)} / 10',
                style: const TextStyle(color: Colors.grey, fontSize: 14),
              ),
            ],
          ),
        if (_seasonCount != null)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.tv, size: 16, color: Colors.grey),
              const SizedBox(width: 4),
              Text(
                '$_seasonCount Season${_seasonCount! > 1 ? 's' : ''}',
                style: const TextStyle(color: Colors.grey, fontSize: 14),
              ),
            ],
          ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            movie.type.toUpperCase(),
            style: TextStyle(
              color: Theme.of(context).colorScheme.onPrimaryContainer,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOverview() {
    final overview = widget.movie.overview;

    if (overview == null || overview.isEmpty) {
      return const Text(
        'No overview available for this title.',
        style: TextStyle(color: Colors.grey),
      );
    }

    const textStyle = TextStyle(fontSize: 15, height: 1.5);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Overview',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final textSpan = TextSpan(text: overview, style: textStyle);
            final textPainter = TextPainter(
              text: textSpan,
              maxLines: 2,
              textDirection: TextDirection.ltr,
            )..layout(maxWidth: constraints.maxWidth);

            final exceedsMaxLines = textPainter.didExceedMaxLines;

            if (!exceedsMaxLines) {
              // Text fits in 2 lines — just show it
              return Text(overview, style: textStyle);
            }

            // Text overflows — show expandable
            return AnimatedCrossFade(
              duration: const Duration(milliseconds: 200),
              crossFadeState: _isOverviewExpanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              firstChild: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    overview,
                    style: textStyle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _isOverviewExpanded = true),
                    child: const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Text(
                        '...see more',
                        style: TextStyle(
                          color: Colors.deepPurpleAccent,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              secondChild: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(overview, style: textStyle),
                  GestureDetector(
                    onTap: () => setState(() => _isOverviewExpanded = false),
                    child: const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Text(
                        'show less',
                        style: TextStyle(
                          color: Colors.deepPurpleAccent,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildVideoSection(String uid, UserDataProvider userData) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'My Edits & Videos',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            IconButton(
              onPressed: userData.isUploadingVideo
                  ? null
                  : () => _pickAndUploadVideo(uid, userData),
              icon: ZoomIn(child: const Icon(Icons.video_call, size: 28)),
              tooltip: 'Upload Video',
            ),
          ],
        ),
        // Upload progress indicator
        if (userData.isUploadingVideo)
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LinearProgressIndicator(
                  value: userData.videoUploadProgress,
                  backgroundColor: Colors.white12,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 4),
                Text(
                  'Uploading... ${(userData.videoUploadProgress * 100).toInt()}%',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),
        const SizedBox(height: 8),
        StreamBuilder<QuerySnapshot>(
          stream: userData.firestoreService.getVideoCollection(
            uid,
            widget.movie.uniqueId,
          ),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 100,
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              );
            }

            if (snapshot.hasError) {
              return const Text(
                'Could not load videos.',
                style: TextStyle(color: Colors.white38),
              );
            }

            final docs = snapshot.data?.docs ?? [];

            if (docs.isEmpty) {
              return Container(
                height: 100,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Text(
                    'No videos uploaded yet.\nTap the video icon above to add one!',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white38, fontSize: 13),
                  ),
                ),
              );
            }

            final videos = docs
                .map(
                  (doc) => VideoEdit.fromFirestore(
                    doc.data() as Map<String, dynamic>,
                    doc.id,
                  ),
                )
                .toList();

            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: videos.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final video = videos[index];
                return FadeInUp(
                  duration: const Duration(milliseconds: 500),
                  delay: Duration(milliseconds: 100 * index),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      leading: Icon(
                        Icons.play_circle_fill,
                        size: 36,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      title: Text(
                        video.title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      trailing: IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.redAccent,
                        ),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Delete Video'),
                              content: Text(
                                'Remove "${video.title}" from your collection?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  child: const Text('Cancel'),
                                ),
                                FilledButton(
                                  onPressed: () {
                                    Navigator.pop(ctx);
                                    userData.deleteVideo(
                                      uid,
                                      widget.movie,
                                      video.id,
                                      video.videoUrl,
                                    );
                                  },
                                  style: FilledButton.styleFrom(
                                    backgroundColor: Colors.red,
                                  ),
                                  child: const Text('Delete'),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => VideoPlayerScreen(
                              videoUrl: video.videoUrl,
                              title: video.title,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  Future<void> _pickAndUploadVideo(
    String uid,
    UserDataProvider userData,
  ) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickVideo(source: ImageSource.gallery);

    if (pickedFile == null || !mounted) return;

    // Show a dialog to name the video
    final titleController = TextEditingController(
      text: 'Edit ${DateTime.now().millisecondsSinceEpoch % 1000}',
    );

    final title = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Name this video'),
        content: TextField(
          controller: titleController,
          decoration: const InputDecoration(hintText: 'Enter a title'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, titleController.text.trim()),
            child: const Text('Upload'),
          ),
        ],
      ),
    );

    if (title == null || title.isEmpty || !mounted) return;

    final videoFile = File(pickedFile.path);

    // Show real-time progress snackbar
    if (mounted) {
      SnackbarUtils.showLoadingWithProgress(
        context,
        'Uploading "${title.length > 20 ? '${title.substring(0, 17)}...' : title}"',
        userData.uploadProgressStream,
      );
    }

    final success = await userData.uploadVideo(
      uid,
      widget.movie,
      videoFile,
      title,
    );

    if (mounted) {
      SnackbarUtils.hide(context);
      if (success) {
        SnackbarUtils.showSuccess(context, 'Video uploaded successfully!');
      } else {
        SnackbarUtils.showError(context, 'Failed to upload video.');
      }
    }
  }

  Widget _buildBottomBar({
    required AuthService authService,
    required UserDataProvider userDataProvider,
    required dynamic user,
    required bool isFavorite,
    required bool isWatched,
  }) {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.2),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: FilledButton.icon(
              onPressed: () {
                _guardedAction(authService, () {
                  userDataProvider.toggleFavorite(user!.uid, widget.movie);
                });
              },
              icon: Icon(
                isFavorite ? Icons.favorite : Icons.favorite_border,
                color: isFavorite ? Colors.red : null,
              ),
              label: Text(
                isFavorite ? 'Remove from Favorites' : 'Add to Favorites',
              ),
              style: FilledButton.styleFrom(
                backgroundColor: isFavorite
                    ? Theme.of(context).colorScheme.errorContainer
                    : Theme.of(context).colorScheme.primaryContainer,
                foregroundColor: isFavorite
                    ? Theme.of(context).colorScheme.onErrorContainer
                    : Theme.of(context).colorScheme.onPrimaryContainer,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              onSelected: (value) {
                if (value == 'watched') {
                  _guardedAction(authService, () {
                    userDataProvider.toggleWatched(user!.uid, widget.movie);
                  });
                } else if (value == 'add_to_list') {
                  _guardedAction(authService, () {
                    _showAddToListBottomSheet(
                      context,
                      userDataProvider,
                      user!.uid,
                      widget.movie,
                    );
                  });
                } else if (value == 'upload_poster') {
                  _guardedAction(authService, () {
                    _pickAndUploadPoster(user!.uid, userDataProvider);
                  });
                } else if (value == 'remove_poster') {
                  _guardedAction(authService, () {
                    userDataProvider.removeCustomPoster(
                      user!.uid,
                      widget.movie,
                    );
                  });
                }
              },
              itemBuilder: (context) {
                return [
                  PopupMenuItem<String>(
                    value: 'watched',
                    child: Row(
                      children: [
                        Icon(
                          isWatched ? Icons.visibility : Icons.visibility_off,
                          color: isWatched ? Colors.green : null,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          isWatched ? 'Remove from Watched' : 'Already Watched',
                        ),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem<String>(
                    value: 'add_to_list',
                    child: Row(
                      children: [
                        Icon(Icons.playlist_add),
                        SizedBox(width: 12),
                        Text('Add to list...'),
                      ],
                    ),
                  ),
                ];
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickAndUploadPoster(
    String uid,
    UserDataProvider userDataProvider,
  ) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 500,
      imageQuality: 70,
    );

    if (pickedFile == null) return;

    final bytes = await pickedFile.readAsBytes();
    final base64Image = base64Encode(bytes);

    userDataProvider.uploadCustomPoster(uid, widget.movie, base64Image);

    if (mounted) {
      setState(() {}); // Refresh hero section
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Custom poster uploaded!'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _showAddToListBottomSheet(
    BuildContext context,
    UserDataProvider userDataProvider,
    String uid,
    Movie movie,
  ) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Consumer<UserDataProvider>(
          builder: (context, provider, child) {
            final customLists = provider.customLists;

            return SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text(
                      'Save to...',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  if (customLists.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Text(
                        'No custom lists yet.',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  if (customLists.isNotEmpty)
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: customLists.length,
                        itemBuilder: (context, index) {
                          final customList = customLists[index];
                          final isInList =
                              customList.movieIds.contains(movie.uniqueId) ||
                              customList.movieIds.contains(movie.id);
                          return CheckboxListTile(
                            title: Text(customList.formattedName),
                            value: isInList,
                            activeColor: Colors.deepPurpleAccent,
                            onChanged: (bool? value) {
                              provider.toggleMovieInCustomList(
                                uid,
                                customList.id,
                                movie,
                              );
                            },
                          );
                        },
                      ),
                    ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.add),
                    title: const Text('New list'),
                    onTap: () {
                      Navigator.pop(context);
                      _showCreateListDialog(context, provider, uid, movie);
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showCreateListDialog(
    BuildContext context,
    UserDataProvider userDataProvider,
    String uid,
    Movie movie,
  ) {
    final TextEditingController nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('New list'),
          content: TextField(
            controller: nameController,
            decoration: const InputDecoration(hintText: 'Enter list name'),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final listName = nameController.text.trim();
                if (listName.isNotEmpty) {
                  userDataProvider.createCustomList(uid, listName, movie);
                  Navigator.pop(context);
                }
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildImage(String path) {
    if (path.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: path,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          color: Colors.grey[900],
          child: const Center(child: CircularProgressIndicator()),
        ),
        errorWidget: (context, url, error) => Container(
          color: Colors.grey[900],
          child: const Center(child: Icon(Icons.broken_image, size: 50)),
        ),
      );
    } else {
      try {
        final decodedBytes = base64Decode(path);
        return Image.memory(decodedBytes, fit: BoxFit.cover);
      } catch (_) {
        return Container(
          color: Colors.grey[900],
          child: const Center(child: Icon(Icons.broken_image, size: 50)),
        );
      }
    }
  }
}
