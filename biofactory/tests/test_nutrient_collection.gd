extends SceneTree

# Run: godot --headless --path biofactory --script res://tests/test_nutrient_collection.gd
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


func prepare_feeding_cell(cell) -> bool:
    cell.physiology.stabilized = true
    cell.inventory.set_amount("atp", 50.0)
    cell.inventory.set_amount("oxygen", 20.0)
    cell.inventory.set_amount("nutrient", 50.0)
    var hover = cell.get_node("MembraneHoverController")
    hover.action_section = cell.boundary.membrane_sections[0]
    return hover._change_membrane("nutrient_exchange_membrane")


func inventory_is_valid(cell) -> bool:
    for amount in cell.inventory.amounts.values():
        if amount < 0.0 or not is_finite(amount):
            return false
    return true


func run_tests() -> void:
    test_real_progression_and_long_term_autonomy()
    test_emergency_nutrients_and_cooldowns()
    test_passive_exchange_respects_environment_and_contacts()
    test_owning_cell_inventory_isolation()
    test_upgrade_permissions_and_group_cost()
    test_autonomy_resets_and_keeps_achievements()
    test_nominal_factory_demand_and_growth()
    test_recovery_from_complete_starvation()
    test_disabled_and_unsupported_production()
    test_early_second_factory_does_not_lock_feeding()
    test_low_nutrients_do_not_count_as_autonomy()
    await process_frame
    print("BIOFACTORY_NUTRIENT_TESTS: %d checks, %d failures" % [checks, failures])
    quit(0 if failures == 0 else 1)


func test_real_progression_and_long_term_autonomy() -> void:
    var game = fixture()
    var cell = game.get_node("organism/StarterCell")
    var physiology = cell.physiology
    var hover = cell.get_node("MembraneHoverController")
    hover.action_section = cell.boundary.membrane_sections[0]
    var before_locked: Dictionary = cell.inventory.amounts.duplicate()
    expect(not hover._change_membrane("nutrient_exchange_membrane"), "Nutrition specialization is locked before initial stabilization")
    expect(cell.inventory.amounts == before_locked, "A locked specialization spends no resources")
    expect(hover._change_membrane("oxygen_exchange_membrane"), "The first oxygen specialization remains available")
    for index in range(1500):
        physiology.advance(0.1)
        if physiology.stabilized:
            break
    expect(physiology.stabilized, "The initial cell can achieve its first stabilization through oxygen exchange")
    expect(not physiology.get_autonomy_blockers().is_empty(), "Oxygen exchange alone cannot claim sustainable nutrient supply")
    expect(not physiology.autonomous, "An initial finite nutrient stock does not count as autonomy")
    var oxygen_conductance_before: float = cell.oxygen_conductance
    expect(hover._change_membrane("nutrient_exchange_membrane"), "Initial materials can fund the feeding membrane after oxygen specialization")
    expect(cell.oxygen_conductance > 0.0 and cell.oxygen_conductance < oxygen_conductance_before, "Feeding retains oxygen intake with a real specialization tradeoff")
    expect(cell.nutrient_conductance > 1.0, "Feeding provides enough nutrient exchange for the initial factory")
    var valid: bool = true
    for index in range(3000):
        physiology.advance(0.2)
        valid = valid and inventory_is_valid(cell)
    expect(valid, "Ten minutes of nutrient exchange keep all quantities finite and nonnegative")
    expect(physiology.autonomous, "The cell completes the autonomy milestone without manual assistance")
    expect(physiology.get_state_name() == "Stable", "Automated nutrition keeps the cell stable beyond the initial stock's lifetime")
    expect(physiology.get_autonomy_blockers().is_empty(), "The completed design genuinely covers its ongoing demands")
    expect(cell.inventory.get_amount("nutrient") > 20.0, "Nutrients remain available after many minutes of factory consumption")
    expect(cell.inventory.get_amount("oxygen") > 5.0, "The feeding membrane sustains oxygen at the same time")
    expect(physiology.nutrient_intake_per_second > 0.5, "The long-lived reserve is supplied by actual nutrient intake")
    print("NUTRIENT_LONG_RUN: ATP %.2f, O2 %.2f, nutrients %.2f" % [cell.inventory.get_amount("atp"), cell.inventory.get_amount("oxygen"), cell.inventory.get_amount("nutrient")])
    game.free()


