// ============================================================================
// PixelArtImporter.cs — Unity Editor AssetPostprocessor
// Drop into: Assets/Editor/PixelArtImporter.cs
//
// Automatically configures any PNG imported under Assets/Sprites/ with:
//   - Filter Mode: Point (no filter)
//   - Compression: None
//   - Pixels Per Unit: 32
//   - Sprite Mode: Single
//   - Read/Write: Enabled (for tilemap slicing if needed)
//
// Also creates a Tile asset alongside each imported sprite.
// ============================================================================
using UnityEditor;
using UnityEngine;

public class PixelArtImporter : AssetPostprocessor
{
    private const string SpritesFolder = "Assets/Sprites/";
    private const int PixelsPerUnit = 32;

    private void OnPreprocessTexture()
    {
        if (!assetPath.StartsWith(SpritesFolder))
            return;
        if (!assetPath.EndsWith(".png", System.StringComparison.OrdinalIgnoreCase))
            return;

        TextureImporter importer = (TextureImporter)assetImporter;

        importer.textureType = TextureImporterType.Sprite;
        importer.spriteImportMode = SpriteImportMode.Single;
        importer.spritePixelsPerUnit = PixelsPerUnit;
        importer.filterMode = FilterMode.Point;
        importer.textureCompression = TextureImporterCompression.Uncompressed;
        importer.isReadable = true;
        importer.mipmapEnabled = false;
        importer.wrapMode = TextureWrapMode.Clamp;
        importer.alphaIsTransparency = true;

        // Override platform defaults to ensure no compression
        TextureImporterPlatformSettings platformSettings = importer.GetDefaultPlatformTextureSettings();
        platformSettings.format = TextureImporterFormat.RGBA32;
        platformSettings.textureCompression = TextureImporterCompression.Uncompressed;
        importer.SetPlatformTextureSettings(platformSettings);

        Debug.Log($"[PixelArtImporter] Configured: {assetPath} (Point filter, no compression, PPU {PixelsPerUnit})");
    }

    private static void OnPostprocessAllAssets(
        string[] importedAssets,
        string[] deletedAssets,
        string[] movedAssets,
        string[] movedFromAssetPaths)
    {
        foreach (string assetPath in importedAssets)
        {
            if (!assetPath.StartsWith(SpritesFolder))
                continue;
            if (!assetPath.EndsWith(".png", System.StringComparison.OrdinalIgnoreCase))
                continue;

            CreateTileAsset(assetPath);
        }
    }

    private static void CreateTileAsset(string spritePath)
    {
        // Load the sprite from the imported texture
        Sprite sprite = AssetDatabase.LoadAssetAtPath<Sprite>(spritePath);
        if (sprite == null)
            return;

        // Build tile asset path: Assets/Sprites/foo.png -> Assets/Tiles/foo.asset
        string relativePath = spritePath.Substring(SpritesFolder.Length);
        string nameWithoutExt = System.IO.Path.ChangeExtension(relativePath, null);
        string tileDir = "Assets/Tiles/" + System.IO.Path.GetDirectoryName(relativePath);
        string tilePath = "Assets/Tiles/" + nameWithoutExt + ".asset";

        // Ensure Tiles directory exists
        if (!AssetDatabase.IsValidFolder("Assets/Tiles"))
            AssetDatabase.CreateFolder("Assets", "Tiles");

        // Create subdirectories if the sprite was in a subfolder
        string[] parts = tileDir.Split('/');
        string current = parts[0];
        for (int i = 1; i < parts.Length; i++)
        {
            string next = current + "/" + parts[i];
            if (!string.IsNullOrEmpty(parts[i]) && !AssetDatabase.IsValidFolder(next))
                AssetDatabase.CreateFolder(current, parts[i]);
            current = next;
        }

        // Skip if tile already exists
        if (AssetDatabase.LoadAssetAtPath<UnityEngine.Tilemaps.Tile>(tilePath) != null)
            return;

        // Create the Tile asset
        var tile = ScriptableObject.CreateInstance<UnityEngine.Tilemaps.Tile>();
        tile.sprite = sprite;
        tile.color = Color.white;
        tile.colliderType = UnityEngine.Tilemaps.Tile.ColliderType.Sprite;

        AssetDatabase.CreateAsset(tile, tilePath);
        AssetDatabase.SaveAssets();

        Debug.Log($"[PixelArtImporter] Created tile: {tilePath}");
    }
}
