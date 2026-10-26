import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/video/random_video_service.dart';
import '../services/video/video_folder_gateway.dart';
import '../services/video/video_library_store.dart';

/// One library for the whole phone. It is not tied to the logged-in account:
/// logging out or switching accounts never touches the Movies/Godfident folder.
final videoLibraryStoreProvider = Provider<VideoLibraryStore>(
  (ref) => VideoLibraryStore(NativeVideoFolderGateway()),
);

/// Picks the next video to show when something is blocked.
final randomVideoServiceProvider = Provider<RandomVideoService>(
  (ref) => RandomVideoService(ref.watch(videoLibraryStoreProvider)),
);
