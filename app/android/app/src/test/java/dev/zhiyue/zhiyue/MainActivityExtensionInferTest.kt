package dev.zhiyue.zhiyue

import android.net.Uri
import org.junit.Assert.assertEquals
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/// v1.14.0-alpha T1: verifies that MainActivity infers the source file's
/// extension from a content:// or file:// URI, replacing the old hard-coded
/// ".book" suffix that broke BookFormatDetector's EPUB detection.
///
/// Note: the MIME-type fallback path exists in [MainActivity.inferExtensionFromUriForTest]
/// but is not covered here. Constructing a real android.content.ContentResolver
/// subclass for Robolectric is fiddly (abstract class with package-private
/// constructor) and the path-based inference is the actual fix for the
/// user-reported deep-link bug (file managers always expose the original
/// filename via lastPathSegment). MIME fallback is a defensive belt-and-
/// braces for the rare case where lastPathSegment has no extension.
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class MainActivityExtensionInferTest {

    private val activity = MainActivity()

    @Test
    fun `inferExtension takes dot-epub from lastPathSegment`() {
        val uri = Uri.parse("content://media/external/file/123/%E4%B8%89%E4%BD%93.epub")
        assertEquals(".epub", activity.inferExtensionFromUriForTest(uri))
    }

    @Test
    fun `inferExtension takes dot-pdf from lastPathSegment`() {
        val uri = Uri.parse("content://media/external/file/456/report.pdf")
        assertEquals(".pdf", activity.inferExtensionFromUriForTest(uri))
    }

    @Test
    fun `inferExtension returns empty when lastPathSegment has no extension`() {
        val uri = Uri.parse("content://media/external/file/123")
        assertEquals("", activity.inferExtensionFromUriForTest(uri))
    }

    @Test
    fun `inferExtension returns empty for unsupported extension like docx`() {
        val uri = Uri.parse("content://x/y/z.docx")
        assertEquals("", activity.inferExtensionFromUriForTest(uri))
    }
}