func test_emergency_nutrients_and_cooldowns() -> void:
    var game = fixture()
    var cell = game.get_node("organism/StarterCell")
    var physiology = cell.physiology
    var section = cell.boundary.membrane_sections[0]
    cell.inventory.set_amount("nutrient", 0.0)
    var captured: float = physiology.absorb_nutrients(section)
    expect(is_equal_approx(captured, 4.0), "Emergency nutrient absorption gives the configured small amount")
    expect(is_equal_approx(cell.inventory.get_amount("nutrient"), captured), "Emergency nutrients enter the owning inventory")
    expect(is_zero_approx(physiology.absorb_nutrients(section)), "Repeated nutrient clicks cannot bypass the cooldown")
    expect(physiology.absorb_oxygen(section) > 0.0, "Nutrient absorption does not consume the independent oxygen cooldown")
    expect(physiology.nutrient_cooldown_remaining > 0.0 and physiology.manual_cooldown_remaining > 0.0, "Each emergency action maintains its own recovery timer")
    advance(cell, physiology.profile.manual_nutrient_cooldown)
    expect(physiology.absorb_nutrients(section) > 0.0, "Emergency nutrient collection resumes after recovery")
    physiology.nutrient_cooldown_remaining = 0.0
    cell.inventory.set_amount("nutrient", physiology.get_nutrient_capacity() - 0.5)
    expect(is_equal_approx(physiology.absorb_nutrients(section), 0.5), "Emergency absorption stops at nutrient equilibrium")
    physiology.nutrient_cooldown_remaining = 0.0
    physiology.profile.ambient_nutrient = 0.0
    cell.inventory.set_amount("nutrient", 0.0)
    expect(is_zero_approx(physiology.absorb_nutrients(section)), "An empty nutrient environment cannot provide manual resources")
    physiology.profile.ambient_nutrient = 1.0
    section.is_external = false
    cell.recalculate_membrane_maintenance()
    expect(is_zero_approx(physiology.absorb_nutrients(section)), "A shared membrane cannot manually collect outside nutrients")
    expect(is_zero_approx(physiology.absorb_nutrients(null)), "An absent target cannot collect nutrients")
    var foreign_section = load("res://scripts/spatial/membrane_section_state.gd").new()
    expect(is_zero_approx(physiology.absorb_nutrients(foreign_section)), "A section outside this cell cannot collect its resources")
    game.free()


func test_passive_exchange_respects_environment_and_contacts() -> void:
    var game = fixture()
    var cell = game.get_node("organism/StarterCell")
    var physiology = cell.physiology
    cell.buildings[0].free()
    cell.inventory.set_amount("nutrient", 0.0)
    advance(cell, 1.0)
    expect(cell.inventory.get_amount("nutrient") > 0.0, "Even a basic external membrane provides its small passive nutrient exchange")
    expect(physiology.nutrient_intake_per_second > 0.0, "Passive nutrient intake is reported as a rate")
    var section = cell.boundary.membrane_sections[0]
    section.is_external = false
    cell.recalculate_membrane_maintenance()
    cell.inventory.set_amount("nutrient", 0.0)
    advance(cell, 5.0)
    expect(is_zero_approx(cell.nutrient_conductance), "Shared contacts do not contribute external nutrient conductance")
    expect(is_zero_approx(cell.inventory.get_amount("nutrient")), "No external nutrients appear behind internal contacts")
    section.is_external = true
    cell.recalculate_membrane_maintenance()
    physiology.profile.ambient_nutrient = 0.0
    advance(cell, 5.0)
    expect(is_zero_approx(cell.inventory.get_amount("nutrient")), "Passive exchange cannot create nutrients in an empty environment")
    physiology.profile.ambient_nutrient = 1.0
    cell.inventory.set_amount("nutrient", physiology.get_nutrient_capacity() - 0.01)
    physiology.advance(10000.0)
    expect(cell.inventory.get_amount("nutrient") <= physiology.get_nutrient_capacity() + 0.000001, "A large simulation step cannot overshoot nutrient equilibrium")
    game.free()


