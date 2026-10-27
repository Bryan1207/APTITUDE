class_name AptitudeAct1Run
extends RefCounted

## One local run, one selected hero. Encounter results persist across map nodes.
## Map geometry is deterministic for a seed; a fresh run selects a fresh seed.
## Multiplayer network authority will be built separately.

const FLOOR_COUNT := 15
const LANES := 9
const HERO_IDS := ["bryan", "carlos", "manny", "cristian_hb"]
const STARTER_DECK := ["attack", "attack", "attack", "attack", "attack",
    "block", "block", "block", "block", "demon"]

var seed: int = 0
var rng := RandomNumberGenerator.new()
var floors: Array = []
var boss: Dictionary = {}
var hero_id: String = ""
var deck: Array = []
var hp: int = 60
var max_hp: int = 60
var coins: int = 0
var current_floor: int = -1
var current_node_id: String = ""
var current_kind: String = ""
var state: String = "inactive"
var visited: Array[String] = []
var encounters_cleared: int = 0

func start_new(chosen_hero: String, starting_max_hp: int = 60, requested_seed: int = -1) -> void:
    if not HERO_IDS.has(chosen_hero):
        push_error("Unknown hero: " + chosen_hero)
        return
    hero_id = chosen_hero
    max_hp = maxi(1, starting_max_hp)
    hp = max_hp
    coins = 0
    deck = STARTER_DECK.duplicate()
    current_floor = -1
    current_node_id = ""
    current_kind = ""
    state = "map"
    visited.clear()
    encounters_cleared = 0
    seed = requested_seed if requested_seed >= 0 else randi_range(1, 2147483647)
    rng.seed = seed
    _generate_map()

func _node_id(floor_index: int, lane: int) -> String:
    return "%02d_%d" % [floor_index, lane]

func _kind_for(floor_index: int, lane: int) -> String:
    if floor_index == 0:
        # Three real choices on floor 1, without forcing one opening fight.
        var opening: Array = ["combat", "combat", "event"]
        return str(opening[(lane + int(seed % 3)) % 3])
    var roll: int = rng.randi_range(0, 99)
    if floor_index == FLOOR_COUNT - 1:
        return "rest" if roll < 27 else ("elite" if roll < 52 else "combat")
    if roll < 48:
        return "combat"
    if roll < 62:
        return "event"
    if roll < 74:
        return "shop"
    if roll < 88:
        return "rest"
    return "elite"

## Irregular deterministic topology: first sample non-uniform node positions,
## then connect each floor in both directions (no orphaned nodes).
## Connections always move exactly one floor, never skip an encounter.
func _pick_lanes(amount: int) -> Array[int]:
    var pool: Array[int] = []
    for lane in range(LANES):
        pool.append(lane)
    for i in range(pool.size() - 1, 0, -1):
        var swap_index: int = rng.randi_range(0, i)
        var temp: int = pool[i]
        pool[i] = pool[swap_index]
        pool[swap_index] = temp
    var chosen: Array[int] = []
    for i in range(amount):
        chosen.append(pool[i])
    chosen.sort()
    return chosen

func _nearest(nodes: Array, lane: int) -> Dictionary:
    var closest: Dictionary = nodes[0]
    var distance: int = absi(int(closest["lane"]) - lane)
    for candidate in nodes:
        var candidate_distance: int = absi(int(candidate["lane"]) - lane)
        if candidate_distance < distance:
            closest = candidate
            distance = candidate_distance
    return closest

func _has_edge(source: Dictionary, target: Dictionary) -> bool:
    return (source["next"] as Array).has(str(target["id"]))

func _edge_crosses(row: Array, source: Dictionary, target: Dictionary) -> bool:
    var a: int = int(source["lane"])
    var b: int = int(target["lane"])
    for other in row:
        var c: int = int(other["lane"])
        for connected_id in other["next"]:
            var connected: Dictionary = node_by_id(str(connected_id))
            var d: int = int(connected["lane"])
            # Shared source and shared target are legal; other crossings aren't.
            if a < c and b > d:
                return true
            if a > c and b < d:
                return true
    return false

func _try_edge(row: Array, source: Dictionary, target: Dictionary) -> bool:
    if _has_edge(source, target):
        return true
    if _edge_crosses(row, source, target):
        return false
    (source["next"] as Array).append(str(target["id"]))
    return true

