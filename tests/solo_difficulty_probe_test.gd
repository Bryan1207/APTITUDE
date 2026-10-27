extends SceneTree
## Deterministic, normal-HP Act 1 difficulty telemetry. No balance changes.
## Unlike the 5000-HP full-route test, these runs can lose legitimately.
const RunScript = preload("res://scripts/act1_run.gd")
const CombatScript = preload("res://scripts/combat_engine.gd")
const HERO_IDS := ["bryan", "carlos", "manny", "cristian_hb"]
const SEEDS := [64217, 1729, 531, 2026, 8123, 99173]
# The original combat-first baseline is unchanged. Recovery chooses reachable
# healing routes and the existing repair reward when health is low.
const POLICIES := ["combat_first", "recovery", "tactical", "tactical_draft"]
var failures: int = 0

func _initialize() -> void:
    _test_tactical_decisions()
    _test_draft_decisions()
    for owner in HERO_IDS:
        for policy in POLICIES:
            var gates: int = 0
            var floors_total: int = 0
            var samples: int = 0
            var hp_total: int = 0
            var wins_total: int = 0
            for seed in SEEDS:
                var first: Dictionary = _play_route(owner, seed, policy)
                var replay: Dictionary = _play_route(owner, seed, policy)
                _check(not first.is_empty(), owner + " " + policy + " seed " + str(seed) + " completed a valid probe")
                _check(first == replay, owner + " " + policy + " seed " + str(seed) + " is reproducible")
                if not first.is_empty():
                    gates += 1 if first["outcome"] == "boss_gate" else 0
                    floors_total += int(first["floor"])
                    hp_total += int(first["hp"])
                    wins_total += int(first["wins"])
                    samples += 1
                    print("DIFFICULTY: %s policy=%s seed=%d outcome=%s floor=%d wins=%d turns=%d hp=%d coins=%d cards=%d" % [
                        owner, policy, seed, first["outcome"], first["floor"], first["wins"],
                        first["turns"], first["hp"], first["coins"], first["cards"]])
            if samples > 0:
                print("DIFFICULTY_SUMMARY: %s policy=%s boss_gates=%d/%d mean_floor=%.2f mean_hp=%.2f mean_wins=%.2f" % [
                    owner, policy, gates, samples, float(floors_total) / float(samples),
                    float(hp_total) / float(samples), float(wins_total) / float(samples)])
    if failures == 0:
        print("PASS: six-seed 60-HP combat-first, recovery, tactical and tactical-draft probes are reproducible and preserve run state")
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
        if policy != "combat_first" and run.hp <= 45:
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
                    var tactical: Dictionary = _tactical_pick(fight, hero, owner) if policy == "tactical" or policy == "tactical_draft" else {}
                    if not tactical.is_empty():
                        index = int(tactical["index"])
                        target = str(tactical["target"])
                    if policy != "tactical" and policy != "tactical_draft":
                        for preferred_type in ["power", "attack", "skill"]:
                            for i in range((hero["hand"] as Array).size()):
                                var card_id: String = str(hero["hand"][i])
                                if not fight.cards.has(card_id):
                                    return _fail(owner + " drew an unknown card: " + card_id)
                                var card: Dictionary = fight.cards[card_id]
                                if str(card["type"]) != preferred_type or int(card["cost"]) > int(hero["energy"]):
                                    continue
                                if str(card["type"]) == "power" and (hero["powers_played"] as Array).has(card_id):
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
            var reward: String = str(run.reward_options[0])
            if policy == "tactical_draft":
                reward = _choose_draft_reward(run, fight.cards)
            elif policy != "combat_first" and run.hp <= 38:
                reward = "repair"
            if not run.claim_reward(reward):
                return _fail(owner + " could not claim a reward")
            if reward != "repair":
                cards_earned += 1
            if run.deck.size() != 10 + cards_earned:
                return _fail(owner + " reward deck does not match acquired cards")
        else:
            var choice: String = "salvage" if run.state == "event" else (
                "heal" if run.state == "rest" else "leave")
            if policy != "combat_first":
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

# A deterministic, one-action tactical evaluator for balance telemetry only.
# It does not change player combat, rewards, or the boss. It uses visible enemy
# intents, existing card definitions, energy and current health; no future draws.
func _incoming_damage(fight: AptitudeCombatEngine, hero: Dictionary) -> int:
    var total: int = 0
    var team_bonus: int = 0
    for enemy in fight.enemies:
        if int(enemy["hp"]) <= 0:
            continue
        var move: Dictionary = enemy["next_move"]
        var kind: String = str(move.get("kind", "attack"))
        if kind == "charge":
            if bool(move.get("team", false)):
                team_bonus += int(move.get("strength", 1))
            continue
        if kind == "guard":
            continue
        var amount: int = maxi(1, roundi(float(enemy["damage"]) * float(move.get("power", 1.0))))
        amount += int(enemy.get("strength", 0)) + team_bonus
        if int(enemy.get("weak", 0)) > 0:
            amount = maxi(1, roundi(float(amount) * 0.75))
        if int(hero.get("vulnerable", 0)) > 0:
            amount = maxi(1, roundi(float(amount) * 1.5))
        total += amount * maxi(1, int(move.get("hits", 1)))
    return total

