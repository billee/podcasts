// web/main.dart

import 'package:kapwa_companion_basic/main.dart' as app;
import 'package:kapwa_companion_basic/web/video_player_channel.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';

void main() {
  // Register the web plugin
  VideoPlayerChannel.registerWith(registrarFor('video_player_channel'));

  // Run the app
  app.main();
}
