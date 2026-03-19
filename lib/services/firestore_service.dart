import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // User Actions (Watched / Favorites)
  Future<void> toggleWatched(
    String uid,
    String movieId,
    bool isCurrentlyWatched, {
    String? legacyId,
  }) async {
    final userRef = _db.collection('users').doc(uid);
    if (isCurrentlyWatched) {
      await userRef.set({
        'watched': FieldValue.arrayRemove([
          movieId,
          ...?legacyId != null ? [legacyId] : null,
        ]),
      }, SetOptions(merge: true));
    } else {
      await userRef.set({
        'watched': FieldValue.arrayUnion([movieId]),
      }, SetOptions(merge: true));
    }
  }

  Future<void> toggleFavorite(
    String uid,
    String movieId,
    bool isCurrentlyFavorite, {
    String? legacyId,
  }) async {
    final userRef = _db.collection('users').doc(uid);
    if (isCurrentlyFavorite) {
      await userRef.set({
        'favorites': FieldValue.arrayRemove([
          movieId,
          ...?legacyId != null ? [legacyId] : null,
        ]),
      }, SetOptions(merge: true));
    } else {
      await userRef.set({
        'favorites': FieldValue.arrayUnion([movieId]),
      }, SetOptions(merge: true));
    }
  }

  Stream<DocumentSnapshot> getUserData(String uid) {
    return _db.collection('users').doc(uid).snapshots();
  }

  // Custom User Lists
  Stream<QuerySnapshot> getCustomLists(String uid) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('custom_lists')
        .orderBy('created_at')
        .snapshots();
  }

  Future<void> createCustomList(
    String uid,
    String listName, [
    String? initialMovieId,
  ]) async {
    // Normalize list name for ID (lowercase and trimmed)
    final normalizedId = listName.trim().toLowerCase();

    final listRef = _db
        .collection('users')
        .doc(uid)
        .collection('custom_lists')
        .doc(normalizedId);

    await listRef.set({
      'name': listName.trim(), // Keep original casing here
      if (initialMovieId != null)
        'movieIds': FieldValue.arrayUnion([initialMovieId]),
      'created_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> toggleMovieInCustomList(
    String uid,
    String listId,
    String movieId,
    bool isCurrentlyInList, {
    String? legacyId,
  }) async {
    final listRef = _db
        .collection('users')
        .doc(uid)
        .collection('custom_lists')
        .doc(listId);
    if (isCurrentlyInList) {
      await listRef.update({
        'movieIds': FieldValue.arrayRemove([
          movieId,
          ...?legacyId != null ? [legacyId] : null,
        ]),
      });
    } else {
      await listRef.update({
        'movieIds': FieldValue.arrayUnion([movieId]),
      });
    }
  }

  Future<void> deleteCustomList(String uid, String listId) async {
    await _db
        .collection('users')
        .doc(uid)
        .collection('custom_lists')
        .doc(listId)
        .delete();
  }

  // Custom Posters (per-user overrides for missing TMDB images)
  Future<void> uploadCustomPoster(
    String uid,
    String movieUniqueId,
    String base64Image,
  ) async {
    await _db
        .collection('users')
        .doc(uid)
        .collection('custom_posters')
        .doc(movieUniqueId)
        .set({'image': base64Image});
  }

  Future<void> deleteCustomPoster(String uid, String movieUniqueId) async {
    await _db
        .collection('users')
        .doc(uid)
        .collection('custom_posters')
        .doc(movieUniqueId)
        .delete();
  }

  Stream<QuerySnapshot> getCustomPosters(String uid) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('custom_posters')
        .snapshots();
  }

  // Video Collections (per-user video edits for movies/shows)
  Future<void> addVideoMetadata(
    String uid,
    String movieUniqueId,
    String videoUrl,
    String title,
  ) async {
    final movieRef = _db
        .collection('users')
        .doc(uid)
        .collection('video_collections')
        .doc(movieUniqueId);

    // Ensure the movie parent document exists so it can be discovered during account deletion
    await movieRef.set({
      'lastUpdated': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await movieRef.collection('videos').add({
      'videoUrl': videoUrl,
      'title': title,
      'uploadedAt': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> deleteVideoMetadata(
    String uid,
    String movieUniqueId,
    String videoId,
  ) async {
    await _db
        .collection('users')
        .doc(uid)
        .collection('video_collections')
        .doc(movieUniqueId)
        .collection('videos')
        .doc(videoId)
        .delete();
  }

  Stream<QuerySnapshot> getVideoCollection(
    String uid,
    String movieUniqueId,
  ) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('video_collections')
        .doc(movieUniqueId)
        .collection('videos')
        .orderBy('uploadedAt', descending: true)
        .snapshots();
  }

  Future<List<String>> deleteUserAccountData(String uid) async {
    final userRef = _db.collection('users').doc(uid);
    final batch = _db.batch();
    final List<String> videoUrls = [];

    // 1. Delete all custom lists (subcollection)
    final listsSnapshot = await userRef.collection('custom_lists').get();
    for (var doc in listsSnapshot.docs) {
      batch.delete(doc.reference);
    }

    // 2. Delete all custom posters (subcollection)
    final postersSnapshot = await userRef.collection('custom_posters').get();
    for (var doc in postersSnapshot.docs) {
      batch.delete(doc.reference);
    }

    // 3. Delete all video collection metadata
    final videoCollsSnapshot =
        await userRef.collection('video_collections').get();
    for (var collDoc in videoCollsSnapshot.docs) {
      final videosSnapshot =
          await collDoc.reference.collection('videos').get();
      for (var videoDoc in videosSnapshot.docs) {
        final data = videoDoc.data();
        final url = data['videoUrl'] as String?;
        if (url != null) {
          videoUrls.add(url);
        }
        batch.delete(videoDoc.reference);
      }
      batch.delete(collDoc.reference);
    }

    // 4. Delete the main user document
    batch.delete(userRef);

    await batch.commit();
    return videoUrls;
  }
}