func test_owning_cell_inventory_isolation() -> void:
    var first_game = fixture()
    var second_game = fixture()
    var first = first_game.get_node("organism/StarterCell")
    var second = second_game.get_node("organism/StarterCell")
    first.inventory.set_amount("nutrient", 0.0)
    var before: Dictionary = second.inventory.amounts.duplicate()
    first.physiology.absorb_nutrients(first.boundary.membrane_sections[0])
    advance(first, 10.0)
    expect(second.inventory.amounts == before, "Manual and passive collection never change another cell's inventory")
    expect(first.inventory.get_amount("nutrient") != 100.0, "Collection does not operate through the globally active inventory facade")
    second_game.free()
    first_game.free()


func test_upgrade_permissions_and_group_cost() -> void:
    var game = fixture()
    var cell = game.get_node("organism/StarterCell")
    var boundary = cell.boundary
    boundary.split_section_at_t(0.25)
    boundary.split_section_at_t(0.5)
    boundary.split_section_at_t(0.75)
    var hover = cell.get_node("MembraneHoverController")
    hover.action_section = boundary.membrane_sections[2]
    cell.physiology.stabilized = true
    cell.inventory.set_amount("lipid", 0.0)
    var before: Dictionary = cell.inventory.amounts.duplicate()
    expect(not hover._change_membrane("nutrient_exchange_membrane"), "Unaffordable feeding specialization is rejected")
    expect(cell.inventory.amounts == before, "A failed purchase never partially charges its materials")
    cell.inventory.set_amount("lipid", 100.0)
    cell.inventory.set_amount("phosphorus", 100.0)
    var cost: Dictionary = hover._replacement_cost("nutrient_exchange_membrane")
    var length_m: float = boundary.get_perimeter_m()
    expect(is_equal_approx(cost.get("lipid", 0.0), length_m * 1.7), "Feeding specialization quotes the entire logical membrane length")
    var lipids_before: float = cell.inventory.get_amount("lipid")
    expect(hover._change_membrane("nutrient_exchange_membrane"), "A funded unlocked feeding specialization succeeds")
    var all_changed: bool = true
    for section in boundary.membrane_sections:
        all_changed = all_changed and section.membrane_type_id == "nutrient_exchange_membrane"
    expect(all_changed, "Feeding specialization changes all technical fragments of the chosen membrane")
    expect(is_equal_approx(cell.inventory.get_amount("lipid"), lipids_before - cost["lipid"]), "A logical-group purchase pays its full cost once")
    var same_type_inventory: Dictionary = cell.inventory.amounts.duplicate()
    hover._change_membrane("nutrient_exchange_membrane")
    expect(cell.inventory.amounts == same_type_inventory, "Selecting an already installed membrane type cannot spend resources again")
    for section in boundary.membrane_sections:
        section.is_external = false
    cell.recalculate_membrane_maintenance()
    expect(not hover._change_membrane("oxygen_exchange_membrane"), "A replacement action cannot alter an unsupported internal interface")
    game.free()


func test_autonomy_resets_and_keeps_achievements() -> void:
    var game = fixture()
    var cell = game.get_node("organism/StarterCell")
    expect(prepare_feeding_cell(cell), "Autonomy timer fixture installs the feeding membrane")
    var physiology = cell.physiology
    advance(cell, 10.0)
    expect(physiology.autonomous_seconds > 0.0, "A stable self-sufficient design accrues autonomy time")
    expect(not physiology.autonomous, "Ten seconds cannot complete the thirty-second autonomy goal")
    expect(physiology.absorb_oxygen(cell.boundary.membrane_sections[0]) > 0.0, "A successful oxygen action is available during the autonomy interval")
    expect(is_zero_approx(physiology.autonomous_seconds), "Manual oxygen assistance resets the autonomy interval immediately")
    advance(cell, 10.0)
    expect(physiology.absorb_nutrients(cell.boundary.membrane_sections[0]) > 0.0, "A successful nutrient action is available during the autonomy interval")
    expect(is_zero_approx(physiology.autonomous_seconds), "Manual nutrient assistance also resets the autonomy interval")
    advance(cell, physiology.profile.autonomy_seconds + 0.2)
    expect(physiology.autonomous, "A fresh uninterrupted autonomous interval completes the milestone")
    physiology.profile.ambient_nutrient = 0.0
    physiology.advance(0.1)
    expect(not physiology.get_autonomy_blockers().is_empty(), "Losing the environment's supply reveals a current autonomy blocker")
    expect(is_zero_approx(physiology.autonomous_seconds), "Unsustainable supply resets current autonomy progress")
    expect(physiology.autonomous and physiology.stabilized, "Past milestones remain achieved when conditions later deteriorate")
    game.free()


