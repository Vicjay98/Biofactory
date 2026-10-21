extends SceneTree

# Run: godot --headless --path biofactory --script res://tests/test_autonomy_progress.gd
const STEP: float = 1.0 / 60.0

var checks: int = 0
var failures: int = 0


func expect(condition: bool, message: String) -> void:
    checks += 1
    if not condition:
        failures += 1
        push_error(message)


func _initialize() -> void:
    call_deferred("run_tests")


func fixture() -> Node:
    var game = load("res://scene/main/game.tscn").instantiate()
    root.add_child(game)
    game.process_mode = Node.PROCESS_MODE_DISABLED
    game.get_node("organism/StarterCell").simulation_enabled = false
    return game


func run_tests() -> void:
    test_progress_without_emergency_collection(false)
    test_progress_without_emergency_collection(true)
    await process_frame
    print("BIOFACTORY_AUTONOMY_PROGRESS_TESTS: %d checks, %d failures" % [checks, failures])
    quit(0 if failures == 0 else 1)


func test_progress_without_emergency_collection(add_factory: bool) -> void:
    var game = fixture()
    var cell = game.get_node("organism/StarterCell")
    var physiology = cell.physiology
    if add_factory:
        var construction = cell.get_node("OrganicConstructionController")
        construction.preview_position = Vector2(35.0, 0.0)
        expect(construction.is_preview_valid(), "The second factory has an affordable valid placement")
        construction.construct_building()
        expect(cell.buildings.size() == 2, "The early second factory is really constructed")
        expect(is_equal_approx(cell.inventory.get_amount("nutrient"), 50.0), "Construction uses the actual starting nutrient stock")
    var hover = cell.get_node("MembraneHoverController")
    hover.action_section = cell.boundary.membrane_sections[0]
    expect(hover._change_membrane("oxygen_exchange_membrane"), "Actual starting materials fund oxygen exchange")
    for index in range(60 * 150):
        physiology.advance(STEP)
        if physiology.stabilized:
            break
    expect(physiology.stabilized, "The initial stabilization completes at 60 Hz without emergency collection")
    var lipids_before: float = cell.inventory.get_amount("lipid")
    expect(hover._change_membrane("nutrient_exchange_membrane"), "The real progression unlocks and affords the feeding membrane")
    expect(cell.inventory.get_amount("lipid") < lipids_before, "The feeding upgrade is paid from the remaining starting stock")

    if add_factory:
        expect(physiology.has_low_nutrients(), "Early construction leaves depleted nutrients when feeding is installed")
        expect(physiology.get_state_name() == "Stable", "ATP/O2 can be stable while nutrients are still rebuilding")
        expect(physiology.get_status_name() == "Nutriments faibles", "The displayed status reveals the depleted nutrient reserve")
        expect("Reconstitution automatique des nutriments" in physiology.get_autonomy_wait_reason(), "The waiting reason explains that feeding replenishes nutrients automatically")
        physiology.advance(STEP)
        expect(is_zero_approx(physiology.autonomous_seconds), "Low nutrient reserves wait before the autonomy interval starts")
    else:
        expect(physiology.get_status_name() == "Stable", "The original single-factory path has healthy reserves")
        expect(physiology.get_autonomy_wait_reason().is_empty(), "Healthy passive feeding needs no action before the timer starts")
        physiology.advance(STEP)
        expect(physiology.autonomous_seconds > 0.0, "The autonomy timer starts automatically on the next simulation frame")

    for index in range(60 * 150):
        physiology.advance(STEP)
        if physiology.autonomous:
            break
    expect(physiology.autonomous, "Passive feeding completes thirty seconds of autonomy without any emergency collection")
    expect(physiology.autonomous_seconds >= physiology.profile.autonomy_seconds, "The complete uninterrupted autonomy interval is recorded")
    expect(not physiology.has_low_nutrients(), "Feeding restores a healthy nutrient reserve without manual assistance")
    expect(physiology.get_status_name() == "Stable", "The displayed status returns to stable once all reserves are healthy")
    expect(physiology.get_autonomy_wait_reason().is_empty(), "The successful autonomous design has no waiting reason")
    print("AUTONOMY_NO_HARVEST: factories=%d, nutrients=%.2f, autonomy=%.2f" % [cell.buildings.size(), cell.inventory.get_amount("nutrient"), physiology.autonomous_seconds])
    game.free()
