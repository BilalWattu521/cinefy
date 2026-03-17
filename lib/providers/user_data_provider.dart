import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/custom_list.dart';
import '../models/movie.dart';
import '../models/video_edit.dart';
import '../services/firestore_service.dart';
import '../services/storage_service.dart';

class UserDataProvider extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();
  final StorageService _storageService = StorageService();

  List<String> _watchedIds = [];
  List<String> _favoriteIds = [];
  List<CustomList> _customLists = [];
  Map<String, String> _customPosters = {};
  String? _currentUid;

  // Video cache per movie
  final Map<String, List<VideoEdit>> _movieVideosCache = {};
  final Map<String, StreamSubscription> _videoStreamSubs = {};
  final Set<String> _deletingVideoIds = {};

  // Video upload progress tracking
  bool _isUploadingVideo = false;
  final StreamController<double> _uploadProgressController = 
      StreamController<double>.broadcast();

  StreamSubscription? _userDataSub;
  StreamSubscription? _customListsSub;
  StreamSubscription? _customPostersSub;

  List<String> get watchedIds => _watchedIds;
  List<String> get favoriteIds => _favoriteIds;
  List<CustomList> get customLists => _customLists;
  Map<String, String> get customPosters => _customPosters;
  bool get isUploadingVideo => _isUploadingVideo;
  Set<String> get deletingVideoIds => _deletingVideoIds;
  Stream<double> get uploadProgressStream => _uploadProgressController.stream;

  // Getters for cached videos
  List<VideoEdit> getMovieVideos(String movieId) => _movieVideosCache[movieId] ?? [];
  bool isMovieVideosLoaded(String movieId) => _movieVideosCache.containsKey(movieId);

  FirestoreService get firestoreService => _firestoreService;

  void loadUserData(String uid) {
    if (_currentUid == uid) return;
    _currentUid = uid;

    _userDataSub?.cancel();
    _customListsSub?.cancel();
    _customPostersSub?.cancel();

    _userDataSub = _firestoreService.getUserData(uid).listen(
      (snapshot) {
        if (snapshot.exists) {
          final data = snapshot.data() as Map<String, dynamic>? ?? {};
          _watchedIds = List<String>.from(data['watched'] ?? []);
          _favoriteIds = List<String>.from(data['favorites'] ?? []);
          notifyListeners();
        } else {
          _watchedIds = [];
          _favoriteIds = [];
          notifyListeners();
        }
      },
      onError: (e) {
        if (kDebugMode) print('Error listening to user data: $e');
      },
    );

    _customListsSub = _firestoreService.getCustomLists(uid).listen(
      (snapshot) {
        _customLists = snapshot.docs
            .map(
              (doc) => CustomList.fromFirestore(
                doc.data() as Map<String, dynamic>,
                doc.id,
              ),
            )
            .toList();
        notifyListeners();
      },
      onError: (e) {
        if (kDebugMode) print('Error listening to custom lists: $e');
      },
    );

    _customPostersSub = _firestoreService.getCustomPosters(uid).listen(
      (snapshot) {
        _customPosters = {};
        for (var doc in snapshot.docs) {
          final data = doc.data() as Map<String, dynamic>;
          _customPosters[doc.id] = data['image'] as String;
        }
        notifyListeners();
      },
      onError: (e) {
        if (kDebugMode) print('Error listening to custom posters: $e');
      },
    );
  }

  void clearUserData() {
    _currentUid = null;
    _watchedIds = [];
    _favoriteIds = [];
    _customLists = [];
    _customPosters = {};
    _userDataSub?.cancel();
    _customListsSub?.cancel();
    _customPostersSub?.cancel();
    
    // Cancel all video subscriptions
    for (var sub in _videoStreamSubs.values) {
      sub.cancel();
    }
    _videoStreamSubs.clear();
    _movieVideosCache.clear();
    _deletingVideoIds.clear();
    
    notifyListeners();
  }

  @override
  void dispose() {
    _userDataSub?.cancel();
    _customListsSub?.cancel();
    _customPostersSub?.cancel();
    for (var sub in _videoStreamSubs.values) {
      sub.cancel();
    }
    _uploadProgressController.close();
    super.dispose();
  }

  Future<void> toggleWatched(String uid, Movie movie) async {
    final movieId = movie.uniqueId;
    final legacyId = movie.id;
    final isCurrentlyWatched =
        _watchedIds.contains(movieId) || _watchedIds.contains(legacyId);

    if (isCurrentlyWatched) {
      _watchedIds.remove(movieId);
      _watchedIds.remove(legacyId);
    } else {
      _watchedIds.add(movieId);
    }
    notifyListeners();

    try {
      await _firestoreService.toggleWatched(
        uid,
        movieId,
        isCurrentlyWatched,
        legacyId: legacyId,
      );
    } catch (e) {
      if (kDebugMode) print('Error toggling watched: $e');
      if (isCurrentlyWatched) {
        _watchedIds.add(movieId);
      } else {
        _watchedIds.remove(movieId);
      }
      notifyListeners();
    }
  }

  Future<void> toggleFavorite(String uid, Movie movie) async {
    final movieId = movie.uniqueId;
    final legacyId = movie.id;
    final isCurrentlyFavorite =
        _favoriteIds.contains(movieId) || _favoriteIds.contains(legacyId);

    if (isCurrentlyFavorite) {
      _favoriteIds.remove(movieId);
      _favoriteIds.remove(legacyId);
    } else {
      _favoriteIds.add(movieId);
    }
    notifyListeners();

    try {
      await _firestoreService.toggleFavorite(
        uid,
        movieId,
        isCurrentlyFavorite,
        legacyId: legacyId,
      );
    } catch (e) {
      if (kDebugMode) print('Error toggling favorite: $e');
      if (isCurrentlyFavorite) {
        _favoriteIds.add(movieId);
      } else {
        _favoriteIds.remove(movieId);
      }
      notifyListeners();
    }
  }

  Future<void> createCustomList(
    String uid,
    String listName, [
    Movie? initialMovie,
  ]) async {
    try {
      await _firestoreService.createCustomList(
        uid,
        listName,
        initialMovie?.uniqueId,
      );
    } catch (e) {
      if (kDebugMode) print('Error creating custom list: $e');
    }
  }

  Future<void> toggleMovieInCustomList(
    String uid,
    String listId,
    Movie movie,
  ) async {
    final listIndex = _customLists.indexWhere((l) => l.id == listId);
    if (listIndex == -1) return;

    final customList = _customLists[listIndex];
    final movieId = movie.uniqueId;
    final legacyId = movie.id;
    final isCurrentlyInList =
        customList.movieIds.contains(movieId) ||
        customList.movieIds.contains(legacyId);

    final updatedMovieIds = List<String>.from(customList.movieIds);
    if (isCurrentlyInList) {
      updatedMovieIds.remove(movieId);
      updatedMovieIds.remove(legacyId);
    } else {
      updatedMovieIds.add(movieId);
    }

    _customLists[listIndex] = CustomList(
      id: customList.id,
      name: customList.name,
      movieIds: updatedMovieIds,
    );
    notifyListeners();

    try {
      await _firestoreService.toggleMovieInCustomList(
        uid,
        listId,
        movieId,
        isCurrentlyInList,
        legacyId: legacyId,
      );
    } catch (e) {
      if (kDebugMode) print('Error toggling movie in custom list: $e');
      _customLists[listIndex] = customList;
      notifyListeners();
    }
  }

  Future<void> deleteCustomList(String uid, String listId) async {
    final listIndex = _customLists.indexWhere((l) => l.id == listId);
    if (listIndex == -1) return;

    final originalList = _customLists[listIndex];

    _customLists.removeAt(listIndex);
    notifyListeners();

    try {
      await _firestoreService.deleteCustomList(uid, listId);
    } catch (e) {
      if (kDebugMode) print('Error deleting list: $e');
      _customLists.insert(listIndex, originalList);
      notifyListeners();
    }
  }

  Future<void> uploadCustomPoster(
    String uid,
    Movie movie,
    String base64Image,
  ) async {
    final key = movie.uniqueId;

    _customPosters[key] = base64Image;
    notifyListeners();

    try {
      await _firestoreService.uploadCustomPoster(uid, key, base64Image);
    } catch (e) {
      if (kDebugMode) print('Error uploading custom poster: $e');
      _customPosters.remove(key);
      notifyListeners();
    }
  }

  Future<void> removeCustomPoster(String uid, Movie movie) async {
    final key = movie.uniqueId;
    final previous = _customPosters[key];

    _customPosters.remove(key);
    notifyListeners();

    try {
      await _firestoreService.deleteCustomPoster(uid, key);
    } catch (e) {
      if (kDebugMode) print('Error removing custom poster: $e');
      if (previous != null) {
        _customPosters[key] = previous;
      }
    }
  }

  // Video Collection Methods
  void watchMovieVideos(String uid, String movieUniqueId) {
    if (_videoStreamSubs.containsKey(movieUniqueId)) return;

    _videoStreamSubs[movieUniqueId] = _firestoreService
        .getVideoCollection(uid, movieUniqueId)
        .listen((snapshot) {
      _movieVideosCache[movieUniqueId] = snapshot.docs
          .map(
            (doc) => VideoEdit.fromFirestore(
              doc.data() as Map<String, dynamic>,
              doc.id,
            ),
          )
          .toList();
      notifyListeners();
    });
  }

  Future<bool> uploadVideo(
    String uid,
    Movie movie,
    File videoFile,
    String title,
  ) async {
    _isUploadingVideo = true;
    notifyListeners();
    try {
      final downloadUrl = await _storageService.uploadVideo(
        uid: uid,
        movieUniqueId: movie.uniqueId,
        videoFile: videoFile,
        onProgress: (progress) {
          _uploadProgressController.add(progress);
        },
      );

      await _firestoreService.addVideoMetadata(
        uid,
        movie.uniqueId,
        downloadUrl,
        title,
      );

      _isUploadingVideo = false;
      notifyListeners();
      return true;
    } catch (e) {
      if (kDebugMode) print('Error uploading video: $e');
      _isUploadingVideo = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteVideo(
    String uid,
    Movie movie,
    String videoId,
    String videoUrl,
  ) async {
    _deletingVideoIds.add(videoId);
    notifyListeners();
    try {
      await _storageService.deleteVideo(videoUrl);
      await _firestoreService.deleteVideoMetadata(
        uid,
        movie.uniqueId,
        videoId,
      );

      // Folder cleanup logic: if this was the last video, remove the folder
      final remainingVideos = _movieVideosCache[movie.uniqueId] ?? [];
      if (remainingVideos.length <= 1) {
        // We check <= 1 because the stream update might not have reflected the deletion yet
        // or this is the last one being removed.
        final folderPath = 'movie_tracker/users/$uid/videos/${movie.uniqueId}';
        await _storageService.deleteFolder(folderPath);
      }

      return true;
    } catch (e) {
      if (kDebugMode) print('Error deleting video: $e');
      return false;
    } finally {
      _deletingVideoIds.remove(videoId);
      notifyListeners();
    }
  }
}
