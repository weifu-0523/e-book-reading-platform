package dev.zhiyue.zhiyue

import android.content.ActivityNotFoundException
import android.content.Context
import android.content.ContextWrapper
import android.content.Intent
import android.provider.Settings
import androidx.test.core.app.ApplicationProvider
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config

/// v1.14.0-alpha T5: verifies that MainActivity launches
/// ACTION_MANAGE_DEFAULT_APPS_SETTINGS so the user can manually set
/// ZhiYue as the .epub handler (Android does not allow apps to self-
/// register as default; the user must flip the switch in system
/// settings).
///
/// The production handler lives on the `dev.zhiyue.bookopen`
/// MethodChannel. These tests exercise [MainActivity.openDefaultAppsSettingsForTest],
/// a VisibleForTesting seam that takes a Context parameter so we can
/// inject a ContextWrapper that throws ActivityNotFoundException to
/// exercise the failure path (very old ROMs without the settings page).
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class DefaultAppsSettingsLauncherTest {

    @Test
    fun `openDefaultAppsSettings launches correct intent`() {
        val activity = MainActivity()
        val context = ApplicationProvider.getApplicationContext<Context>()
        val launched = activity.openDefaultAppsSettingsForTest(context)
        assertTrue(launched)

        val shadowActivity = shadowOf(activity)
        val intent = shadowActivity.nextStartedActivity
        assertEquals(Settings.ACTION_MANAGE_DEFAULT_APPS_SETTINGS, intent.action)
    }

    @Test
    fun `openDefaultAppsSettings returns false when startActivity throws`() {
        val activity = MainActivity()
        // Inject a context that throws on startActivity to simulate old ROMs
        // where ACTION_MANAGE_DEFAULT_APPS_SETTINGS does not resolve.
        val throwingContext = object : ContextWrapper(
            ApplicationProvider.getApplicationContext()) {
            override fun startActivity(intent: Intent) {
                throw ActivityNotFoundException("forced for test")
            }
        }
        val launched = activity.openDefaultAppsSettingsForTest(throwingContext)
        assertFalse(launched)
    }
}
