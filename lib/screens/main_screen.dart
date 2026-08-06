import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:veil/export.dart';

class MainScreen extends ConsumerWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentTab = ref.watch(mainTabProvider);
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final userId = user?.id ?? '';

    int _getNavIndexFromTab(int tabIndex) {
      const map = {0: 0, 1: 1, 2: 3, 3: 4};
      return map[tabIndex] ?? 0;
    }

    int _getTabIndexFromNav(int navIndex) {
      const map = {0: 0, 1: 1, 3: 2, 4: 3};
      return map[navIndex] ?? 0;
    }

    return WillPopScope(
      onWillPop: () async {
        final now = DateTime.now();
        final lastPress = ref.read(lastBackPressProvider);
        if (lastPress != null &&
            now.difference(lastPress) < const Duration(seconds: 2)) {
          return true;
        }
        ref.read(lastBackPressProvider.notifier).state = now;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Press back again to exit'),
            duration: Duration(seconds: 2),
          ),
        );
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        resizeToAvoidBottomInset: true,
        body: IndexedStack(
          index: currentTab,
          children: [
            const FeedScreen(),
            const ExploreScreen(),
            const EchoesScreen(),
            userId.isNotEmpty
                ? ProfileScreen(userId: userId, isRoot: true)
                : const Center(
                    child: Text(
                      'Please log in',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: GlassNavBar(
              currentIndex: _getNavIndexFromTab(currentTab),
              onTap: (navIndex) {
                if (navIndex == 2) {
                  // + button pressed
                  if (currentTab == 2) {
                    // We are currently on Echoes → open New Chat flow
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const NewChatScreen()),
                    );
                  } else {
                    // Normal behaviour → Create Post
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const CreatePostScreen(),
                      ),
                    );
                  }
                  return;
                }

                final tabIndex = _getTabIndexFromNav(navIndex);
                ref.read(mainTabProvider.notifier).state = tabIndex;
              },
            ),
          ),
        ),
      ),
    );
  }
}
