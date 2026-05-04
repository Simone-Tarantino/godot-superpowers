---
name: setup-collision-layers
description: Configure Godot 4.x physics collision layers and masks for 2D and 3D — sensible 11-layer scheme for player, enemies, environment, projectiles, pickups, triggers, hurtboxes, hitboxes. Edits project.godot.
allowed-tools: Read, Write, Edit
---

# Setup Collision Layers

Configures **Project Settings → Layer Names → 2D Physics** and **3D Physics** with a battle-tested 11-layer scheme that supports clean hurtbox/hitbox separation.

## The scheme

| Bit | Name | Used by | Masks (collides with) |
|-----|------|---------|----------------------|
| 1 | World | StaticBody2D/3D, TileMapLayer, terrain | (passive — bodies on this layer don't actively scan) |
| 2 | Player | CharacterBody2D/3D player | World, Enemy, Pickup, Trigger |
| 3 | Enemy | Enemy CharacterBody / RigidBody | World, Player, EnemyHurtbox |
| 4 | PlayerProjectile | Bullets / abilities owned by player | World, Enemy, EnemyHurtbox |
| 5 | EnemyProjectile | Bullets / abilities owned by enemies | World, Player, PlayerHurtbox |
| 6 | Pickup | Coins, items, powerups | Player |
| 7 | Trigger | Area-based events, doors, checkpoints | Player (also Enemy if needed) |
| 8 | PlayerHurtbox | Area on player that takes damage | EnemyHitbox, EnemyProjectile |
| 9 | PlayerHitbox | Area on player that deals damage | EnemyHurtbox |
| 10 | EnemyHurtbox | Area on enemy that takes damage | PlayerHitbox, PlayerProjectile |
| 11 | EnemyHitbox | Area on enemy that deals damage | PlayerHurtbox |

**Hitbox rule:** a hitbox sits on **its own** layer and masks the **opposing** hurtbox layer. Never the reverse.

## Apply to `project.godot`

Append (or merge into existing `[layer_names]` section):

```ini
[layer_names]

2d_physics/layer_1="World"
2d_physics/layer_2="Player"
2d_physics/layer_3="Enemy"
2d_physics/layer_4="PlayerProjectile"
2d_physics/layer_5="EnemyProjectile"
2d_physics/layer_6="Pickup"
2d_physics/layer_7="Trigger"
2d_physics/layer_8="PlayerHurtbox"
2d_physics/layer_9="PlayerHitbox"
2d_physics/layer_10="EnemyHurtbox"
2d_physics/layer_11="EnemyHitbox"

3d_physics/layer_1="World"
3d_physics/layer_2="Player"
3d_physics/layer_3="Enemy"
3d_physics/layer_4="PlayerProjectile"
3d_physics/layer_5="EnemyProjectile"
3d_physics/layer_6="Pickup"
3d_physics/layer_7="Trigger"
3d_physics/layer_8="PlayerHurtbox"
3d_physics/layer_9="PlayerHitbox"
3d_physics/layer_10="EnemyHurtbox"
3d_physics/layer_11="EnemyHitbox"
```

## Helper constants (optional but recommended)

Add `scripts/collision_layers.gd`:

```gdscript
class_name CollisionLayers
extends RefCounted

## Bit constants for layer set/get via code. Use as flags:
##     hitbox.collision_layer = CollisionLayers.PLAYER_HITBOX
##     hitbox.collision_mask = CollisionLayers.ENEMY_HURTBOX

const WORLD := 1 << 0
const PLAYER := 1 << 1
const ENEMY := 1 << 2
const PLAYER_PROJECTILE := 1 << 3
const ENEMY_PROJECTILE := 1 << 4
const PICKUP := 1 << 5
const TRIGGER := 1 << 6
const PLAYER_HURTBOX := 1 << 7
const PLAYER_HITBOX := 1 << 8
const ENEMY_HURTBOX := 1 << 9
const ENEMY_HITBOX := 1 << 10
```

## Configuration cheatsheet for common nodes

| Node | `collision_layer` | `collision_mask` |
|------|-------------------|------------------|
| Player CharacterBody | Player | World, Enemy, Pickup, Trigger |
| Enemy CharacterBody | Enemy | World, Player |
| Wall / floor StaticBody | World | (none) |
| Player bullet | PlayerProjectile | World, Enemy, EnemyHurtbox |
| Enemy bullet | EnemyProjectile | World, Player, PlayerHurtbox |
| Coin Area | Pickup | (none — Player's mask handles it) |
| Door trigger Area | Trigger | (none) |
| Player Hurtbox Area | PlayerHurtbox | EnemyHitbox, EnemyProjectile |
| Player Hitbox Area (sword) | PlayerHitbox | EnemyHurtbox |
| Enemy Hurtbox Area | EnemyHurtbox | PlayerHitbox, PlayerProjectile |
| Enemy Hitbox Area (claw) | EnemyHitbox | PlayerHurtbox |

## Debugging

Enable **Debug → Visible Collision Shapes** while running. Color collisions to verify layer / mask combinations are correct.

If hits don't register:
1. Verify both shapes have `monitoring = true` (Areas) or appropriate physics setup
2. Confirm layer/mask: emitter on its own layer, mask = receiver's layer
3. Check shapes overlap visually (debug drawing on)
4. For Areas: check `monitorable = true` on the receiver
