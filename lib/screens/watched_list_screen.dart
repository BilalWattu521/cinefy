import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_data_provider.dart';
import '../providers/catalog_provider.dart';
import '../services/auth_service.dart';
import '../models/movie.dart';
import 'movie_detail_screen.dart';
import '../widgets/movie_card.dart';

class WatchedListScreen extends StatelessWidget {
  const WatchedListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Watched List')),
      body: Consumer3<AuthService, UserDataProvider, CatalogProvider>(
        builder: (context, authService, userData, catalog, _) {
          final user = authService.currentUser;
          if (user == null) {
            return const Center(
              child: Text('Please log in to see your watched list.'),
            );
          }

          final watchedIds = userData.watchedIds;
          if (watchedIds.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.visibility_off, size: 80, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'Your watched list is empty',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            );
          }

          // Check if everything is loaded
          final bool allLoaded = catalog.areAllLoaded(watchedIds);
          final bool isResolving = catalog.isAnyResolving(watchedIds);

          // If some movies are missing, trigger resolution in background
          if (!allLoaded) {
            Future.microtask(() => catalog.resolveMovies(watchedIds));
          }

          // Show a full-screen loading indicator if we have IDs but nothing is ready yet
          if (watchedIds.isNotEmpty && !allLoaded) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    const Text(
                      'Loading, please wait...',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            );
          }

          // Get the full movie objects from the catalog
          final watchedMovies = watchedIds
              .map((id) => catalog.getMovieById(id))
              .whereType<Movie>()
              .toList();

          return Stack(
            children: [
              GridView.builder(
                padding: const EdgeInsets.all(12),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.7,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: watchedMovies.length,
                itemBuilder: (context, index) {
                  final movie = watchedMovies[index];
                  return MovieCard(
                    movie: movie,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => MovieDetailScreen(movie: movie),
                        ),
                      );
                    },
                    overlay: Positioned(
                      top: 8,
                      right: 8,
                      child: GestureDetector(
                        onTap: () {
                          userData.toggleWatched(user.uid, movie);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.9),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Tooltip(
                            message: 'Remove from Watched List',
                            child: Icon(
                              Icons.visibility,
                              color: Colors.green,
                              size: 18,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              if (isResolving)
                const Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: LinearProgressIndicator(
                    minHeight: 2,
                    backgroundColor: Colors.transparent,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