func _tactical_pick(fight: AptitudeCombatEngine, hero: Dictionary, owner: String) -> Dictionary:
    var best_score: float = 0.1
    var best: Dictionary = {}
    var incoming: int = _incoming_damage(fight, hero)
    for i in range((hero["hand"] as Array).size()):
        var card_id: String = str(hero["hand"][i])
        if not fight.cards.has(card_id):
            continue
        var card: Dictionary = fight.cards[card_id]
        if int(card["cost"]) > int(hero["energy"]):
            continue
        # Drafting may add a second copy of a once-per-combat Power.
        # A visible card is not necessarily an eligible command.
        if str(card["type"]) == "power" and (hero["powers_played"] as Array).has(card_id):
            continue
        var targets: Array[String] = [owner]
        if fight.card_target_type(card) == "enemy":
            targets.clear()
            for enemy in fight.enemies:
                if int(enemy["hp"]) > 0:
                    targets.append(str(enemy["id"]))
        for target_id in targets:
            var score: float = _tactical_score(fight, hero, card, target_id, incoming)
            if score > best_score:
                best_score = score
                best = {"index":i, "target":target_id}
    return best

func _tactical_score(fight: AptitudeCombatEngine, hero: Dictionary, card: Dictionary, target_id: String, incoming: int) -> float:
    var score: float = -1.5 * float(int(card["cost"]))
    var target: Dictionary = {}
    for enemy in fight.enemies:
        if str(enemy["id"]) == target_id:
            target = enemy
            break
    var total_enemy_hp: int = 0
    for enemy in fight.enemies:
        total_enemy_hp += int(enemy["hp"])
    for effect in card["effects"]:
        var amount: int = int(effect["value"])
        match str(effect["op"]):
            "damage":
                if target.is_empty():
                    continue
                if str(card["type"]) == "attack":
                    amount += int(hero.get("strength", 0))
                    if int(hero.get("weak", 0)) > 0:
                        amount = maxi(0, roundi(float(amount) * 0.75))
                    if str(hero["id"]) == "carlos" and bool(hero.get("passives_enabled", false)) and not bool(hero.get("first_attack_used", false)):
                        amount += 1
                if int(target.get("vulnerable", 0)) > 0:
                    amount = roundi(float(amount) * 1.5)
                var effective: int = maxi(0, amount * maxi(1, int(effect.get("hits", 1))) - int(target["block"]))
                var inflicted: int = mini(int(target["hp"]), effective)
                score += 1.8 * float(inflicted)
                if inflicted >= int(target["hp"]):
                    score += 8.0
                    if not ["guard", "charge"].has(str((target["next_move"] as Dictionary).get("kind", "attack"))):
                        score += 4.0
            "block":
                var useful: int = mini(amount, maxi(0, incoming - int(hero["block"])))
                score += 1.3 * float(useful)
                if incoming >= int(hero["hp"]) + int(hero["block"]) and incoming - int(hero["block"]) - useful < int(hero["hp"]):
                    score += 14.0
            "draw":
                if not (hero["draw"] as Array).is_empty() or not (hero["discard"] as Array).is_empty():
                    score += float(amount) * (2.0 if int(hero["energy"]) > int(card["cost"]) else 0.5)
            "weak":
                if not target.is_empty() and int(target.get("weak", 0)) == 0:
                    if not ["guard", "charge"].has(str((target["next_move"] as Dictionary).get("kind", "attack"))):
                        score += 3.0 + float(amount)
            "vulnerable":
                if not target.is_empty() and int(target.get("vulnerable", 0)) == 0:
                    score += 2.0 + float(amount)
            "strength":
                score += 7.0 if total_enemy_hp > 15 else 2.0
            "plating":
                score += 5.0 if total_enemy_hp > 15 else 2.0
            "focus":
                score += 4.0 if total_enemy_hp > 15 else 1.0
            "heal":
                score += 1.4 * float(mini(amount, int(hero["max_hp"]) - int(hero["hp"])))
    return score

