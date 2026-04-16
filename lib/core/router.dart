import 'package:go_router/go_router.dart';
import '../screens/main_screen.dart';
import '../screens/analysis_screen.dart';
import '../screens/settings_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const MainScreen(),
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
    ),
    GoRoute(
      path: '/analysis',
      builder: (context, state) => const AnalysisScreen(),
    ),
  ],
);
