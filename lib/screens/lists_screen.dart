import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_data_provider.dart';
import '../services/auth_service.dart';
import 'custom_list_detail_screen.dart';
import 'watched_list_screen.dart';

class ListsScreen extends StatelessWidget {
  const ListsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<AuthService, UserDataProvider>(
      builder: (context, auth, userData, child) {
        final user = auth.currentUser;
        final customLists = userData.customLists;

        return Scaffold(
          appBar: AppBar(title: const Text('My Lists')),
          body: ListView(
            children: [
              ListTile(
                leading: const Icon(Icons.history),
                title: const Text('Watched List'),
                subtitle: Text('${userData.watchedIds.length} items'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const WatchedListScreen(),
                    ),
                  );
                },
              ),
              const Divider(),
              if (customLists.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Center(
                    child: Text(
                      'No custom lists yet.\nTap the + button to create one!',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                )
              else
                ...customLists.map(
                  (list) => ListTile(
                    leading: const Icon(Icons.list_alt),
                    title: Text(list.formattedName),
                    subtitle: Text('${list.movieIds.length} items'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              CustomListDetailScreen(listId: list.id),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
          floatingActionButton: user != null
              ? FloatingActionButton(
                  onPressed: () =>
                      _showCreateListDialog(context, userData, user.uid),
                  tooltip: 'Create New List',
                  child: const Icon(Icons.add),
                )
              : null,
        );
      },
    );
  }

  void _showCreateListDialog(
    BuildContext context,
    UserDataProvider userDataProvider,
    String uid,
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
                  userDataProvider.createCustomList(uid, listName);
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
}
