import 'package:flutter_riverpod/legacy.dart';

final mainTabProvider = StateProvider<int>((ref) => 0);

/// Used for double back to exit
final lastBackPressProvider = StateProvider<DateTime?>((ref) => null);
