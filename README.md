# Icosa Gallery - Godot Addon

A Godot 4.7+ plugin that lets you browse the [Icosa Gallery](https://icosa.gallery), a gallery of curated 3D assets, and download ready-to-use glTF meshes without leaving the editor.

![browser2.png](docs/images/browser2.png)
![browser1.png](docs/images/browser1.png)


## Features

1. **Asset browser** – Search Icosa's catalog in multiple tabs.
2. **Account login** – Sign in with a device code to access your profile, personal uploads, and liked assets.
3. **glTF and OBJ downloads** – Queue asset files, save them in per-asset folders, and track every file in the bundle, including textures referenced by glTF files.
4. **Runtime support** – Embed the browser in a project so users can download and instantiate Icosa assets at runtime.
5. **Open Brush material replacement** – Remap materials from legacy Tilt Brush/Open Brush glTF files and Open Brush UnityGLTF v2 exports to Godot brush shaders.

## Installation

### Godot Editor
If you have Godot Editor open, go to the AssetLib and search "icosa", download and install the addon and enable it.

### Manual installation

1. Download or clone this repository.
2. Copy the `addons/icosa` folder into your project's `res://addons` directory if it is not already there.
3. Open your project in the Godot Editor.
4. In the **Project > Project Settings > Plugins** tab, enable the **Icosa Gallery** plugin.

## Usage

1. After enabling the plugin, switch to the **Icosa Gallery** main screen tab that appears alongside the 3D, 2D, and Script at the top of Godot Editor.
2. Use the **Search** tab to look for assets. Apply filters such as curated assets, formats, triangle count, and ordering to refine results.
3. Click a thumbnail to open it in its own tab, or open multiple search tabs or asset previews as needed.
4. Select an asset to queue downloads. In the editor, files are saved under `res://icosa_downloads/{asset_name}_{asset_id}` by default; runtime downloads use `user://icosa_downloads/{asset_name}_{asset_id}`. Change the destination in **Settings > Downloads**. Project-wide defaults are available under `icosa/downloads` in Project Settings.
5. Sign in through the **Login** tab to sync your Icosa account securely in a web browser. Enter the device code in a browser, then return to Godot to fetch your profile, personal uploads, and liked assets.

## Hardcoded filters

1. By default, public assets are only returned if they have Creative Commons licenses that allow remixing.
2. When the Icosa Gallery API marks a supported format as preferred, the addon downloads it. Otherwise, it chooses **glTF 2.0**, then falls back to OBJ. FBX and direct `.tilt` downloads are not supported.

## Open Brush support

See the [Open Brush support documentation](addons/icosa/open_brush/README.md) for supported exporters, material handling, and limitations.

## Developer onboarding

### Repository structure

1. `addons/icosa/plugin.gd` registers the editor interface and glTF import extensions.
2. `addons/icosa/browser/` contains the gallery browser, search, account, and download workflow.
3. `addons/icosa/open_brush/` contains Open Brush material mapping, import handling, shaders, and brush resources.
4. `test_scenes/visual_comparison_tool/` provides the reusable visual comparison interface.
5. `test_scenes/visual_comparison_cases/` contains focused scenes and reference images for visual checks.

### Local development

1. Install Godot 4.7 or newer and clone the repository.
2. Open the repository root as a Godot project:

   ```sh
   godot4 -e .
   ```

3. Make addon changes under `addons/icosa/`. Keep reusable test scenes under `test_scenes/`.
4. Run an editor initialization check to catch GDScript parse errors and plugin startup failures:

   ```sh
   godot4 --headless --editor --path . --quit
   ```

   If your Godot executable has a different name, substitute it for `godot4`.

### Visual validation

1. Use `test_scenes/visual_comparison_cases/alphaclip_aa/alphaclip_aa_visual_comparison.tscn` for alpha-clip and alpha-to-coverage changes.
2. Use `test_scenes/visual_comparison_cases/victorious_lucian/lucian_victorious_visual_comparison.tscn` for a checked-in legacy Tilt Brush glTF case.
3. For shader or material changes, include before-and-after screenshots or a short capture with the contribution.

There is no formal unit-test suite. The headless editor check and relevant visual comparison scenes are the expected minimum validation.

## Packaging and contributing

Package the addon by archiving the `addons/icosa` directory while preserving its path. Keep commits focused, avoid unrelated refactors, and describe any migration or reimport steps. Contributions are welcome via pull requests.

## License

This project is distributed under the terms of the [Apache License 2.0](LICENSE).
