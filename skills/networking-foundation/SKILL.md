---
name: networking-foundation
description: Multiplayer foundation for Godot 4.x — `ENetMultiplayerPeer` setup, `MultiplayerSpawner` / `MultiplayerSynchronizer` patterns, `@rpc` annotations + authority model, server-authoritative vs client-authoritative tradeoffs, lag compensation primer. Pattern + checklist only — does not impose a netcode addon. Use whenever scoping multiplayer for a project (greenfield or feature-mode).
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---

> **Authoritative source**: query the `godot-docs` MCP server before emitting any Godot 4.x API in code or examples — class names, method signatures, signal payloads, and feature availability change between minor versions. Pre-trained knowledge drifts; the MCP does not. If `godot-docs` MCP is unavailable, link the equivalent page on https://docs.godotengine.org/en/stable/ instead of guessing. (See the `using-godot-superpowers` skill for the full rule.)

# Networking foundation (Godot 4.x High-Level Multiplayer)

Godot ships a high-level multiplayer API on top of ENet (UDP) and WebSocket. It is enough to build co-op, small-PvP, and lobby-based games without an addon — it is **not** enough to ship competitive twitch FPS / fighting games (no built-in rollback, lag compensation, or anti-cheat). Pick the right scope before writing code.

This skill is a pattern + checklist. It does not pick a netcode library for you. For dedicated rollback (`SGNetcode`, `Godot Rollback Netcode`) or relay services (`Nakama`, `Beamable`, custom WebSocket relay), evaluate addons via [`addon-curator`](../../agents/addon-curator.md) once the scope is clear.