func _test_tactical_decisions() -> void:
    var fight: AptitudeCombatEngine = CombatScript.new()
    fight.start(["bryan"], "city_intro")
    var hero: Dictionary = fight.hero_by_id("bryan")
    hero["energy"] = 1
    hero["hand"] = ["attack", "block"]
    fight.enemies[0]["hp"] = 1
    var lethal: Dictionary = _tactical_pick(fight, hero, "bryan")
    _check(int(lethal.get("index", -1)) == 0 and str(lethal.get("target", "")) == "roboduck_1",
        "tactical policy selects a lethal attack instead of unnecessary defense")
    fight.enemies[0]["hp"] = 15
    hero["hp"] = 3
    hero["hand"] = ["attack", "bryan_lockout"]
    var survival: Dictionary = _tactical_pick(fight, hero, "bryan")
    _check(int(survival.get("index", -1)) == 1,
        "tactical policy prioritizes a lifesaving block over a nonlethal attack")
    fight.start(["bryan"], "city_duo_test")
    hero = fight.hero_by_id("bryan")
    hero["energy"] = 1
    hero["hand"] = ["attack"]
    fight.enemies[0]["hp"] = 1
    fight.enemies[1]["hp"] = 10
    var target: Dictionary = _tactical_pick(fight, hero, "bryan")
    _check(str(target.get("target", "")) == "roboduck_1",
        "tactical policy targets the finishable enemy in a multi-enemy fight")
    hero["energy"] = 2
    hero["hand"] = ["bryan_closed_circuit", "attack"]
    hero["powers_played"] = ["bryan_closed_circuit"]
    var once_only: Dictionary = _tactical_pick(fight, hero, "bryan")
    _check(int(once_only.get("index", -1)) == 1,
        "tactical policy skips Powers already played during this encounter")


# Draft policy is a test-only decision aid: it never changes actual reward
# offerings, starter decks or gameplay. Score only currently offered hero cards
# using their real effect definitions and the cards already in the run deck.
# A deterministic first-offer tie break avoids hidden randomness in probes.
func _choose_draft_reward(run: AptitudeAct1Run, card_defs: Dictionary) -> String:
    if run.hp <= 38 and run.hp < run.max_hp:
        return "repair"
    var attack_count: int = 0
    var skill_count: int = 0
    var power_count: int = 0
    for raw_id in run.deck:
        var card_id: String = str(raw_id)
        if not card_defs.has(card_id):
            continue
        match str((card_defs[card_id] as Dictionary).get("type", "")):
            "attack": attack_count += 1
            "skill": skill_count += 1
            "power": power_count += 1
    var best_id: String = ""
    var best_score: float = -100000.0
    for raw_id in run.reward_options:
        var card_id: String = str(raw_id)
        if not card_defs.has(card_id):
            continue
        var card: Dictionary = card_defs[card_id]
        if str(card.get("hero", "")) != run.hero_id:
            continue
        var score: float = -2.1 * float(int(card.get("cost", 0)))
        for raw_effect in card.get("effects", []):
            var effect: Dictionary = raw_effect
            var amount: float = float(int(effect.get("value", 0)))
            match str(effect.get("op", "")):
                "damage": score += amount * float(maxi(1, int(effect.get("hits", 1)))) * 1.2
                "block": score += amount * 0.95
                "draw": score += amount * 2.3
                "weak": score += amount * 1.8
                "vulnerable": score += amount * 1.4
                "strength": score += amount * 6.0
                "plating": score += amount * 5.5
                "focus": score += amount * 4.0
                "heal": score += amount * 1.5
        match str(card.get("type", "")):
            "attack":
                if attack_count <= 6:
                    score += 2.0
            "skill":
                if skill_count <= 5:
                    score += 2.0
            "power":
                if power_count >= 3:
                    score -= 3.0
        score -= 3.5 * float(run.deck.count(card_id))
        if score > best_score:
            best_score = score
            best_id = card_id
    return best_id if best_id != "" else "repair"

func _test_draft_decisions() -> void:
    var fight: AptitudeCombatEngine = CombatScript.new()
    var run: AptitudeAct1Run = RunScript.new()
    run.start_new("bryan", 60, 64217)
    run.reward_options = ["bryan_conduit_jab", "bryan_lockout"]
    var original_deck: Array = run.deck.duplicate()
    var pick: String = _choose_draft_reward(run, fight.cards)
    _check(pick == "bryan_lockout", "draft policy values draw-plus-block over weak damage")
    _check(run.deck == original_deck and run.reward_options.size() == 2,
        "draft evaluation does not mutate the run deck or reward offers")
    run.reward_options = ["bryan_lockout", "bryan_arc_flash"]
    for _i in range(4):
        run.deck.append("bryan_lockout")
    _check(_choose_draft_reward(run, fight.cards) == "bryan_arc_flash",
        "draft policy avoids repeatedly stacking the same card")
    run.reward_options = ["carlos_full_send", "bryan_conduit_jab"]
    _check(_choose_draft_reward(run, fight.cards) == "bryan_conduit_jab",
        "draft policy ignores cards belonging to another hero")
    run.hp = 30
    _check(_choose_draft_reward(run, fight.cards) == "repair",
        "draft policy takes guaranteed healing at critical health")
    run.hp = 60
    run.reward_options.clear()
    _check(_choose_draft_reward(run, fight.cards) == "repair",
        "draft policy safely falls back when no valid reward is offered")
