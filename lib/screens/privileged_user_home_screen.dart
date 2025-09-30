import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/chat_provider.dart';
import '../providers/task_request_provider.dart';
import '../providers/user_provider.dart';
import 'chats_list_screen.dart';
import 'tasks_page.dart';
import 'send_task_screen.dart';
import 'notifications_screen.dart';
import 'profile_screen.dart';
import 'user_search_screen.dart';

class PrivilegedUserHomeScreen extends StatefulWidget {
  const PrivilegedUserHomeScreen({super.key});

  @override
  State<PrivilegedUserHomeScreen> createState() =>
      _PrivilegedUserHomeScreenState();
}

class _PrivilegedUserHomeScreenState extends State<PrivilegedUserHomeScreen> {
  int _selectedIndex = 0;

  final List<Widget> _pages = <Widget>[
    SendTaskScreen(),
    const TasksPage(),
    const ChatsListScreen(),
    const ProfileScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Future<void> _showLogoutConfirmationDialog() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Confirm Logout'),
          content: const Text('Are you sure you want to log out?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(dialogContext).pop(); 
              },
            ),
            TextButton(
              child: const Text('Logout'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                Provider.of<UserProvider>(context, listen: false).logoutUser();
              },
            ),
          ],
        );
      },
    );
  }

  Widget? _buildFloatingActionButton(BuildContext context) {
    switch (_selectedIndex) {
      case 2: 
        return FloatingActionButton(
          heroTag: 'chats_fab_privileged',
          onPressed: () {
            Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => ChangeNotifierProvider.value(
                value: Provider.of<ChatProvider>(context, listen: false),
                child: const UserSearchScreen(),
              ),
            ));
          },
          backgroundColor: Theme.of(context).primaryColor,
          child: const Icon(Icons.add_comment, color: Colors.white),
        );
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return HeroControllerScope.none(
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => ChangeNotifierProvider.value(
                  value:
                      Provider.of<TaskRequestProvider>(context, listen: false),
                  child: const NotificationsScreen(),
                ),
              ));
            },
          ),
          title: const Text('UmiDo',
              style: TextStyle(fontWeight: FontWeight.bold)),
          centerTitle: true,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 1,
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Logout',
              onPressed: _showLogoutConfirmationDialog,
            ),
          ],
        ),
        body: IndexedStack(
          index: _selectedIndex,
          children: _pages,
        ),
        bottomNavigationBar: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          items: const <BottomNavigationBarItem>[
            BottomNavigationBarItem(icon: Icon(Icons.send), label: 'Send Task'),
            BottomNavigationBarItem(
                icon: Icon(Icons.task_alt), label: 'My Tasks'),
            BottomNavigationBarItem(
                icon: Icon(Icons.message), label: 'Messages'),
            BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
          ],
          currentIndex: _selectedIndex,
          selectedItemColor: Theme.of(context).primaryColor,
          unselectedItemColor: Colors.grey,
          onTap: _onItemTapped,
        ),
        floatingActionButton: _buildFloatingActionButton(context),
      ),
    );
  }
}
