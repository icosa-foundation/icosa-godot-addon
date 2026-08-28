# Open Brush glTF support

The addon registers a `GLTFDocumentExtension` while the Icosa Gallery plugin is enabled. It recognizes Tilt Brush and Open Brush generator metadata and replaces exported materials with the matching Godot brush resources.

## Supported inputs

1. Legacy `.gltf` and `.glb` exports whose generator identifies them as Tilt Brush or Open Brush files.
2. `.gltf` and `.glb` files produced by Open Brush UnityGLTF Exporter v2. The importer normalizes exporter-specific vertex data and applies the source settings required by the Godot brush shaders.
3. Open Brush environment, sky, and light metadata when the export includes supported metadata.

Direct `.tilt` importing is not part of this addon. Export the sketch to glTF or GLB before importing it into Godot. UnityGLTF support is currently validated against the v2 export layout.

## Material handling

1. Brush names and durable GUIDs are mapped to resources under `brush_materials/`.
2. Particle brushes reconstruct billboard centers, rotation, and timing data during glTF import.
3. Ribbon brushes preserve the additional vertex data required by their shaders.
4. Selected cutout brushes use alpha-scissor or alpha-to-coverage handling to reduce hard aliased edges.
5. Missing brush mappings retain the imported material and produce a warning.

## Usage

1. Enable the **Icosa Gallery** plugin before adding the glTF or GLB file to the project, so the Open Brush import extension is registered.
2. If the file was imported before the plugin was enabled, reimport it from the Godot FileSystem dock.
3. Instantiate the imported scene normally. Material replacement and supported environment metadata are applied during import.
