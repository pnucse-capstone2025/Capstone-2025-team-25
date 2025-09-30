// lib/screens/profile_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/profile_provider.dart';
import '../providers/user_provider.dart';
import '../widgets/glass_container.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userUuid = Provider.of<UserProvider>(
        context,
        listen: false,
      ).userUuid;
      if (userUuid != null) {
        Provider.of<ProfileProvider>(
          context,
          listen: false,
        ).loadProfile(userUuid);
      }
    });
  }

  void _editDisplayName(BuildContext context, ProfileProvider provider) {
    final TextEditingController controller = TextEditingController(
      text: provider.userProfile?.displayName,
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Display Name'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'New Display Name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final userUuid = Provider.of<UserProvider>(
                context,
                listen: false,
              ).userUuid;
              if (userUuid != null && controller.text.isNotEmpty) {
                provider.updateDisplayName(userUuid, controller.text);
              }
              Navigator.of(ctx).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                SizedBox.expand(
                  child: Image.asset(
                    'assets/background.png',
                    fit: BoxFit.cover,
                  ),
                ),
                Consumer<ProfileProvider>(
                  builder: (context, provider, child) {
                    if (provider.isLoading && provider.userProfile == null) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (provider.errorMessage != null) {
                      return Center(
                        child: Text('An error occurred: ${provider.errorMessage}'),
                      );
                    }
                    if (provider.userProfile == null) {
                      return const Center(child: Text('Could not load profile.'));
                    }

                    final profile = provider.userProfile!;

                    return RefreshIndicator(
                      onRefresh: () async {
                        final userUuid = Provider.of<UserProvider>(
                          context,
                          listen: false,
                        ).userUuid;
                        if (userUuid != null) await provider.loadProfile(userUuid);
                      },
                      child: ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 60),
                        children: [
                          GlassContainer(
                            child: Padding(
                              padding: const EdgeInsets.all(20.0),
                              child: Column(
                                children: [
                                  Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      CircleAvatar(
                                        radius: 60,
                                        backgroundColor: Colors.white.withOpacity(0.1),
                                        backgroundImage: profile.avatarUrl != null
                                            ? NetworkImage(profile.avatarUrl!)
                                            : null,
                                        child: profile.avatarUrl == null
                                            ? Icon(
                                                Icons.person,
                                                size: 60,
                                                color: Colors.white.withOpacity(0.5),
                                              )
                                            : null,
                                      ),
                                      if (provider.isUploading)
                                        const SizedBox(
                                          width: 120,
                                          height: 120,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                          ),
                                        ),
                                      Positioned(
                                        bottom: 0,
                                        right: 0,
                                        child: Material(
                                          color: Theme.of(context).primaryColor,
                                          shape: const CircleBorder(),
                                          elevation: 2,
                                          child: InkWell(
                                            onTap: provider.isUploading
                                                ? null
                                                : () {
                                                    final userUuid =
                                                        Provider.of<UserProvider>(
                                                      context,
                                                      listen: false,
                                                    ).userUuid;
                                                    if (userUuid != null) {
                                                      provider.uploadNewAvatar(userUuid);
                                                    }
                                                  },
                                            customBorder: const CircleBorder(),
                                            child: const Padding(
                                              padding: EdgeInsets.all(8.0),
                                              child: Icon(
                                                Icons.camera_alt,
                                                color: Colors.white,
                                                size: 20,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    profile.displayName,
                                    textAlign: TextAlign.center,
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineSmall
                                        ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                  ),
                                  Text(
                                    '@${profile.username}',
                                    textAlign: TextAlign.center,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyLarge
                                        ?.copyWith(color: Colors.white70),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),

                          GlassContainer(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ListTile(
                                  leading: const Icon(Icons.email_outlined, color: Colors.white),
                                  title: const Text('Email', style: TextStyle(color: Colors.white)),
                                  subtitle: Text(profile.email, style: const TextStyle(color: Colors.white70)),
                                ),
                                ListTile(
                                  leading: const Icon(Icons.badge_outlined, color: Colors.white),
                                  title: const Text('Nickname', style: TextStyle(color: Colors.white)),
                                  subtitle: Text(profile.username, style: const TextStyle(color: Colors.white70)),
                                ),
                                ListTile(
                                  leading: const Icon(Icons.person_outline, color: Colors.white),
                                  title: const Text('Display Name', style: TextStyle(color: Colors.white)),
                                  subtitle: Text(profile.displayName, style: const TextStyle(color: Colors.white70)),
                                  trailing: const Icon(Icons.edit_outlined, color: Colors.white70),
                                  onTap: () => _editDisplayName(context, provider),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    );
                  },
                )
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.only(bottom: 12, top: 4),
            child: Text(
              "Version 1.0.1",
              style: const TextStyle(
                color: Colors.black,
                fontSize: 14,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
