# Keep JNI / reflection-heavy plugin classes that R8 would otherwise strip.

# audio_service (MediaBrowserServiceCompat, MethodChannel reflection)
-keep class com.ryanheise.audioservice.** { *; }

# flutter_tts (MethodChannel reflection)
-keep class com.eyedeadevelopment.fluttertts.** { *; }

# sqlite3_flutter_libs (JNI bridge)
-keep class eu.simonbinder.sqlite3_flutter_libs.** { *; }

# pdfium_flutter native loading (no Java classes but guard FFI entry points)
-keep class com.tomr.jasper.** { *; }
