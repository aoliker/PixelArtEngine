// ============================================================================
// TilePaletteBuilder.cs — Unity Editor tool
// Drop into: Assets/Editor/TilePaletteBuilder.cs
//
// Menu: ScarForge > Rebuild Tile Palette
// Scans Assets/Tiles/ for Tile assets and adds any missing tiles to the
// project's default tile palette (creates one if it doesn't exist).
// ============================================================================
using System.Collections.Generic;
using System.IO;
using UnityEditor;
using UnityEngine;
using UnityEngine.Tilemaps;

public class TilePaletteBuilder : EditorWindow
{
    private const string TilesRoot = "Assets/Tiles";
    private const string PaletteDir = "Assets/Palettes";
    private const string DefaultPaletteName = "ScarForge_Palette";

    private Vector2 scrollPos;
    private List<TileBase> foundTiles = new List<TileBase>();
    private bool scanned = false;

    [MenuItem("ScarForge/Tile Palette Builder")]
    public static void ShowWindow()
    {
        GetWindow<TilePaletteBuilder>("Tile Palette Builder");
    }

    private void OnGUI()
    {
        GUILayout.Label("ScarForge Tile Palette Builder", EditorStyles.boldLabel);
        GUILayout.Space(5);

        if (GUILayout.Button("Scan for Tiles"))
        {
            ScanTiles();
        }

        if (scanned)
        {
            GUILayout.Label($"Found {foundTiles.Count} tile(s) in {TilesRoot}/");
            GUILayout.Space(5);

            scrollPos = EditorGUILayout.BeginScrollView(scrollPos, GUILayout.Height(300));
            foreach (var tile in foundTiles)
            {
                EditorGUILayout.ObjectField(tile, typeof(TileBase), false);
            }
            EditorGUILayout.EndScrollView();

            GUILayout.Space(10);

            if (GUILayout.Button("Add All to Palette"))
            {
                AddTilesToPalette();
            }
        }
    }

    private void ScanTiles()
    {
        foundTiles.Clear();
        string[] guids = AssetDatabase.FindAssets("t:TileBase", new[] { TilesRoot });
        foreach (string guid in guids)
        {
            string path = AssetDatabase.GUIDToAssetPath(guid);
            TileBase tile = AssetDatabase.LoadAssetAtPath<TileBase>(path);
            if (tile != null)
                foundTiles.Add(tile);
        }
        scanned = true;
    }

    [MenuItem("ScarForge/Rebuild Tile Palette")]
    public static void RebuildPalette()
    {
        // Quick-action: scan and add all in one step
        string[] guids = AssetDatabase.FindAssets("t:TileBase", new[] { TilesRoot });
        if (guids.Length == 0)
        {
            Debug.Log("[TilePaletteBuilder] No tiles found in " + TilesRoot);
            return;
        }

        List<TileBase> tiles = new List<TileBase>();
        foreach (string guid in guids)
        {
            string path = AssetDatabase.GUIDToAssetPath(guid);
            TileBase tile = AssetDatabase.LoadAssetAtPath<TileBase>(path);
            if (tile != null)
                tiles.Add(tile);
        }

        AddTilesToPaletteStatic(tiles);
    }

    private void AddTilesToPalette()
    {
        AddTilesToPaletteStatic(foundTiles);
    }

    private static void AddTilesToPaletteStatic(List<TileBase> tiles)
    {
        // Ensure palette directory exists
        if (!AssetDatabase.IsValidFolder(PaletteDir))
            AssetDatabase.CreateFolder("Assets", "Palettes");

        string palettePrefabPath = PaletteDir + "/" + DefaultPaletteName + ".prefab";

        GameObject paletteGO;
        bool isNew = false;

        // Load or create the palette prefab
        GameObject existing = AssetDatabase.LoadAssetAtPath<GameObject>(palettePrefabPath);
        if (existing != null)
        {
            paletteGO = PrefabUtility.InstantiatePrefab(existing) as GameObject;
        }
        else
        {
            paletteGO = new GameObject(DefaultPaletteName);
            var grid = paletteGO.AddComponent<Grid>();
            grid.cellSize = new Vector3(1, 1, 0);

            var tilemapGO = new GameObject("Layer1");
            tilemapGO.transform.SetParent(paletteGO.transform);
            tilemapGO.AddComponent<Tilemap>();
            tilemapGO.AddComponent<TilemapRenderer>();
            isNew = true;
        }

        // Get or add the Tilemap on the first child
        Tilemap tilemap = paletteGO.GetComponentInChildren<Tilemap>();
        if (tilemap == null)
        {
            Debug.LogError("[TilePaletteBuilder] Palette prefab has no Tilemap component.");
            Object.DestroyImmediate(paletteGO);
            return;
        }

        // Place tiles in a grid layout
        // First, collect existing positions to avoid duplicates
        HashSet<TileBase> existingTiles = new HashSet<TileBase>();
        BoundsInt bounds = tilemap.cellBounds;
        foreach (Vector3Int pos in bounds.allPositionsWithin)
        {
            TileBase t = tilemap.GetTile(pos);
            if (t != null)
                existingTiles.Add(t);
        }

        // Find next available position
        int columns = 8;
        int nextIndex = 0;
        foreach (Vector3Int pos in bounds.allPositionsWithin)
        {
            if (tilemap.GetTile(pos) != null)
                nextIndex++;
        }

        int added = 0;
        foreach (TileBase tile in tiles)
        {
            if (existingTiles.Contains(tile))
                continue;

            int x = nextIndex % columns;
            int y = -(nextIndex / columns); // grow downward
            tilemap.SetTile(new Vector3Int(x, y, 0), tile);
            nextIndex++;
            added++;
        }

        // Save the prefab
        if (isNew)
        {
            PrefabUtility.SaveAsPrefabAsset(paletteGO, palettePrefabPath);
        }
        else
        {
            PrefabUtility.ApplyPrefabInstance(paletteGO, InteractionMode.AutomatedAction);
        }

        Object.DestroyImmediate(paletteGO);
        AssetDatabase.SaveAssets();
        AssetDatabase.Refresh();

        Debug.Log($"[TilePaletteBuilder] Added {added} new tile(s) to palette. Total in palette: {nextIndex}");
    }
}