func test_nominal_factory_demand_and_growth() -> void:
    var game = fixture()
    var cell = game.get_node("organism/StarterCell")
    expect(prepare_feeding_cell(cell), "Nominal-demand fixture installs feeding exchange")
    cell.inventory.set_amount("nutrient", 1000.0)
    cell.inventory.set_amount("oxygen", 100.0)
    cell.inventory.set_amount("atp", 1000.0)
    var controller = cell.get_node("OrganicConstructionController")
    controller.building_data = load("res://data/buildings/atp_factory.tres")
    for index in range(3):
        controller.preview_position = Vector2(20.0 * index, 0)
        controller.construct_building()
    expect(cell.buildings.size() == 4, "The demand scenario has four real organic factories")
    cell.physiology.advance(0.01)
    expect(not cell.physiology.get_autonomy_blockers().is_empty(), "Nominal full-rate demand prevents excess factories from claiming autonomy on stored fuel")
    advance(cell, 35.0)
    expect(not cell.physiology.autonomous, "Healthy initial reserves do not hide an unsustainable architecture")
    game.free()
    game = fixture()
    cell = game.get_node("organism/StarterCell")
    expect(prepare_feeding_cell(cell), "Growth-demand fixture installs feeding exchange")
    cell.boundary.build_ovoid(10.0, 8.0, 72)
    cell.inventory.set_amount("nutrient", cell.physiology.get_nutrient_capacity() * 0.8)
    cell.inventory.set_amount("oxygen", cell.physiology.get_oxygen_capacity() * 0.8)
    cell.inventory.set_amount("atp", 1000.0)
    cell.physiology.advance(0.01)
    expect(not cell.physiology.get_autonomy_blockers().is_empty(), "A very large cell cannot call one factory sufficient for its upkeep")
    game.free()
    game = fixture()
    cell = game.get_node("organism/StarterCell")
    cell.physiology.stabilized = true
    cell.inventory.set_amount("atp", 1000.0)
    cell.inventory.set_amount("oxygen", 20.0)
    cell.inventory.set_amount("nutrient", 100.0)
    cell.buildings[0].free()
    expect(not cell.physiology.get_autonomy_blockers().is_empty(), "A stockpile without any ATP producer is not an autonomous energy supply")
    game.free()


func test_recovery_from_complete_starvation() -> void:
    var game = fixture()
    var cell = game.get_node("organism/StarterCell")
    expect(prepare_feeding_cell(cell), "Starvation fixture installs the feeding membrane")
    cell.inventory.set_amount("nutrient", 0.0)
    cell.inventory.set_amount("oxygen", 0.0)
    cell.inventory.set_amount("atp", 0.0)
    cell.physiology.refresh_state()
    expect(cell.physiology.get_state_name() == "Dormance", "An empty fuel inventory produces recoverable dormancy")
    advance(cell, 180.0)
    expect(cell.physiology.get_state_name() == "Stable", "Passive feeding can restart metabolism from completely empty reserves")
    expect(cell.physiology.autonomous, "The recovered cell can complete autonomy without repeated manual clicking")
    expect(inventory_is_valid(cell), "Starvation and recovery never create invalid resource quantities")
    game.free()


