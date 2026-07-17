package dev.zhiyue.zhiyue.tts

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/// Routes hardware media buttons (bluetooth headset play/pause/skip) to
/// [ZhiYueTtsService]'s MediaSession via the AndroidX MediaButtonReceiver
/// forwarding mechanism. T13 will register this in AndroidManifest with
/// ACTION_MEDIA_BUTTON intent-filter.
///
/// The body is intentionally empty — AndroidX MediaButtonReceiver.forwardIntent
/// routes ACTION_MEDIA_BUTTON to the active MediaSession automatically when
/// registered. This class exists mainly to declare the receiver component.
class ZhiYueTtsMediaButtonReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        // No-op: AndroidX routes via MediaSessionCompat automatically.
    }
}
