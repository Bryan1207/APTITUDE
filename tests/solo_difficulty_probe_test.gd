extends SceneTree
## Deterministic, normal-HP Act 1 difficulty telemetry. No balance changes.
## Unlike the 5000-HP full-route test, these runs can lose legitimately.
const RunScript = preload("res://scripts/act1_run.gd")
const CombatScript = preload("res://scripts/combat_engine.gd")
const HERO_IDS := ["bryan", "carlos", "manny", "cristian_hb"]
const SEEDS := [64217, 1729, 531, 2026, 8123, 99173]
# The original combat-first baseline is unchanged. Recovery chooses reachable
# healing routes and the existing repair reward when health is low.
const POLICIES := ["combat_first", "recovery"]
var failures: int = 0

func _initialize() -> void:
    for owner in HERO_IDS:
        for policy in POLICIES:
            var gates: int = 0
            var floors_total: int = 0
            var samples: int = 0
            for seed in SEEDS:
                var first: Dictionary = _play_route(owner, seed, policy)
                var replay: Dictionary = _play_route(owner, seed, policy)
                _check(not first.is_empty(), owner + " " + policy + " seed " + str(seed) + " completed a valid probe")
                _check(first == replay, owner + " " + policy + " seed " + str(seed) + " is reproducible")
                if not first.is_empty():
                    gates += 1 if first["outcome"] == "boss_gate" else 0
                    floors_total += int(first["floor"])
                    samples += 1
                    print("DIFFICULTY: %s policy=%s seed=%d outcome=%s floor=%d wins=%d turns=%d hp=%d coins=%d cards=%d" % [
                        owner, policy, seed, first["outcome"], first["floor"], first["wins"],
                        first["turns"], first["hp"], first["coins"], first["cards"]])
            if samples > 0:
                print("DIFFICULTY_SUMMARY: %s policy=%s boss_gates=%d/%d mean_floor=%.2f" % [
                    owner, policy, gates, samples, float(floors_total) / float(samples)])
    if failures == 0:
        print("PASS: six-seed 60-HP combat-first and recovery probes are reproducible and preserve run state")
    else:
        push_error("FAIL: %d solo difficulty probe assertions" % failures)
    quit(1 if failures > 0 else 0)

func _check(ok: bool, description: String) -> void:
    if ok:
        print("OK: " + description)
    else:
        failures += 1
        push_error("FAIL: " + description)

func _fail(description: String) -> Dictionary:
    _check(false, description)
    return {}

