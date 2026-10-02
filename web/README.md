# Browser runtime files

`sqlite3.wasm` and `sqflite_sw.js` were generated with the locked `sqflite_common_ffi_web` package using:

```sh
dart run sqflite_common_ffi_web:setup --force
```

Regenerate them when updating the SQLite web driver. The wasm binary is supplied by [sqlite3.dart](https://github.com/simolus3/sqlite3.dart/releases); the worker is built by [sqflite_common_ffi_web](https://pub.dev/packages/sqflite_common_ffi_web). Keep these files at the web app's base URL. Both metadata and reference images persist locally in the browser's IndexedDB database.

See the project README for browser startup and limitations.
