package dev.zhiyue.zhiyue.tts

import android.content.Context
import android.speech.tts.TextToSpeech
import android.speech.tts.Voice
import androidx.test.core.app.ApplicationProvider
import org.junit.After
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.shadows.ShadowTextToSpeech
import java.util.Locale

/// v1.14.0-alpha T4: voice selection handlers (getVoices / setVoice /
/// handleSpeak voiceId application). Runs against Robolectric's
/// [ShadowTextToSpeech], which exposes a static [ShadowTextToSpeech.addVoice]
/// registry that the production `tts.voices` reads through. We reset the
/// shadow between tests so voice registrations from one test don't leak
/// into another (the shadow's voices list is process-global).
///
/// Note on `isDefault`: Robolectric's ShadowTextToSpeech has no setter for
/// the engine default voice, so we use [ZhiYueTtsService.defaultVoiceNameOverrideForTest]
/// to simulate "engine reports voice X as default". Production code leaves
/// that field null and falls back to `tts.defaultVoice?.name`.
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class ZhiYueTtsServiceVoiceTest {

    /// Construct a Service with an Application context attached so framework
    /// APIs that touch ContextWrapper.mBase (e.g. TextToSpeech) work.
    /// Mirrors the helper in [ZhiYueTtsServiceTest].
    private fun createService(): ZhiYueTtsService {
        val service = ZhiYueTtsService()
        val ctx = ApplicationProvider.getApplicationContext<Context>()
        val wrapperClass = service.javaClass.superclass?.superclass
        val method = wrapperClass?.getDeclaredMethod("attachBaseContext", Context::class.java)
            ?: error("Could not locate ContextWrapper.attachBaseContext via reflection")
        method.isAccessible = true
        method.invoke(service, ctx)
        return service
    }

    /// Build a service whose TextToSpeech has been initialized and reports
    /// the given [voices]. Uses [ShadowTextToSpeech.addVoice] (process-global
    /// registry) so production `tts.voices` returns them.
    ///
    /// @param voices voices to register with ShadowTextToSpeech
    /// @param defaultVoiceName voice name the engine reports as default.
    ///     Null means "engine reports no default" (production behavior when
    ///     `tts.defaultVoice` is null).
    private fun createServiceWithVoices(
        voices: Set<Voice>,
        defaultVoiceName: String? = null,
    ): ZhiYueTtsService {
        voices.forEach { ShadowTextToSpeech.addVoice(it) }
        val service = createService()
        if (defaultVoiceName != null) {
            service.defaultVoiceNameOverrideForTest = defaultVoiceName
        }
        service.onCreate()
        service.simulateTtsInitCallbackForTest(TextToSpeech.SUCCESS)
        return service
    }

    @Before
    fun resetShadow() {
        ShadowTextToSpeech.reset()
    }

    @After
    fun cleanupShadow() {
        ShadowTextToSpeech.reset()
    }

    @Test
    fun `handleGetVoices maps TextToSpeech voices to List of Map`() {
        val fakeVoices: Set<Voice> = setOf(
            Voice(
                "zh-CN-xiaoxiao",
                Locale.SIMPLIFIED_CHINESE,
                Voice.QUALITY_HIGH,
                Voice.LATENCY_NORMAL,
                false,
                emptySet(),
            ),
            Voice(
                "zh-CN-yunyang",
                Locale.SIMPLIFIED_CHINESE,
                Voice.QUALITY_HIGH,
                Voice.LATENCY_NORMAL,
                false,
                emptySet(),
            ),
        )
        val service = createServiceWithVoices(fakeVoices, defaultVoiceName = "zh-CN-xiaoxiao")

        val result = service.handleGetVoicesForTest()

        org.junit.Assert.assertEquals("voices list size", 2, result.size)
        // Shadow returns voices as a SortedSet (Voice implements Comparable),
        // so insertion order isn't guaranteed. Look up by name to keep the
        // test independent of the iteration order chosen by the shadow.
        val xiaoxiao = result.first { it["name"] == "zh-CN-xiaoxiao" }
        org.junit.Assert.assertEquals(
            "xiaoxiao id is name|locale-tag",
            "zh-CN-xiaoxiao|zh-CN",
            xiaoxiao["id"],
        )
        org.junit.Assert.assertEquals(
            "xiaoxiao locale is BCP-47 tag",
            "zh-CN",
            xiaoxiao["locale"],
        )
        org.junit.Assert.assertEquals(
            "xiaoxiao should be marked default (matches override)",
            true,
            xiaoxiao["isDefault"],
        )
        val yunyang = result.first { it["name"] == "zh-CN-yunyang" }
        org.junit.Assert.assertEquals(
            "yunyang should NOT be marked default",
            false,
            yunyang["isDefault"],
        )
        service.onDestroy()
    }

    @Test
    fun `handleSetVoice finds matching voice and applies`() {
        val fakeVoices = setOf(
            Voice(
                "zh-CN-xiaoxiao",
                Locale.SIMPLIFIED_CHINESE,
                Voice.QUALITY_HIGH,
                Voice.LATENCY_NORMAL,
                false,
                emptySet(),
            ),
        )
        val service = createServiceWithVoices(fakeVoices)

        val applied = service.handleSetVoiceForTest("zh-CN-xiaoxiao|zh-CN")

        org.junit.Assert.assertTrue("handleSetVoice should return true when match found", applied)
        org.junit.Assert.assertEquals(
            "lastAppliedVoiceName should reflect the matched voice",
            "zh-CN-xiaoxiao",
            service.lastAppliedVoiceNameForTest,
        )
        service.onDestroy()
    }

    @Test
    fun `handleSetVoice returns false when voiceId not found`() {
        val service = createServiceWithVoices(emptySet())

        val applied = service.handleSetVoiceForTest("nonexistent|zh-CN")

        org.junit.Assert.assertFalse(
            "handleSetVoice should return false when voiceId not in engine voices",
            applied,
        )
        service.onDestroy()
    }

    @Test
    fun `handleSpeak applies voiceId when present in extras`() {
        val fakeVoices = setOf(
            Voice(
                "zh-CN-xiaoxiao",
                Locale.SIMPLIFIED_CHINESE,
                Voice.QUALITY_HIGH,
                Voice.LATENCY_NORMAL,
                false,
                emptySet(),
            ),
        )
        val service = createServiceWithVoices(fakeVoices)

        // Drive the production handleSpeak path via an Intent (same as
        // real Dart→Plugin→Service flow). voiceId is piggy-backed onto
        // the SPEAK Intent's extras, mirroring how rate/pitch/volume ride
        // the same Intent (v1.13.7-alpha Bug 4).
        val speakIntent = android.content.Intent(ZhiYueTtsService.ACTION_SPEAK)
            .putExtra(ZhiYueTtsService.EXTRA_TEXT, "你好")
            .putExtra(ZhiYueTtsService.EXTRA_LOCALE, "zh-CN")
            .putExtra(ZhiYueTtsService.EXTRA_SENTENCE_INDEX, 0)
            .putExtra(ZhiYueTtsService.EXTRA_VOICE_ID, "zh-CN-xiaoxiao|zh-CN")
        service.onStartCommand(speakIntent, 0, 1)

        org.junit.Assert.assertEquals(
            "handleSpeak should apply voiceId from Intent extras",
            "zh-CN-xiaoxiao",
            service.lastAppliedVoiceNameForTest,
        )
        service.onDestroy()
    }
}