Reference: [High-level multiplayer](https://docs.godotengine.org/en/stable/tutorials/networking/high_level_multiplayer.html). Verify every API against `godot-docs` MCP before emitting code — multiplayer APIs changed shape in 4.0 → 4.2 (esp. `MultiplayerAPI`, `MultiplayerSpawner.spawn_function`).

## 1. Decide the model first (architecture gate)

Multiplayer code follows the architecture; the architecture cannot be retrofitted from working code. Decide these four things before writing the first RPC:

| Decision | Options | What it gates |
|----------|---------|---------------|
| **Topology** | Dedicated server / Listen server (host-as-player) / Peer-to-peer (mesh) | Cheating surface, hosting cost, NAT requirements |
| **Authority** | Server-authoritative / Client-authoritative / Distributed (per-entity) | Where game state lives; who can lie |
| **Synchronization style** | State sync (replicate transforms/properties) / Input sync (replicate inputs, simulate deterministically) | Determinism budget; rollback feasibility |
| **Transport** | ENet (UDP, fastest, NAT-traversal hassle) / WebSocket (TCP, browser-friendly) / WebRTC (P2P, JS signalling) | Platform reach (web/mobile/desktop) |

Defaults that fit ~80% of indie multiplayer:

- **Listen server** topology — one player hosts, others join. No dedicated infrastructure.
- **Server-authoritative** with **state sync** — server owns ground truth, clients replicate. Cheating is bounded.
- **ENet** for desktop, **WebSocket** for browser builds. Pick one per build target.

If the game is a competitive PvP shooter / fighter, stop here and adopt rollback netcode (separate addon). The patterns below cover everything else.

## 2. Project setup

`project.godot`:

```ini
[network]
limits/debugger/max_chars_per_second=32768
limits/debugger/max_queued_messages=2048
```

Reserve two collision-layer bits for `NetworkOwned` / `NetworkRemote` if the game distinguishes locally-controlled from replicated bodies. Layer assignment lives in [`setup-collision-layers`](../setup-collision-layers/SKILL.md).

## 3. Peer setup — host / join

```gdscript
# autoload/network_manager.gd  — registered as autoload "Net".
extends Node
## Owns the MultiplayerPeer and emits high-level lifecycle signals.
## All connection lifecycle goes through this singleton.

const PORT := 7777
const MAX_PEERS := 4

signal hosted(port: int)
signal joined
signal join_failed(reason: String)
signal peer_connected(peer_id: int)
signal peer_disconnected(peer_id: int)
signal server_disconnected


func _ready() -> void:
    multiplayer.peer_connected.connect(func(id): peer_connected.emit(id))
    multiplayer.peer_disconnected.connect(func(id): peer_disconnected.emit(id))
    multiplayer.connected_to_server.connect(func(): joined.emit())
    multiplayer.connection_failed.connect(func(): join_failed.emit("connection refused"))
    multiplayer.server_disconnected.connect(func(): server_disconnected.emit())


func host_game(port: int = PORT) -> Error:
    var peer := ENetMultiplayerPeer.new()
    var err := peer.create_server(port, MAX_PEERS)
    if err != OK:
        return err
    multiplayer.multiplayer_peer = peer
    hosted.emit(port)
    return OK


func join_game(address: String, port: int = PORT) -> Error:
    var peer := ENetMultiplayerPeer.new()
    var err := peer.create_client(address, port)
    if err != OK:
        return err
    multiplayer.multiplayer_peer = peer
    return OK


func leave() -> void:
    if multiplayer.multiplayer_peer != null:
        multiplayer.multiplayer_peer.close()
        multiplayer.multiplayer_peer = null


func is_host() -> bool:
    return multiplayer.is_server()


func local_id() -> int:
    return multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 0
```

Authority rule: `multiplayer.is_server()` returns `true` only for the host. Never trust a client to claim it is the server.

## 4. RPC (`@rpc` annotation)

Every RPC must declare four things in the annotation: who can call, reliability, channel, and target. Reference: [`@rpc` annotation](https://docs.godotengine.org/en/stable/classes/class_%40gdscript.html#class-gdscript-annotation-rpc). Verify the exact keyword set against your Godot version via `godot-docs` MCP — keyword names changed in 4.0 → 4.0.x.

```gdscript
class_name PlayerController
extends CharacterBody2D


# Server-authoritative damage. Only the server may call this.
# Clients see the result via state sync, not via RPC.
@rpc("authority", "call_local", "reliable")
func apply_damage(amount: float) -> void:
    health = max(0.0, health - amount)
    if health <= 0.0:
        die()


# Client-to-server: a player requests an action.
# `any_peer` allows any client to call; the server validates.
@rpc("any_peer", "call_remote", "reliable")
func request_use_ability(ability_id: int) -> void:
    if not multiplayer.is_server():
        return    # only the server processes
    var caller := multiplayer.get_remote_sender_id()
    if not _can_use(caller, ability_id):
        return    # silently ignore invalid request
    _perform_ability(caller, ability_id)


# Unreliable, broadcast: cosmetic-only — fine to drop a packet.
@rpc("authority", "call_local", "unreliable_ordered", 1)
func broadcast_emote(emote_id: int) -> void:
    $EmoteAnimator.play(emote_id)
```

Annotation reference (verify with `godot-docs`):

| Keyword | Effect |
|---------|--------|
| `authority` | Only the node's authority (default: server) may invoke remotely |
| `any_peer` | Any peer may invoke; server-side code must validate |
| `call_local` | RPC executes on the caller too (run side-effects on server when server invokes) |
| `call_remote` | RPC executes only on the receiver (default) |
| `reliable` | TCP-style: guaranteed delivery + ordering, expensive |
| `unreliable` | UDP fire-and-forget, may drop |
| `unreliable_ordered` | UDP, may drop, but late packets are discarded (good for state) |
| `<channel int>` | Independent ordering channel; use 0 for default, 1+ for parallel streams |

Authority is per-node: `set_multiplayer_authority(peer_id)` reassigns. Default authority is `1` (the host). Do not change authority from a regular RPC — only the current authority may transfer.

## 5. State replication — `MultiplayerSynchronizer`

For every property that needs to replicate (position, rotation, animation state, health, …), add a `MultiplayerSynchronizer` node and configure its **Replication Config** resource. The synchronizer reads listed properties on the authority and pushes them to other peers at a configurable rate.

```
Player (CharacterBody2D, authority = the player's peer_id)
├── Sprite2D
├── HealthComponent (health: float)
├── AnimationPlayer
├── MultiplayerSynchronizer (config: res://net/player_sync.tres)
└── MultiplayerSpawner (only on server, spawns more)
```

`res://net/player_sync.tres` (a `SceneReplicationConfig`):

| Property | Replicate | Watch |
|----------|-----------|-------|
| `Player:position`               | always | per-frame |
| `Player:velocity`               | always | per-frame |
| `Sprite2D:flip_h`               | always | on-change |
| `HealthComponent:current_health` | always | on-change |
| `AnimationPlayer:current_animation` | spawn + on-change | on-change |

Configure the resource via the Synchronizer's editor inspector. Setting it programmatically:

```gdscript
var sync_config := SceneReplicationConfig.new()
sync_config.add_property("Player:position")
sync_config.property_set_replication_mode("Player:position", SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
sync_config.property_set_watch_mode("Player:position", SceneReplicationConfig.WATCH_MODE_PER_FRAME)
$MultiplayerSynchronizer.replication_config = sync_config
```

Verify the exact `SceneReplicationConfig` API against `godot-docs` MCP — the property/watch enums changed shape in 4.2.

## 6. Spawning networked entities — `MultiplayerSpawner`

Replicating a node from the server to all clients without each client manually instantiating it: use `MultiplayerSpawner`. Reference: [Synchronizing game start](https://docs.godotengine.org/en/stable/tutorials/networking/high_level_multiplayer.html#synchronizing-game-start).

```gdscript
# Setup once on the host. The spawner watches a parent node;
# every child added on the authority is replicated to all peers.
@onready var spawner: MultiplayerSpawner = $MultiplayerSpawner
@onready var players_root: Node = $Players


func _ready() -> void:
    spawner.spawn_path = players_root.get_path()
    spawner.add_spawnable_scene("res://scenes/player.tscn")
    if multiplayer.is_server():
        Net.peer_connected.connect(_spawn_player)
        _spawn_player(1)    # spawn host's own player


func _spawn_player(peer_id: int) -> void:
    var p := preload("res://scenes/player.tscn").instantiate()
    p.name = str(peer_id)    # important: stable name = stable NodePath across peers
    p.set_multiplayer_authority(peer_id)
    players_root.add_child(p, true)    # `true` = use ready name
```

Stable naming rule: every networked node MUST have a name that is identical on every peer (use peer_id as `name`). The synchronizer matches by NodePath; mismatched names break replication silently.

## 7. Input layer (server-authoritative input)

Client gathers input → sends to server via `any_peer` RPC → server simulates → state syncs back. The local player sees the result one round-trip later. Acceptable for slow-paced games; jarring for twitch.

Mitigation patterns (in increasing complexity):

1. **Input prediction**: client applies its own movement immediately, server corrects on mismatch. Implement only if the round-trip ping is consistently > 60ms in your target deployment.
2. **Lag compensation (rewind)**: server stores past states (1–2 seconds) and rewinds when validating shots. Implement only for hit detection.
3. **Rollback**: deterministic simulation + state restore + replay. **Adopt an addon** for this — implementing from scratch in GDScript is a multi-month project.

## 8. Lobby + matchmaking primer

Godot has no built-in lobby system. Two options:

- **Direct IP**: simplest. Host shares IP/port; peers join. Works for friends on a LAN or with port forwarding. Add an in-game IP entry field.
- **Relay / matchmaking service**: [Steam](https://godotsteam.com/) (Steamworks SDK wrapper), [Nakama](https://heroiclabs.com/) (open-source backend), [EOS](https://github.com/3ddelano/epic-online-services-godot), or a custom WebSocket signalling server. All of these are addons; pick via `addon-curator`.

Either way, abstract behind `Net` — never let scene scripts know whether the underlying transport is direct ENet, Steam relay, or WebSocket.

## 9. Common pitfalls (and the fix)

| Bug | Cause | Fix |
|-----|-------|-----|
| RPC fires on caller too unexpectedly | `call_local` set | Use `call_remote` if the caller should not run the body |
| Position jitters on remote peers | `position` replicated `unreliable` per-frame on a fast mover | Switch to `unreliable_ordered`; consider client-side interpolation |
| Same player spawns twice on a late-joining peer | Late-joiner missed the spawn RPC | Use `MultiplayerSpawner` (replays for late joiners) instead of manual spawn RPCs |
| Authority "drifts" — server sees client moving but client doesn't | `set_multiplayer_authority` not called on spawn | Set authority **immediately after instantiate, before `add_child`** |
| `get_remote_sender_id()` returns `0` outside an RPC | Called outside RPC body | Capture sender id in the RPC body and pass it down |
| Client crashes when host disconnects | No `server_disconnected` handler | Listen on `multiplayer.server_disconnected` and route back to main menu |
| Host sees its own RPC twice | RPC has both `call_local` AND a manual `func()` call | Pick one — let the RPC handle local execution OR call the function directly, not both |
| Web build fails to connect | ENet does not work in browser | Use `WebSocketMultiplayerPeer` for the web target; gate by `OS.has_feature("web")` |

## 10. Pre-multiplayer checklist (before writing the first RPC)

- [ ] Architecture decided (topology, authority, sync style, transport) and recorded in the GDD.
- [ ] Threat model written: what does a malicious client gain? What is the server-authoritative validation surface?
- [ ] Latency budget set: target ping for the deployment region (LAN: 1–10ms; same-region internet: 30–80ms; cross-region: 150ms+).
- [ ] Determinism boundary defined: does physics need to be deterministic? Is `Engine.physics_ticks_per_second` fixed? Are `randf()` seeds synced?
- [ ] Test plan: how will you simulate latency / packet loss / peer disconnect during dev? (`tc qdisc` on Linux, [Clumsy](https://jagt.github.io/clumsy/) on Windows, [Network Link Conditioner](https://developer.apple.com/download/more/?=Additional%20Tools) on macOS.)
- [ ] Save / load behavior under a partial connection: what happens if the host saves but a client desynced 10 seconds ago?

## When NOT to use this skill

- Local couch co-op only (split-screen, shared keyboard) → no multiplayer API needed; use [`setup-input-map`](../setup-input-map/SKILL.md) device assignment.
- Async multiplayer (turn-based via REST API, leaderboards) → no `MultiplayerPeer`; use `HTTPRequest` and a normal backend.
- The user wants rollback netcode out of the box → adopt a rollback addon via `addon-curator`; this skill's patterns are state-sync, not rollback.

## See also

- [High-level multiplayer](https://docs.godotengine.org/en/stable/tutorials/networking/high_level_multiplayer.html) — official tutorial
- [`setup-collision-layers`](../setup-collision-layers/SKILL.md) — for `NetworkOwned` / `NetworkRemote` layer assignments
- [`save-schema-migration`](../save-schema-migration/SKILL.md) — multiplayer game saves often add a `host_peer_id` field; bump the schema when introducing it
- [`addon-curator`](../../agents/addon-curator.md) — pick the relay / matchmaking / rollback addon once the architecture is decided
