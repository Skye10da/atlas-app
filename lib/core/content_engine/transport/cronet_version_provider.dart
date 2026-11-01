/// Platform split for [CronetVersionProvider].
///
/// `cronet_http` reaches `dart:ffi` through `jni`, which does not exist on the
/// web target, so the Cronet-backed implementation must be behind a
/// conditional import. On web the stub keeps the same API and always returns
/// `null`.
library;

export 'package:atlas_app/core/content_engine/transport/cronet_version_provider_io.dart'
    if (dart.library.js_interop) 'package:atlas_app/core/content_engine/transport/cronet_version_provider_stub.dart';
