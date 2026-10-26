`test_cert.pem` and `test_key.pem` are a throwaway self-signed certificate
for `localhost`, used only by the TLS pinning tests. They protect nothing.

`widget_shaping.json` holds raw answers of a TrueNAS server and the JSON the
home screen widgets must make of them. The Dart shaping
(`test/core/widgets/widget_shaping_test.dart`) and the Swift one
(`tools/check-widget-shaping.sh`, run on macOS CI) are both held to it.
