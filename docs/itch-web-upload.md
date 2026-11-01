# Web release

Upload `build/cleared-for-release-web.zip` to the existing itch.io project.

- Kind of project: HTML.
- Mark the ZIP as "This file will be played in the browser".
- Enable Click to Play and the fullscreen button; disable scrollbars.
- Suggested embedded size: 1152 x 648. Fullscreen is recommended for reading.
- SharedArrayBuffer / cross-origin isolation is not required: this build uses the single-threaded Web template.
- Do not mark Mobile Friendly until touch input and small-screen reading have been tested.

The ZIP must have `index.html` at its root alongside all exported files. Do not upload the source project or only the HTML file.

## Rebuild

Install the matching Godot 4.7.2 export templates. This machine has the official single-threaded Web debug and release templates installed.

Run Godot with `--headless --path . --editor --export-release Web build/web/index.html`, then ZIP the contents of `build/web` (not the enclosing folder).

The preset exports game resources and excludes tests, tools, documents, marketing images, comparison scenes and unused WAV music drafts. Web rendering uses Compatibility; streamed audio retains the explosion bus filters. Browser audio should be checked after clicking to start.

## Verification

- Release export succeeded.
- Browser smoke check: opening dialogue, the desk/document view and clicking a marked span to black it out.
- ZIP root, file sizes and CRC checked against itch.io's archive limits.
- Full seven-letter browser playthrough, Safari, mobile devices and an actual itch.io-hosted session are not yet verified.