func _generate_map() -> void:
    floors.clear()
    # Start with exactly three options; following rows fluctuate between 2 and 5.
    for level in range(FLOOR_COUNT):
        var row: Array = []
        var node_count: int = 3 if level == 0 else rng.randi_range(2, 5)
        var columns: Array[int] = _pick_lanes(node_count)
        for lane in columns:
            row.append({
                "id": _node_id(level, lane),
                "floor": level,
                "lane": lane,
                "jitter": rng.randf_range(-11.0, 11.0),
                "kind": _kind_for(level, lane),
                "next": []
            })
        floors.append(row)

    for level in range(FLOOR_COUNT - 1):
        var row: Array = floors[level]
        var following: Array = floors[level + 1]
        # Every existing node must have an outgoing connection.
        for source in row:
            var closest: Dictionary = _nearest(following, int(source["lane"]))
            (source["next"] as Array).append(str(closest["id"]))
        # Every new node needs an incoming route so all nodes are reachable.
        for target in following:
            var closest_source: Dictionary = _nearest(row, int(target["lane"]))
            _try_edge(row, closest_source, target)
        # Add bounded extra branching/merging without crisscrossed wires.
        for source in row:
            if rng.randf() > 0.50:
                continue
            var nearest_node: Dictionary = _nearest(following, int(source["lane"]))
            var closest_index: int = following.find(nearest_node)
            var step: int = -1 if rng.randf() < 0.5 else 1
            var alternative: int = closest_index + step
            if alternative >= 0 and alternative < following.size():
                _try_edge(row, source, following[alternative])

    boss = {"id":"alextron_boss", "floor":FLOOR_COUNT,
        "lane":LANES / 2, "jitter":0.0, "kind":"boss", "next":[]}
    for node in floors[FLOOR_COUNT - 1]:
        node["next"] = [str(boss["id"])]

func node_by_id(id: String) -> Dictionary:
    if id == str(boss.get("id", "")):
        return boss
    for row in floors:
        for node in row:
            if str(node["id"]) == id:
                return node
    return {}

func available_nodes() -> Array:
    if state != "map":
        return []
    if current_floor < 0:
        return floors[0].duplicate()
    if current_floor == FLOOR_COUNT - 1:
        return [boss]
    if current_floor >= FLOOR_COUNT:
        return []
    var current: Dictionary = node_by_id(current_node_id)
    if current.is_empty():
        return []
    var next_row: Array = []
    for next_id in current["next"]:
        var node: Dictionary = node_by_id(str(next_id))
        if not node.is_empty():
            next_row.append(node)
    return next_row

func choose_node(id: String) -> bool:
    if state != "map":
        return false
    var chosen: Dictionary = {}
    for node in available_nodes():
        if str(node["id"]) == id:
            chosen = node
            break
    if chosen.is_empty():
        return false
    current_node_id = str(chosen["id"])
    current_floor = int(chosen["floor"])
    current_kind = str(chosen["kind"])
    visited.append(current_node_id)
    match current_kind:
        "combat", "elite", "boss":
            state = "battle"
        "rest", "shop", "event":
            state = current_kind
        _:
            push_error("Invalid map node type: " + current_kind)
            return false
    return true

func encounter_id() -> String:
    match current_kind:
        "elite":
            return "city_duo_test"
        "boss":
            return "alextron_boss"
        _:
            return "city_intro"

func combat_options() -> Dictionary:
    return {"hero_hp":hp, "hero_max_hp":max_hp, "coins":coins,
        "deck":deck.duplicate(), "apply_passives":true, "scale_for_party":true}

func finish_battle(result_hp: int, result_max_hp: int, result_coins: int, victory: bool) -> bool:
    if state != "battle":
        return false
    max_hp = maxi(1, result_max_hp)
    hp = clampi(result_hp, 0, max_hp)
    coins = maxi(0, result_coins)
    if not victory or hp <= 0:
        state = "defeat"
        return true
    encounters_cleared += 1
    state = "complete" if current_kind == "boss" else "reward"
    return true

func claim_reward(reward_id: String) -> bool:
    if state != "reward":
        return false
    match reward_id:
        "attack":
            deck.append("attack")
        "block":
            deck.append("block")
        "repair":
            hp = mini(max_hp, hp + 8)
        _:
            return false
    state = "map"
    return true

func resolve_node(choice: String) -> bool:
    match state:
        "rest":
            if choice == "heal":
                hp = mini(max_hp, hp + 12)
            elif choice == "upgrade":
                max_hp += 5
                hp += 5
            else:
                return false
        "event":
            if choice == "salvage":
                coins += 20
            elif choice == "repair":
                hp = mini(max_hp, hp + 8)
            else:
                return false
        "shop":
            if choice == "leave":
                pass
            elif choice == "heal" and coins >= 20:
                coins -= 20
                hp = mini(max_hp, hp + 15)
            elif choice == "upgrade" and coins >= 30:
                coins -= 30
                max_hp += 5
                hp += 5
            else:
                return false
        _:
            return false
    state = "map"
    return true

func floor_label() -> String:
    if current_floor < 0:
        return "Starting paths"
    if current_floor == FLOOR_COUNT:
        return "Boss"
    return "Floor %d / %d" % [current_floor + 1, FLOOR_COUNT]
