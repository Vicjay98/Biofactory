extends SceneTree

# Run: godot --headless --path biofactory --script res://tests/test_physiology.gd
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
    var cell = game.get_node("organism/StarterCell")
    cell.simulation_enabled = false
    cell.physiology_profile = cell.physiology_profile.duplicate()
    cell.physiology.profile = cell.physiology_profile
    return game


func advance(cell, seconds: float, step: float = 0.1) -> void:
    for index in range(roundi(seconds / step)):
        cell.physiology.advance(step)


func run_tests() -> void:
    test_recipe_time_and_conservation()
    test_initial_crisis_and_recovery()
    test_manual_absorption_and_shared_membranes()
    test_inventory_isolation_and_building_lifecycle()
    test_objective_reset_and_geometry_cost()
    test_diagnostics_and_context_actions()
    await process_frame
    print("BIOFACTORY_TESTS: %d checks, %d failures" % [checks, failures])
    quit(0 if failures == 0 else 1)


func test_recipe_time_and_conservation() -> void:
    var inventory = load("res://scripts/resources/resource_inventory.gd").new()
    expect(inventory.remove_resource("atp", 0.0), "An empty inventory can pay zero upkeep")
    inventory.set_amount("atp", 0.000001)
    inventory.remove_resource("atp", 0.000001)
    expect(inventory.get_amount("atp") == 0.0, "Very small resource payments are not rounded away")
    inventory.set_amount("nutrient", 6.0)
    inventory.set_amount("oxygen", 3.0)
    var processor = load("res://scripts/recipes/recipe_processor.gd").new()
    processor.configure(root.get_node("RecipeDatabase").get_recipe("basic_atp_production"), inventory)
    processor.process(5.0)
    expect(is_equal_approx(inventory.get_amount("atp"), 10.0), "Five seconds finish two recipes")
    expect(is_equal_approx(processor.cycle_progress, 1.0), "Elapsed time remains in the next cycle")
    expect(is_zero_approx(inventory.get_amount("nutrient")), "Ingredients are reserved exactly once per cycle")
    processor.process(1.0)
    expect(is_equal_approx(inventory.get_amount("atp"), 15.0), "An already funded cycle finishes without new fuel")
    processor.process(60.0)
    expect(is_equal_approx(inventory.get_amount("atp"), 15.0), "No ATP is created without ingredients")
    expect(is_equal_approx(inventory.get_amount("waste"), 3.0), "Waste tracks completed recipes")
    var split_inventory = load("res://scripts/resources/resource_inventory.gd").new()
    split_inventory.set_amount("nutrient", 6.0)
    split_inventory.set_amount("oxygen", 3.0)
    var split_processor = load("res://scripts/recipes/recipe_processor.gd").new()
    split_processor.configure(root.get_node("RecipeDatabase").get_recipe("basic_atp_production"), split_inventory)
    for index in range(600):
        split_processor.process(0.01)
    expect(is_equal_approx(split_inventory.get_amount("atp"), 15.0), "Recipe output is independent of frame subdivision")


func test_initial_crisis_and_recovery() -> void:
    var game = fixture()
    var cell = game.get_node("organism/StarterCell")
    var physiology = cell.physiology
    expect(cell.buildings.size() == 1, "The initial organic ATP factory registers with its cell")
    expect(physiology.get_state_name() == "Affaiblie", "The first cell begins weakened")
    advance(cell, 60.0)
    expect(physiology.get_state_name() in ["Dormance", "Critique"], "Basic exchange cannot sustain the initial cell")
    expect(is_instance_valid(cell), "A long shortage leaves the cell recoverable")
    expect(not physiology.stabilized, "A failing cell cannot complete the objective")
    var previous_conductance: float = cell.oxygen_conductance
    var hover = cell.get_node("MembraneHoverController")
    var section = cell.boundary.membrane_sections[0]
    var previous_lipids: float = cell.inventory.get_amount("lipid")
    var cost: float = cell.boundary.get_section_length_m(section) * 1.5
    hover.action_section = section
    hover._on_action(1)
    expect(section.membrane_type_id == "oxygen_exchange_membrane", "The membrane action installs specialized exchange")
    expect(cell.oxygen_conductance > previous_conductance, "Specialization changes real oxygen intake")
    expect(is_equal_approx(cell.inventory.get_amount("lipid"), previous_lipids - cost), "Specialization pays its local material cost")
    var recovered_after: float = 0.0
    var valid_inventory: bool = true
    for index in range(1500):
        physiology.advance(0.1)
        recovered_after += 0.1
        valid_inventory = valid_inventory and inventory_is_valid(cell)
        if physiology.stabilized:
            break
    print("Recovery after upgrade: %.1f s; ATP %.2f; O2 %.2f" % [recovered_after, cell.inventory.get_amount("atp"), cell.inventory.get_amount("oxygen")])
    expect(physiology.stabilized, "A starved cell can recover and finish 20 continuous stable seconds")
    expect(physiology.get_state_name() == "Stable", "Recovery restores normal physiology")
    expect(physiology.atp_production_per_second > 0.0, "Organic factories report actual ATP production")
    expect(valid_inventory, "All resource quantities stay finite and nonnegative during recovery")
    game.free()


func inventory_is_valid(cell) -> bool:
    for amount in cell.inventory.amounts.values():
        if amount < 0.0 or not is_finite(amount):
            return false
    return true


