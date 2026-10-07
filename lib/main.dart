import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'app.dart';
import 'services/notification_service.dart';
import 'services/theme_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Runs the music player in an Android media service so it keeps playing
  // when you leave the Music tab, lock the phone or close the app.
  try {
    await JustAudioBackground.init(
      androidNotificationChannelId: 'com.godfident.music',
      androidNotificationChannelName: 'Godfident music',
      androidNotificationOngoing: true,
    );
  } catch (_) {}
  await ThemeController.load(); // before the first frame: no wrong-theme flash
  await NotificationService().initialize();
  runApp(const ProviderScope(child: GodfidentApp()));
}
