import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/trips_screen.dart';
import 'screens/lists_screen.dart';
import 'screens/items_screen.dart';
import 'theme/app_theme.dart';
import 'screens/trip_map_screen.dart';

import 'screens/forgot_password_screen.dart';
import 'screens/reset_password_screen.dart';

void main() {
  runApp(const FoldawayApp());
}

final _router = GoRouter(
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => LoginScreen(
        initialMessage: state.uri.queryParameters['message'],
        initialEmail: state.uri.queryParameters['email'],
      ),
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
    GoRoute(path: '/trips/:tripId/map',
      builder: (context, state) => TripMapScreen(
        tripId: state.pathParameters['tripId']!,
        tripTitle: state.uri.queryParameters['title'] ?? 'Карта подорожі',
      ),
    ),
    GoRoute(
      path: '/trips/:tripId/lists/:listId',
      builder: (context, state) => ItemsScreen(
        tripId: state.pathParameters['tripId']!,
        listId: state.pathParameters['listId']!,
        listTitle: state.uri.queryParameters['listTitle'] ?? 'Список',
        tripTitle: state.uri.queryParameters['tripTitle'] ?? 'Подорож',
      ),
    ),
    GoRoute(
      path: '/forgot-password',
      builder: (context, state) => const ForgotPasswordScreen(),
    ),

    GoRoute(
      path: '/reset-password',
      builder: (context, state) => ResetPasswordScreen(
        uid: state.uri.queryParameters['uid'] ?? '',
        token: state.uri.queryParameters['token'] ?? '',
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