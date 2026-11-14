# Bryce NPC

A custom Garry's Mod NextBot using the included Bryce player model.

## Features

- Navmesh-based NextBot movement and wandering
- Player detection with a forward vision cone and line-of-sight checks
- Short-term last-seen-position memory
- Throttled target and visibility checks to avoid scanning every coroutine tick
- Separate walk/run movement animation updates
- Health-based Colossus transformation, with an admin console command to trigger it
- Custom model and material files included in the addon
- Spawn-menu registration under **Custom NPCs**

## Installation

1. Put the entire `bryce_npc` folder in `garrysmod/addons/`.
2. Keep the folder structure intact. In particular, do not move the files out of `models/`, `materials/`, or `lua/`.
3. Start or restart the game/server and find **Bryce NPC** under **NPCs → Custom NPCs**.

The server resource script registers the custom model and material files for client downloads. The model files must remain in their original addon paths.

## Map requirements

Bryce is a NextBot and uses the map's navigation mesh for pathfinding. A map without a usable navmesh may let the entity spawn but will not allow normal path-following behavior. Use a map with a navmesh, or generate one for your map before testing.

## Configuration

Most tuning values are at the top of `lua/entities/npc_bryce/shared.lua`.

| Setting | Default | Purpose |
| --- | ---: | --- |
| `MaxHealth` | `100` | Starting and maximum health |
| `WalkSpeed` | `120` | Wandering speed |
| `RunSpeed` | `250` | Chase speed |
| `SearchRadius` | `1500` | Initial player detection range |
| `LoseTargetDistance` | `2500` | Maximum distance before dropping a target |
| `TargetFOV` | `150` | Horizontal vision cone in degrees |
| `TargetScanInterval` | `0.35` | Time between player scans |
| `VisibilityCheckInterval` | `0.12` | Time between line-of-sight checks |
| `TargetMemoryTime` | `2.5` | How long Bryce remembers a lost target |
| `AttackDamage` | `25` | Base in-game melee damage |
| `AttackDelay` | `1.0` | Minimum delay between attacks |
| `GrowthDuration` | `10` | Transformation duration |
| `GrowthScale` | `3.0` | Final model scale |

Change the values in the configuration section, save the file, and restart the map/server to apply them.

## Console command

`bryce_grow` queues the transformation for every spawned Bryce NPC. Players must be admins to run it; the server console can also run it.

## Troubleshooting

- **Bryce spawns but does not move:** check that the map has a navigation mesh.
- **The model is missing for other players:** confirm that the addon is installed on the server and that the files in `models/player/` and `materials/models/custom/` are present.
- **The spawn-menu entry is missing:** confirm the folder is installed under `garrysmod/addons/`, then restart the game/server.
- **The model animates poorly:** the model may not contain the standard walk/run activities or movement pose parameters used by the configured activities.

## Credits and assets

The addon uses the model and material files stored in this repository. Keep any third-party asset permissions and attribution with the distributed addon.