func test_manual_absorption_and_shared_membranes() -> void:
    var game = fixture()
    var cell = game.get_node("organism/StarterCell")
    var section = cell.boundary.membrane_sections[0]
    var physiology = cell.physiology
    var before: float = cell.inventory.get_amount("oxygen")
    var captured: float = physiology.absorb_oxygen(section)
    expect(is_equal_approx(captured, 2.0), "Emergency absorption gives a small amount of external O2")
    expect(is_equal_approx(cell.inventory.get_amount("oxygen"), before + captured), "Manual O2 enters only this inventory")
    expect(is_zero_approx(physiology.absorb_oxygen(section)), "Repeated clicks cannot bypass the cooldown")
    advance(cell, physiology.profile.manual_oxygen_cooldown)
    expect(physiology.absorb_oxygen(section) > 0.0, "Emergency absorption becomes available after cooldown")
    section.is_external = false
    cell.recalculate_membrane_maintenance()
    expect(is_zero_approx(cell.oxygen_conductance), "Internal contact does not tap the external reservoir")
    physiology.manual_cooldown_remaining = 0.0
    expect(is_zero_approx(physiology.absorb_oxygen(section)), "Internal contacts cannot manually absorb external O2")
    section.is_external = true
    cell.recalculate_membrane_maintenance()
    physiology.profile.ambient_oxygen = 0.0
    expect(is_zero_approx(physiology.absorb_oxygen(section)), "No oxygen can be collected from an empty environment")
    physiology.profile.ambient_oxygen = 1.0
    cell.inventory.set_amount("oxygen", physiology.get_oxygen_capacity() - 0.5)
    expect(is_equal_approx(physiology.absorb_oxygen(section), 0.5), "Manual absorption stops at the local oxygen equilibrium")
    game.free()


func test_inventory_isolation_and_building_lifecycle() -> void:
    var first_game = fixture()
    var second_game = fixture()
    var first = first_game.get_node("organism/StarterCell")
    var second = second_game.get_node("organism/StarterCell")
    var second_before: Dictionary = second.inventory.amounts.duplicate()
    advance(first, 8.0)
    expect(second.inventory.amounts == second_before, "A cell never consumes its neighbor's inventory")
    expect(first.inventory.get_amount("nutrient") < 100.0, "The organic factory consumes its own fuel")
    var controller = first.get_node("OrganicConstructionController")
    controller.building_data = load("res://data/buildings/atp_factory.tres")
    controller.preview_position = Vector2(35, 0)
    controller.construct_building()
    expect(first.buildings.size() == 2, "A newly constructed factory registers after receiving its owner and data")
    var built = first.buildings[-1]
    advance(first, 0.1)
    expect(built.recipe_processor != null, "A new organic factory actually joins the metabolism")
    built.free()
    expect(first.buildings.size() == 1, "Removing a building unregisters it from simulation")
    second_game.free()
    first_game.free()


func test_objective_reset_and_geometry_cost() -> void:
    var game = fixture()
    var cell = game.get_node("organism/StarterCell")
    var physiology = cell.physiology
    cell.inventory.set_amount("atp", 50.0)
    cell.inventory.set_amount("oxygen", 20.0)
    advance(cell, 2.0)
    expect(physiology.stable_seconds >= 1.9, "Stable time accrues only while healthy")
    cell.inventory.set_amount("atp", 0.0)
    physiology.advance(0.01)
    expect(is_zero_approx(physiology.stable_seconds), "A new shortage resets the continuous-stability timer")
    expect(not physiology.stabilized, "A short healthy interval cannot finish the objective")
    var previous_demand: float = physiology.atp_demand_per_second
    cell.boundary.build_ovoid(3.5, 3.0, 72)
    physiology.advance(0.01)
    expect(physiology.atp_demand_per_second > previous_demand, "A larger cell costs more ATP to maintain")
    game.free()


func test_diagnostics_and_context_actions() -> void:
    var game = fixture()
    var cell = game.get_node("organism/StarterCell")
    var panel = game.get_node("HUD/MembraneInfoPanel")
    panel.show_cell(cell)
    expect("O₂ faible" in panel.body_label.text, "Cell hover explains the oxygen shortage")
    panel.show_building(cell.buildings[0])
    expect(panel.title_label.text == "Usine ATP", "Hover identifies the actual organic factory")
    var hover = cell.get_node("MembraneHoverController")
    hover.action_section = cell.boundary.membrane_sections[0]
    cell.inventory.set_amount("lipid", 0.0)
    var initial_type: String = hover.action_section.membrane_type_id
    hover._on_action(1)
    expect(hover.action_section.membrane_type_id == initial_type, "An unaffordable specialization cannot modify the membrane")
    panel.show_section(cell.boundary, hover.action_section)
    expect("O₂ entrant" in panel.body_label.text, "Membrane hover reports its functional oxygen exchange")
    var display = game.get_node("HUD/ResourceDisplay")
    display.update_display()
    expect(display.labels_by_resource_id.size() == 3, "Early HUD introduces only ATP, oxygen and nutrients")
    expect(not cell.get_node("OrganicConstructionController").construction_active, "The game starts without a construction preview")
    var palette = game.get_node("HUD/BuildingPalette")
    expect(not palette.visible, "Construction UI is hidden during normal play")
    hover._on_action(2)
    expect(palette.visible and palette.owning_cell == cell, "The contextual construction action targets its cell")
    expect(not palette.factory_button.disabled, "The cell can build with its own available nutrients")
    cell.inventory.set_amount("nutrient", 0.0)
    palette._process(0.2)
    expect(palette.factory_button.disabled, "The open construction menu reacts to resource changes")
    game.free()