func test_disabled_and_unsupported_production() -> void:
    var game = fixture()
    var cell = game.get_node("organism/StarterCell")
    prepare_feeding_cell(cell)
    var building = cell.buildings[0]
    building.simulate(0.1)
    building.recipe_processor.enabled = false
    expect(not cell.physiology.get_autonomy_blockers().is_empty(), "A disabled ATP producer cannot provide theoretical energy for autonomy")
    game.free()
    var database = root.get_node("RecipeDatabase")
    for test_case in ["unsupported_input", "net_atp_input"]:
        game = fixture()
        cell = game.get_node("organism/StarterCell")
        prepare_feeding_cell(cell)
        building = cell.buildings[0]
        var recipe = database.get_recipe("basic_atp_production").duplicate()
        recipe.inputs = recipe.inputs.duplicate()
        recipe.id = "nutrient_test_" + test_case
        if test_case == "unsupported_input":
            recipe.inputs["phosphorus"] = 1.0
        else:
            recipe.inputs["atp"] = 3.0
        database.recipes_by_id[recipe.id] = recipe
        building.data = building.data.duplicate()
        building.data.supported_recipes = building.data.supported_recipes.duplicate()
        building.data.supported_recipes.assign([recipe.id])
        var blockers: PackedStringArray = cell.physiology.get_autonomy_blockers()
        if test_case == "unsupported_input":
            expect("Approvisionnement non automatisé" in "\n".join(blockers), "An unsupplied extra recipe ingredient prevents autonomy despite initial stock")
        else:
            expect("production ATP" in "\n".join(blockers), "Autonomy subtracts ATP used as a recipe ingredient from gross ATP output")
        database.recipes_by_id.erase(recipe.id)
        game.free()


func test_early_second_factory_does_not_lock_feeding() -> void:
    var game = fixture()
    var cell = game.get_node("organism/StarterCell")
    var construction = cell.get_node("OrganicConstructionController")
    construction.building_data = load("res://data/buildings/atp_factory.tres")
    construction.preview_position = Vector2(35, 0)
    expect(construction.is_preview_valid(), "An early second factory has a legitimate affordable placement")
    construction.construct_building()
    expect(cell.buildings.size() == 2 and is_equal_approx(cell.inventory.get_amount("nutrient"), 50.0), "The early second factory uses actual initial stock")
    var hover = cell.get_node("MembraneHoverController")
    hover.action_section = cell.boundary.membrane_sections[0]
    expect(hover._change_membrane("oxygen_exchange_membrane"), "An early second factory still leaves materials for oxygen exchange")
    for index in range(1200):
        cell.physiology.advance(0.1)
        if cell.physiology.stabilized:
            break
    expect(cell.physiology.stabilized, "Early construction cannot lock nutrition behind an unreachable first stabilization")
    expect(hover._change_membrane("nutrient_exchange_membrane"), "The real early-construction path unlocks and can afford feeding exchange")
    advance(cell, 90.0)
    expect(cell.inventory.get_amount("nutrient") >= cell.physiology.profile.low_nutrient, "Feeding restores a useful nutrient reserve after early construction")
    print("EARLY_SECOND_FACTORY: stabilized=", cell.physiology.stabilized, "; autonomous=", cell.physiology.autonomous, "; nutrients=", cell.inventory.get_amount("nutrient"))
    game.free()


func test_low_nutrients_do_not_count_as_autonomy() -> void:
    var game = fixture()
    var cell = game.get_node("organism/StarterCell")
    prepare_feeding_cell(cell)
    cell.inventory.set_amount("nutrient", 0.0)
    cell.physiology.refresh_state()
    expect(cell.physiology.get_state_name() == "Stable", "Initial stabilization retains its ATP/O2 definition without hiding nutrient warnings")
    cell.physiology.advance(1.0)
    expect(cell.inventory.get_amount("nutrient") < cell.physiology.profile.low_nutrient, "The autonomy scenario genuinely has insufficient nutrient reserve")
    expect(is_zero_approx(cell.physiology.autonomous_seconds) and not cell.physiology.autonomous, "Healthy ATP/O2 alone cannot advance nutrition autonomy")
    cell.inventory.set_amount("nutrient", 20.0)
    advance(cell, 2.0)
    expect(cell.physiology.autonomous_seconds > 0.0, "Autonomy progress resumes when nutrient reserves are healthy again")
    game.free()