func _play_route(owner: String, seed: int, policy: String) -> Dictionary:
    var run: AptitudeAct1Run = RunScript.new()
    run.start_new(owner, 60, seed)
    if run.hp != 60 or run.deck.size() != 10:
        return _fail(owner + " did not start with 60 HP and the ten-card deck")
    var wins: int = 0
    var cards_earned: int = 0
    var total_turns: int = 0
    for floor_index in range(15):
        var choices: Array = run.available_nodes()
        if choices.is_empty():
            return _fail(owner + " has no reachable node on floor " + str(floor_index + 1))
        var chosen: Dictionary = choices[0]
        # Prefer combat to sample the real enemy roster and earned card economy.
        for node in choices:
            if str(node["kind"]) == "combat" or str(node["kind"]) == "elite":
                chosen = node
                break
        # Only choose from the currently connected nodes. This policy
        # deliberately does not look ahead or inspect hidden encounters.
        if policy == "recovery" and run.hp <= 45:
            for kind in ["rest", "event", "shop"]:
                if kind == "shop" and (run.coins < 20 or run.hp > 40):
                    continue
                var found: bool = false
                for node in choices:
                    if str(node["kind"]) == kind:
                        chosen = node
                        found = true
                        break
                if found:
                    break
        if not run.choose_node(str(chosen["id"])):
            return _fail(owner + " could not enter a connected node")
        if run.state == "battle":
            var fight: AptitudeCombatEngine = CombatScript.new()
            fight.start([owner], run.encounter_id(), run.combat_options())
            var hero: Dictionary = fight.hero_by_id(owner)
            if int(hero["hp"]) != run.hp or int(hero["max_hp"]) != run.max_hp or fight.coins != run.coins:
                return _fail(owner + " lost persisted HP or coins entering combat")
            var turns: int = 0
            while fight.phase == "player" and turns < 80:
                var actions: int = 0
                while fight.phase == "player" and actions < 25:
                    var index: int = -1
                    var target: String = owner
                    for preferred_type in ["power", "attack", "skill"]:
                        for i in range((hero["hand"] as Array).size()):
                            var card_id: String = str(hero["hand"][i])
                            if not fight.cards.has(card_id):
                                return _fail(owner + " drew an unknown card: " + card_id)
                            var card: Dictionary = fight.cards[card_id]
                            if str(card["type"]) != preferred_type or int(card["cost"]) > int(hero["energy"]):
                                continue
                            target = owner
                            if fight.card_target_type(card) == "enemy":
                                var found_enemy: bool = false
                                for enemy in fight.enemies:
                                    if int(enemy["hp"]) > 0:
                                        target = str(enemy["id"])
                                        found_enemy = true
                                        break
                                if not found_enemy:
                                    continue
                            index = i
                            break
                        if index >= 0:
                            break
                    if index < 0:
                        break
                    var error: String = fight.submit_card(owner, index, target)
                    if error != "":
                        return _fail(owner + " rejected a playable card: " + error)
                    actions += 1
                if fight.phase == "player":
                    fight.mark_done(owner)
                turns += 1
            total_turns += turns
            if fight.phase != "victory" and fight.phase != "defeat":
                return _fail(owner + " stalled without victory or defeat")
            var victory: bool = fight.phase == "victory"
            if not run.finish_battle(int(hero["hp"]), int(hero["max_hp"]), fight.coins, victory):
                return _fail(owner + " failed to persist a real combat outcome")
            if run.hp != int(hero["hp"]) or run.coins != fight.coins:
                return _fail(owner + " lost combat state on return to run")
            if not victory:
                if run.state != "defeat" or not run.available_nodes().is_empty():
                    return _fail(owner + " defeat left the map or rewards accessible")
                return _summary("defeat", floor_index + 1, wins, total_turns, run)
            wins += 1
            if run.state != "reward" or run.reward_options.size() != 3:
                return _fail(owner + " victory did not offer three card rewards")
            var reward: String = "repair" if policy == "recovery" and run.hp <= 38 else str(run.reward_options[0])
            if not run.claim_reward(reward):
                return _fail(owner + " could not claim a reward")
            if reward != "repair":
                cards_earned += 1
            if run.deck.size() != 10 + cards_earned:
                return _fail(owner + " reward deck does not match acquired cards")
        else:
            var choice: String = "salvage" if run.state == "event" else (
                "heal" if run.state == "rest" else "leave")
            if policy == "recovery":
                if run.state == "event" and run.hp <= 50:
                    choice = "repair"
                elif run.state == "shop" and run.hp <= 40 and run.coins >= 20:
                    choice = "heal"
            if not run.resolve_node(choice):
                return _fail(owner + " could not resolve a noncombat floor")
        if run.state != "map" or run.current_floor != floor_index:
            return _fail(owner + " did not return to the correct map floor")
    var boss_options: Array = run.available_nodes()
    if boss_options.size() != 1 or str(boss_options[0]["id"]) != "alextron_boss":
        return _fail(owner + " did not reach the reserved boss gate")
    # Do not select or simulate the user-reserved boss.
    return _summary("boss_gate", 15, wins, total_turns, run)

func _summary(outcome: String, floor_reached: int, wins: int, turns: int, run: AptitudeAct1Run) -> Dictionary:
    return {"outcome":outcome, "floor":floor_reached, "wins":wins, "turns":turns,
        "hp":run.hp, "coins":run.coins, "cards":run.deck.size()}
