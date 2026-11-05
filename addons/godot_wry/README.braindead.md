# Bundled Godot WRY runtime

Godot WRY v1.0.2, distributed under the MIT license (see `LICENSE`).
Only the extension manifest, icon, and upstream desktop runtime binaries are included.
The manifest disables extension hot reload because this upstream Rust binding does
not support class reloading in Godot 4.7. Runtime binaries are unmodified.

- Project: https://github.com/doceazedo/godot_wry
- Release: https://github.com/doceazedo/godot_wry/releases/tag/v1.0.2
- Archive: https://github.com/doceazedo/godot_wry/releases/download/v1.0.2/godot_wry.zip
- Archive SHA-256: `706B407ACA47DF0626DF26997A3E825A49C91985A199CEAD3D0B75D35FCA783C`

Windows uses the installed Microsoft Edge WebView2 Runtime. macOS uses WebKit;
Linux needs WebKitGTK. The extension currently supports desktop platforms only.
The Windows x64 build is the locally verified target for this project.
