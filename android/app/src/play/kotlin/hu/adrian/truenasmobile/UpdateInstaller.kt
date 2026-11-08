package hu.adrian.truenasmobile

import android.app.Activity
import io.flutter.embedding.engine.FlutterEngine

/**
 * The Google Play build does not update itself (Play only allows its own
 * updater), so there is no installer channel, no REQUEST_INSTALL_PACKAGES
 * permission and no update FileProvider here. The `github` flavor has the real
 * one under the same name.
 */
object UpdateInstaller {
    @Suppress("UNUSED_PARAMETER")
    fun register(activity: Activity, flutterEngine: FlutterEngine) = Unit
}
