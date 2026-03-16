import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import 'catalog_screen.dart';
import 'favorites_screen.dart';
import 'lists_screen.dart';
import 'profile_screen.dart';
import 'login_screen.dart';

class MainContainerScreen extends StatefulWidget {
  const MainContainerScreen({super.key});

  @override
  State<MainContainerScreen> createState() => _MainContainerScreenState();
}

class _MainContainerScreenState extends State<MainContainerScreen> {
  int _currentIndex = 0;
  final GlobalKey<CatalogScreenState> _catalogKey =
      GlobalKey<CatalogScreenState>();

  late final List<Widget> _screens = [
    CatalogScreen(key: _catalogKey),
    const FavoritesScreen(),
    const ListsScreen(),
    const ProfileScreen(),
  ];

  Widget _buildBody(BuildContext context, int index) {
    if (index == 0) return _screens[index]; // Home is public

    return Consumer<AuthService>(
      builder: (context, auth, _) {
        if (auth.currentUser == null) {
          if (index == 3) {
            return const LoginScreen();
          }
          return Scaffold(
            appBar: AppBar(title: Text(_getAppBarTitle(index))),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.lock_outline, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('Please log in to view this tab.'),
                ],
              ),
            ),
          );
        }
        return _screens[index];
      },
    );
  }

  String _getAppBarTitle(int index) {
    switch (index) {
      case 1:
        return 'Favorites';
      case 2:
        return 'Lists';
      case 3:
        return 'Profile';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _buildBody(context, _currentIndex),
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          indicatorColor:
              Colors.transparent, // Removes the wide highlight bubble
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const TextStyle(
                color: Colors.deepPurpleAccent,
                fontWeight: FontWeight.bold,
              );
            }
            return const TextStyle(color: Colors.grey);
          }),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const IconThemeData(
                color: Colors.deepPurpleAccent,
                size: 28,
              );
            }
            return const IconThemeData(color: Colors.grey, size: 24);
          }),
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (index) {
            if (index == 0 && _currentIndex == 0) {
              // User tapped Home while already on Home
              _catalogKey.currentState?.scrollToTopOrRefresh();
            } else {
              setState(() {
                _currentIndex = index;
              });
            }
          },
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
            NavigationDestination(
              icon: Icon(Icons.favorite),
              label: 'Favorites',
            ),
            NavigationDestination(icon: Icon(Icons.view_list), label: 'Lists'),
            NavigationDestination(icon: Icon(Icons.person), label: 'Profile'),
          ],
        ),
      ),
    );
  }
}
