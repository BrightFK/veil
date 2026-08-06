import 'package:flutter_riverpod/legacy.dart';

/// Increment this provider to trigger a refresh in the Profile screen
final refreshProfileProvider = StateProvider<int>((ref) => 0);
