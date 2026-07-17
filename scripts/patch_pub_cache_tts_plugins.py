"""
scripts/patch_pub_cache_tts_plugins.py

v1.12.3-alpha-exp2 P0 diagnostic: patch flutter_tts + audio_session in
pub-cache to defer system-service binding from onAttachedToEngine to
first method call.

WHY
===
v1.12.2-alpha-exp.apk still crashed on the user's Chinese ROM device
(Huawei/Xiaomi/OPPO/vivo class, Android 12+). Elimination:
- v1.11.6-alpha (pre-TTS, no flutter_tts/audio_service/audio_session)
  works on the same device.
- v1.12.0-alpha (adds 3 packages) crashes.
- v1.12.1-alpha (lazy-init audio_service in main()) crashes.
- v1.12.2-alpha-exp (strip audio_service manifest + remove main.dart
  audio calls) STILL crashes.

Code inspection + flutter_tts GitHub issue #640 ("Adding flutter_tts
as a dependency crashes the application before Dart main() on some
machines") point to plugin attach-time work:

  1. flutter_tts FlutterTtsPlugin.initInstance() calls
     `tts = TextToSpeech(context, onInitListenerWithoutCallback)`
     inside onAttachedToEngine → binds to the system TTS service
     BEFORE main(). Chinese ROMs may kill the process at this stage
     for "background service binding during cold start".
  2. audio_session AndroidAudioManager ctor → Singleton ctor →
     `registerAudioDeviceCallback()` on attach → enumerates audio
     devices BEFORE main().

Patch strategy: defer the system-binding calls to first method call.
The plugins' existing async architecture (pendingMethodCalls queue
in flutter_tts, lazy Singleton fields in audio_session) handles the
wait gracefully.

USAGE
=====
Run after `flutter pub get` if pub-cache has been reset.

    python scripts/patch_pub_cache_tts_plugins.py

Exit codes:
  0  All patches applied successfully.
  1  Patch target version not found in pub-cache (version drift).
  2  Patch already applied (idempotent skip).

Idempotent: detects the "v1.12.3-alpha-exp2 P0" marker comment and
skips files already patched.
"""
import os
import sys

PUB_CACHE = os.path.join(
    os.environ.get('LOCALAPPDATA', r'C:\Users\1\AppData\Local'),
    'Pub', 'Cache', 'hosted', 'pub.dev')

MARKER = 'v1.12.3-alpha-exp2 P0'


def _patch_file(path, original, patched, label):
    if not os.path.exists(path):
        print(f"SKIP {label}: file not found at {path}")
        print(f"      (version drift — update this script for new version)")
        sys.exit(1)
    with open(path, 'rb') as f:
        text = f.read().decode('utf-8')
    if MARKER in text:
        print(f"SKIP {label}: already patched (idempotent)")
        return
    if original not in text:
        print(f"FAIL {label}: original block not found")
        print(f"      (code structure changed — update this script)")
        sys.exit(1)
    text = text.replace(original, patched, 1)
    with open(path, 'wb') as f:
        f.write(text.encode('utf-8'))
    print(f"OK   {label}: {path}")


