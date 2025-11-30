import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import '../home/home_content_page.dart';
import '../map/map_page.dart';
import '../favorites/favorites_page.dart';
import '../profile/profile_page.dart';
import '../messages/conversations_list_page.dart';
import '../../../services/supabase_service.dart';

class HomePage extends HookWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final supabaseService = SupabaseService();
    final user = supabaseService.currentUser;
    final currentIndex = useState(0);

    // Pages principales - REMOVED SEARCH PAGE
    final List<Widget> pages = [
      const HomeContentPage(),
      const MapPage(),
      const FavoritesPage(),
      const ConversationsListPage(),
      const ProfilePage(),
    ];

    return Scaffold(
      body: pages[currentIndex.value],
      bottomNavigationBar: _buildBottomNavigationBar(currentIndex),
    );
  }

  Widget _buildBottomNavigationBar(ValueNotifier<int> currentIndex) {
    return BottomNavigationBar(
      currentIndex: currentIndex.value,
      onTap: (index) => currentIndex.value = index,
      type: BottomNavigationBarType.fixed,
      backgroundColor: Colors.white,
      selectedItemColor: Colors.blue,
      unselectedItemColor: Colors.grey,
      selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
      unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal),
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home),
          activeIcon: Icon(Icons.home_filled),
          label: 'Accueil',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.map_outlined),
          activeIcon: Icon(Icons.map),
          label: 'Carte',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.favorite_border),
          activeIcon: Icon(Icons.favorite),
          label: 'Favoris',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.chat_bubble_outline),
          activeIcon: Icon(Icons.chat_bubble),
          label: 'Messages',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person_outline),
          activeIcon: Icon(Icons.person),
          label: 'Profil',
        ),
      ],
    );
  }
}
