import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/auth_viewmodel.dart';

class ProfileView extends StatelessWidget {
  const ProfileView({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<AuthViewModel>();
    final user = viewModel.user;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: Center(
        child: user == null
            ? const Text('Not logged in')
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundImage: user.photoURL != null ? NetworkImage(user.photoURL!) : null,
                    child: user.photoURL == null ? const Icon(Icons.person, size: 50) : null,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    user.displayName ?? 'No Name',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(user.email ?? 'No Email'),
                  const SizedBox(height: 48),
                  ElevatedButton.icon(
                    onPressed: () async {
                      await viewModel.signOut();
                      if (context.mounted) {
                        Navigator.pop(context);
                      }
                    },
                    icon: const Icon(Icons.logout),
                    label: const Text('Logout'),
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.red,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