def patch_flutter_tts():
    path = os.path.join(
        PUB_CACHE, 'flutter_tts-4.2.5', 'android', 'src', 'main',
        'kotlin', 'com', 'eyedeadevelopment', 'fluttertts',
        'FlutterTtsPlugin.kt')
    original = """    private fun initInstance(messenger: BinaryMessenger, context: Context) {
        this.context = context
        methodChannel = MethodChannel(messenger, "flutter_tts")
        methodChannel!!.setMethodCallHandler(this)
        handler = Handler(Looper.getMainLooper())
        bundle = Bundle()
        tts = TextToSpeech(context, onInitListenerWithoutCallback)
    }"""
    patched = """    private fun initInstance(messenger: BinaryMessenger, context: Context) {
        this.context = context
        methodChannel = MethodChannel(messenger, "flutter_tts")
        methodChannel!!.setMethodCallHandler(this)
        handler = Handler(Looper.getMainLooper())
        bundle = Bundle()
        // v1.12.3-alpha-exp2 P0: defer TextToSpeech construction to first
        // method call. Constructing here binds to the system TTS service
        // during GeneratedPluginRegistrant.registerWith() (BEFORE main()),
        // which Chinese ROMs kill as "background service binding on cold
        // start". See onMethodCall lazy-init guard.
    }

    /// v1.12.3-alpha-exp2 P0: lazy-init tts on first method call. The
    /// existing pendingMethodCalls queue (synchronized on ttsStatus==null)
    /// handles the async wait for TextToSpeech.OnInitListener.
    private fun ensureTts() {
        if (tts == null && context != null) {
            tts = TextToSpeech(context!!, onInitListenerWithoutCallback)
        }
    }"""
    _patch_file(path, original, patched, 'flutter_tts initInstance')

    # Patch onMethodCall to lazy-init tts
    with open(path, 'rb') as f:
        text = f.read().decode('utf-8')
    original_mc = """    override fun onMethodCall(call: MethodCall, result: Result) {
        // If TTS is still loading
        synchronized(this@FlutterTtsPlugin) {"""
    patched_mc = """    override fun onMethodCall(call: MethodCall, result: Result) {
        // v1.12.3-alpha-exp2 P0: lazy-init TextToSpeech on first method
        // call instead of onAttachedToEngine. Avoids system TTS service
        // binding during FlutterEngine init (which Chinese ROMs kill).
        ensureTts()
        // If TTS is still loading
        synchronized(this@FlutterTtsPlugin) {"""
    if original_mc in text:
        text = text.replace(original_mc, patched_mc, 1)
        with open(path, 'wb') as f:
            f.write(text.encode('utf-8'))
        print(f"OK   flutter_tts onMethodCall: {path}")
    else:
        print(f"SKIP flutter_tts onMethodCall: already patched or signature changed")

    # Patch onDetachedFromEngine safe-call
    with open(path, 'rb') as f:
        text = f.read().decode('utf-8')
    original_detach = """    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        stop()
        tts!!.shutdown()"""
    patched_detach = """    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        stop()
        // v1.12.3-alpha-exp2 P0: tts may be null if no method call ever
        // occurred (lazy init never triggered).
        tts?.shutdown()"""
    if original_detach in text:
        text = text.replace(original_detach, patched_detach, 1)
        with open(path, 'wb') as f:
            f.write(text.encode('utf-8'))
        print(f"OK   flutter_tts onDetachedFromEngine: {path}")
    else:
        print(f"SKIP flutter_tts onDetachedFromEngine: already patched or signature changed")


def patch_audio_session():
    path = os.path.join(
        PUB_CACHE, 'audio_session-0.1.25', 'android', 'src', 'main',
        'java', 'com', 'ryanheise', 'audio_session',
        'AndroidAudioManager.java')
    original_ctor = """        public Singleton(Context applicationContext) {
            this.applicationContext = applicationContext;
            audioManager = (AudioManager)applicationContext.getSystemService(Context.AUDIO_SERVICE);
            if (Build.VERSION.SDK_INT >= 23) {
                initAudioDeviceCallback();
            }
        }"""
    patched_ctor = """        public Singleton(Context applicationContext) {
            this.applicationContext = applicationContext;
            audioManager = (AudioManager)applicationContext.getSystemService(Context.AUDIO_SERVICE);
            // v1.12.3-alpha-exp2 P0: defer AudioDeviceCallback registration
            // to first requestAudioFocus call. Registering here would
            // enumerate audio devices during GeneratedPluginRegistrant
            // (BEFORE main()), which Chinese ROMs kill. audioDeviceCallback
            // is now initialized lazily inside requestAudioFocus.
        }

        /// v1.12.3-alpha-exp2 P0: lazy-init audio device callback on first
        /// audio focus request. The callback's purpose is routing changes
        /// (headphone plug/unplug), which only matters while audio is
        /// active. No-op until first focus request.
        private void ensureAudioDeviceCallback() {
            if (audioDeviceCallback == null && Build.VERSION.SDK_INT >= 23) {
                initAudioDeviceCallback();
            }
        }"""
    _patch_file(path, original_ctor, patched_ctor, 'audio_session Singleton ctor')

    with open(path, 'rb') as f:
        text = f.read().decode('utf-8')
    original_focus = """        public boolean requestAudioFocus(List<?> args) {
            if (audioFocusRequest != null) {
                return true;
            }"""
    patched_focus = """        public boolean requestAudioFocus(List<?> args) {
            // v1.12.3-alpha-exp2 P0: lazy-init audio device callback here.
            ensureAudioDeviceCallback();
            if (audioFocusRequest != null) {
                return true;
            }"""
    if original_focus in text:
        text = text.replace(original_focus, patched_focus, 1)
        with open(path, 'wb') as f:
            f.write(text.encode('utf-8'))
        print(f"OK   audio_session requestAudioFocus: {path}")
    else:
        print(f"SKIP audio_session requestAudioFocus: already patched or signature changed")


if __name__ == '__main__':
    print(f"Patching pub-cache at: {PUB_CACHE}")
    print(f"Marker: {MARKER}")
    print()
    patch_flutter_tts()
    patch_audio_session()
    print()
    print("All patches applied. Rebuild APK to pick up changes.")
