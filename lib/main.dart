import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:veil/export.dart';

class SupabaseClientService {
  static final SupabaseClientService _instance =
      SupabaseClientService._internal();
  factory SupabaseClientService() => _instance;
  SupabaseClientService._internal();

  SupabaseClient get client => Supabase.instance.client;

  static Future<void> initialize() async {
    await dotenv.load(fileName: ".env");
    await Supabase.initialize(
      url: dotenv.env['SUPABASE_URL']!,
      anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
    );
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseClientService.initialize();
  runApp(const ProviderScope(child: VeilApp()));
}

class VeilApp extends StatelessWidget {
  const VeilApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Veil',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
        primaryColor: Colors.white,
        inputDecorationTheme: const InputDecorationTheme(
          fillColor: Colors.black,
        ),
      ),
      initialRoute: '/splash',
      routes: {
        '/splash': (context) => const SplashScreen(),
        '/feed': (context) => const FeedScreen(),
        '/main': (context) => const MainScreen(),
        '/login': (context) => const LoginScreen(),
        '/signup': (context) => const SignUpScreen(),
        '/verify-otp': (context) {
          final args =
              ModalRoute.of(context)!.settings.arguments
                  as Map<String, dynamic>;
          return VerifyOtpScreen(
            email: args['email'],
            password: args['password'],
            username: args['username'],
          );
        },
      },
    );
  }
}
