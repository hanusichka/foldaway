import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/trips_screen.dart';
import 'screens/lists_screen.dart';
import 'screens/items_screen.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const FoldawayApp());
}

final _router = GoRouter(
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/register',
      builder: (context, state) => const RegisterScreen(),
    ),
    GoRoute(
      path: '/trips',
      builder: (context, state) => const TripsScreen(),
    ),
    GoRoute(
      path: '/trips/:tripId',
      builder: (context, state) => ListsScreen(
        tripId: state.pathParameters['tripId']!,
        tripTitle: state.uri.queryParameters['title'] ?? 'Подорож',
      ),
    ),
    GoRoute(
      path: '/trips/:tripId/lists/:listId',
      builder: (context, state) => ItemsScreen(
        listId: state.pathParameters['listId']!,
        listTitle: state.extra as String? ?? 'Список',
      ),
    ),
  ],
);

class FoldawayApp extends StatelessWidget {
  const FoldawayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Foldaway',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: _router,
    );
  }
}