import 'package:http/http.dart' as http;

/// Web branch of [createPlatformHttpClient]: plain browser HTTP client.
///
/// `cronet_http` (via `jni`) and `cupertino_http` (via `objective_c`) both
/// depend on `dart:ffi`, which does not exist on the web target — so even a
/// factory that would never *call* those clients breaks the web build if the
/// imports are unconditional. This stub keeps the plugin-free `http` package,
/// which compiles everywhere.
http.Client createPlatformHttpClient() => http.Client();
