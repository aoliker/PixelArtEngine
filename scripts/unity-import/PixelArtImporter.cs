// ============================================================================
// PixelArtImporter.cs — Unity Editor AssetPostprocessor
// Drop into: Assets/Editor/PixelArtImporter.cs
//
// Automatically configures any PNG imported under Assets/Sprites/ with:
//   - Filter Mode: Point (no filter)
//   - Compression: None
//   - Pixels Per Unit: 32 for tiles/characters, 16 for icons
//   - Sprite Mode: Single
//   - Read/Write: Enabled (for tilemap slicing if needed)
//   - Pivot: Bottom-center for characters, Center for tiles/icons
//
// Also creates a Tile asset for tile_ prefixed sprites.
// ============================================================================
using UnityEditor;
using UnityEngine;

public class PixelArtImporter : AssetPostprocessor
{
    private const string SpritesFolder = "Assets/Sprites/";

    // PPU per style guide: 32 for tiles/characters, 16 for icons
    private const int TilePPU = 32;
    private const int IconPPU = 16;

    private void OnPreprocessTexture()
    {
        if (!assetPath.StartsWith(SpritesFolder))
            return;
        if (!assetPath.EndsWith(".png", System.StringComparison.OrdinalIgnoreCase))
            return;

        TextureImporter importer = (TextureImporter)assetImporter;
        string filename = System.IO.Path.GetFileNameWithoutExtension(assetPath).ToLowerInvariant();

        // Determine PPU and pivot based on asset type (by filename prefix or folder)
        bool isIcon = filename.StartsWith("icon_") || filename.StartsWith("item_")
            || assetPath.Contains("/Icons/") || assetPath.Contains("/Items/");
        bool isCharacter = filename.StartsWith("char_") || filename.StartsWith("npc_")
            || filename.StartsWith("enemy_") || filename.StartsWith("player_")
            || assetPath.Contains("/Characters/") || assetPath.Contains("/Enemies/");

        int ppu = isIcon ? IconPPU : TilePPU;

        // Pivot: bottom-center (0.5, 0) for characters, center (0.5, 0.5) for tiles/icons
        Vector2 pivot = isCharacter ? new Vector2(0.5f, 0f) : new Vector2(0.5f, 0.5f);

        importer.textureType = TextureImporterType.Sprite;
        importer.spriteImportMode = SpriteImportMode.Single;
        importer.spritePixelsPerUnit = ppu;
        importer.spritePivot = pivot;
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

        string type = isIcon ? "icon" : isCharacter ? "character" : "tile";
        Debug.Log($"[PixelArtImporter] Configured: {assetPath} ({type}, Point filter, no compression, PPU {ppu})");
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

            // Only create Tile assets for tile-prefixed sprites
            string fname = System.IO.Path.GetFileNameWithoutExtension(assetPath).ToLowerInvariant();
            if (fname.StartsWith("tile_") || assetPath.Contains("/Tiles/"))
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
