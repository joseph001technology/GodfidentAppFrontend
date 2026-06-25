import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/auth/forgot_password_screen.dart';
import '../screens/auth/verify_email_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/bible/bible_screen.dart';
import '../screens/bible/chapter_screen.dart';
import '../screens/bible/verse_detail_screen.dart';
import '../screens/bible/search_screen.dart';
import '../screens/devotionals/devotional_list_screen.dart';
import '../screens/devotionals/devotional_detail_screen.dart';
import '../screens/devotionals/saved_devotionals_screen.dart';
import '../screens/reading_plans/plans_screen.dart';
import '../screens/reading_plans/my_plans_screen.dart';
import '../screens/reading_plans/plan_day_screen.dart';
import '../screens/prayer/prayer_list_screen.dart';
import '../screens/prayer/prayer_form_screen.dart';
import '../screens/prayer/prayer_detail_screen.dart';
import '../screens/prayer/prayer_stats_screen.dart';
import '../screens/ai/ai_home_screen.dart';
import '../screens/ai/chat_screen.dart';
import '../screens/ai/explain_verse_screen.dart';
import '../screens/ai/topic_study_screen.dart';
import '../screens/ai/character_study_screen.dart';
import '../screens/analytics/dashboard_screen.dart';
import '../screens/notifications/notifications_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/settings/profile_screen.dart';
import '../screens/settings/change_password_screen.dart';
import '../widgets/common/shell_scaffold.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/home',
    redirect: (context, state) {
      final isAuthed = authState.value == true;
      final isAuthRoute = state.matchedLocation.startsWith('/login') ||
          state.matchedLocation.startsWith('/register') ||
          state.matchedLocation.startsWith('/forgot') ||
          state.matchedLocation.startsWith('/verify');

      if (!isAuthed && !isAuthRoute) return '/login';
      if (isAuthed && isAuthRoute) return '/home';
      return null;
    },
    routes: [
      // Auth routes
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
      GoRoute(path: '/forgot-password', builder: (_, __) => const ForgotPasswordScreen()),
      GoRoute(path: '/verify-email', builder: (_, __) => const VerifyEmailScreen()),

      // Shell with bottom nav
      ShellRoute(
        builder: (context, state, child) => ShellScaffold(child: child),
        routes: [
          GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
          GoRoute(
            path: '/bible',
            builder: (_, __) => const BibleScreen(),
            routes: [
              GoRoute(
                path: 'chapter',
                builder: (_, state) => ChapterScreen(
                  book: state.uri.queryParameters['book']!,
                  chapter: int.parse(state.uri.queryParameters['chapter']!),
                  translation: state.uri.queryParameters['translation'] ?? 'KJV',
                ),
              ),
              GoRoute(
                path: 'verse',
                builder: (_, state) => VerseDetailScreen(
                  book: state.uri.queryParameters['book']!,
                  chapter: int.parse(state.uri.queryParameters['chapter']!),
                  verse: int.parse(state.uri.queryParameters['verse']!),
                  translation: state.uri.queryParameters['translation'] ?? 'KJV',
                ),
              ),
              GoRoute(path: 'search', builder: (_, __) => const SearchScreen()),
            ],
          ),
          GoRoute(
            path: '/prayer',
            builder: (_, __) => const PrayerListScreen(),
            routes: [
              GoRoute(path: 'new', builder: (_, __) => const PrayerFormScreen()),
              GoRoute(
                path: ':id',
                builder: (_, state) => PrayerDetailScreen(id: int.parse(state.pathParameters['id']!)),
                routes: [
                  GoRoute(
                    path: 'edit',
                    builder: (_, state) => PrayerFormScreen(prayerId: int.parse(state.pathParameters['id']!)),
                  ),
                ],
              ),
              GoRoute(path: 'stats', builder: (_, __) => const PrayerStatsScreen()),
            ],
          ),
          GoRoute(
            path: '/ai',
            builder: (_, __) => const AiHomeScreen(),
            routes: [
              GoRoute(
                path: 'chat',
                builder: (_, state) => ChatScreen(sessionId: state.uri.queryParameters['session']),
              ),
              GoRoute(path: 'explain-verse', builder: (_, __) => const ExplainVerseScreen()),
              GoRoute(path: 'topic-study', builder: (_, __) => const TopicStudyScreen()),
              GoRoute(path: 'character-study', builder: (_, __) => const CharacterStudyScreen()),
            ],
          ),
          GoRoute(
            path: '/more',
            builder: (_, __) => const DevotionalListScreen(),
            routes: [
              GoRoute(path: 'devotionals', builder: (_, __) => const DevotionalListScreen()),
              GoRoute(
                path: 'devotionals/:id',
                builder: (_, state) => DevotionalDetailScreen(id: int.parse(state.pathParameters['id']!)),
              ),
              GoRoute(path: 'devotionals/saved', builder: (_, __) => const SavedDevotionalsScreen()),
              GoRoute(path: 'plans', builder: (_, __) => const PlansScreen()),
              GoRoute(path: 'my-plans', builder: (_, __) => const MyPlansScreen()),
              GoRoute(
                path: 'plans/:id/day',
                builder: (_, state) => PlanDayScreen(planId: int.parse(state.pathParameters['id']!)),
              ),
              GoRoute(path: 'analytics', builder: (_, __) => const DashboardScreen()),
              GoRoute(path: 'notifications', builder: (_, __) => const NotificationsScreen()),
              GoRoute(path: 'settings', builder: (_, __) => const SettingsScreen()),
              GoRoute(path: 'profile', builder: (_, __) => const ProfileScreen()),
              GoRoute(path: 'change-password', builder: (_, __) => const ChangePasswordScreen()),
            ],
          ),
        ],
      ),
    ],
  );
});
