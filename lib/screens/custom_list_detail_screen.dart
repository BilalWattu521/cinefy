import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_data_provider.dart';
import '../providers/catalog_provider.dart';
import '../services/auth_service.dart';
import '../models/movie.dart';
import 'movie_detail_screen.dart';
import '../widgets/movie_card.dart';

class CustomListDetailScreen extends StatelessWidget {
  final String listId;

  const CustomListDetailScreen({super.key, required this.listId});

  @override
  Widget build(BuildContext context) {
    return Consumer3<AuthService, UserDataProvider, CatalogProvider>(
      builder: (context, authService, userData, catalog, _) {
        final user = authService.currentUser;
        if (user == null) {
          return const Scaffold(body: Center(child: Text('Please log in.')));
        }

        // Find the list in the provider's current data
        final listIndex = userData.customLists.indexWhere(
          (l) => l.id == listId,
        );
        if (listIndex == -1) {
          return Scaffold(
            appBar: AppBar(title: const Text('List Not Found')),
            body: const Center(child: Text('This list no longer exists.')),
          );
        }

        final customList = userData.customLists[listIndex];
        final movieIds = customList.movieIds;

        return Scaffold(
          appBar: AppBar(
            title: Text(customList.formattedName),
            actions: [
              IconButton(
                icon: const Icon(Icons.delete_outline),
                color: Colors.redAccent,
                tooltip: 'Delete List',
                onPressed: () => _confirmDeleteList(
                  context,
                  userData,
                  user.uid,
                  customList.id,
                  customList.formattedName,
                ),
              ),
            ],
          ),
          body: movieIds.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.movie_outlined, size: 80, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'This list is empty',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                )
              : Builder(
                  builder: (context) {
                    // Check if everything is loaded
                    final bool allLoaded = catalog.areAllLoaded(movieIds);
                    final bool isResolving = catalog.isAnyResolving(movieIds);

                    // If some movies are missing, trigger resolution in background
                    if (!allLoaded) {
                      Future.microtask(() => catalog.resolveMovies(movieIds));
                    }

                    // Show a full-screen loading indicator if we have IDs but nothing is ready yet
                    if (movieIds.isNotEmpty && !allLoaded) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CircularProgressIndicator(),
                            const SizedBox(height: 16),
                            const Text(
                              'Loading, please wait...',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      );
                    }

                    // Get the full movie objects from the catalog
                    final listMovies = movieIds
                        .map((id) => catalog.getMovieById(id))
                        .whereType<Movie>()
                        .toList();

                    return Stack(
                      children: [
                        GridView.builder(
                          padding: const EdgeInsets.all(12),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                childAspectRatio: 0.7,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                              ),
                          itemCount: listMovies.length,
                          itemBuilder: (context, index) {
                            final movie = listMovies[index];
                            return MovieCard(
                              movie: movie,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        MovieDetailScreen(movie: movie),
                                  ),
                                );
                              },
                              overlay: Positioned(
                                top: 8,
                                right: 8,
                                child: GestureDetector(
                                  onTap: () {
                                    userData.toggleMovieInCustomList(
                                      user.uid,
                                      listId,
                                      movie,
                                    );
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(
                                        alpha: 0.9,
                                      ),
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(
                                            alpha: 0.2,
                                          ),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: const Tooltip(
                                      message: 'Remove from List',
                                      child: Icon(
                                        Icons.remove_circle,
                                        color: Colors.orangeAccent,
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
      },
    );
  }

  void _confirmDeleteList(
    BuildContext context,
    UserDataProvider userData,
    String uid,
    String listId,
    String listName,
  ) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete List'),
          content: Text('Are you sure you want to delete this list?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                userData.deleteCustomList(uid, listId);
                Navigator.pop(context); // Close dialog
                Navigator.pop(context); // Go back to Lists screen
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }
}
