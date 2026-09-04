import 'package:ani_dash/core/tasks/news_task.dart';
import 'package:ani_dash/core/tasks/episode_release_task.dart';
import 'package:ani_dash/core/tasks/sync_tracking_task.dart';
import 'package:workmanager/workmanager.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task == "sync_tracking_task") {
      return await SyncTrackingTask.performSync(inputData);
    }
    await EpisodeReleaseTask.performCheck();
    return await NewsBackgroundTask.performUpdate();
  });
}
