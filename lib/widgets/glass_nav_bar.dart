import 'package:flutter/material.dart';

class GlassNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const GlassNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: BackdropFilter(
        filter: const ColorFilter.mode(Color(0xCC1A1A1A), BlendMode.srcOver),
        child: Container(
          height: 72,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.6),
            border: Border(
              top: BorderSide(
                color: Colors.white.withOpacity(0.08),
                width: 0.5,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildItem(Icons.home_outlined, 'Feed', 0),
              _buildItem(Icons.search_outlined, 'Seek', 1),
              _buildPlusButton(),
              _buildItem(Icons.forum_outlined, 'Echoes', 3),
              _buildItem(Icons.person_outline, 'Profile', 4),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildItem(IconData icon, String label, int index) {
    final isSelected = currentIndex == index;
    return GestureDetector(
      onTap: () => onTap(index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.white.withOpacity(0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : Colors.grey,
              size: 26,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey,
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlusButton() {
    return GestureDetector(
      onTap: () => onTap(2), // plus index
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.purple.shade600, Colors.blue.shade600],
          ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.purple.withOpacity(0.4),
              blurRadius: 16,
              spreadRadius: 4,
            ),
          ],
        ),
        child: const Icon(Icons.add, color: Colors.white, size: 32),
      ),
    );
  }
}
