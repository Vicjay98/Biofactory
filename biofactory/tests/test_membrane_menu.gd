extends SceneTree

# Run: godot --headless --path biofactory --script res://tests/test_membrane_menu.gd
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


func membrane_index(hover, type_id: String) -> int:
    for action_id in hover._membrane_type_actions:
        if hover._membrane_type_actions[action_id] == type_id:
            return hover.action_menu.get_item_index(action_id)
    return -1


func equipped_count(menu: PopupMenu) -> int:
    var count: int = 0
    for index in range(menu.item_count):
        count += menu.get_item_text(index).count("(équipé)")
    return count


func build_menu(cell):
    var hover = cell.get_node("MembraneHoverController")
    hover.action_section = cell.boundary.membrane_sections[0]
    hover._build_membrane_menu()
    hover._update_menu()
    return hover


func run_tests() -> void:
    test_initial_catalog_and_equipped_marker()
    test_upgrade_and_live_unlock()
    test_unaffordable_options_remain_visible()
    test_equipped_selection_never_charges_again()
    await process_frame
    print("BIOFACTORY_MENU_TESTS: %d checks, %d failures" % [checks, failures])
    quit(0 if failures == 0 else 1)


func test_initial_catalog_and_equipped_marker() -> void:
    var game = fixture()
    var cell = game.get_node("organism/StarterCell")
    var hover = build_menu(cell)
    expect(hover._membrane_type_actions.size() == 3, "The initial membrane menu lists all three catalog specializations")
    for type_id in ["basic_membrane", "oxygen_exchange_membrane", "nutrient_exchange_membrane"]:
        expect(membrane_index(hover, type_id) >= 0, "The catalog entry remains visible: " + type_id)
    expect(equipped_count(hover.action_menu) == 1, "The menu shows exactly one equipped marker")
    var current: int = membrane_index(hover, "basic_membrane")
    if current >= 0:
        expect("(équipé)" in hover.action_menu.get_item_text(current), "The installed basic membrane is explicitly labeled equipped")
        expect(hover.action_menu.is_item_disabled(current), "The already equipped specialization cannot be repurchased")
    var feeding: int = membrane_index(hover, "nutrient_exchange_membrane")
    if feeding >= 0:
        expect(hover.action_menu.is_item_disabled(feeding), "Locked feeding remains visible but disabled")
        expect("après stabilisation" in hover.action_menu.get_item_text(feeding), "The locked entry explains its stabilization prerequisite")
    game.free()


func test_upgrade_and_live_unlock() -> void:
    var game = fixture()
    var cell = game.get_node("organism/StarterCell")
    var hover = build_menu(cell)
    expect(hover._change_membrane("oxygen_exchange_membrane"), "A real material-funded oxygen upgrade succeeds")
    hover._build_membrane_menu()
    hover._update_menu()
    expect(hover._membrane_type_actions.size() == 3, "Upgrading does not remove the installed specialization from the menu")
    var oxygen: int = membrane_index(hover, "oxygen_exchange_membrane")
    var basic: int = membrane_index(hover, "basic_membrane")
    var feeding: int = membrane_index(hover, "nutrient_exchange_membrane")
    expect(oxygen >= 0 and basic >= 0 and feeding >= 0, "All specializations remain listed after upgrading")
    if oxygen >= 0 and basic >= 0 and feeding >= 0:
        expect("(équipé)" in hover.action_menu.get_item_text(oxygen), "The equipped marker moves to oxygen exchange")
        expect(hover.action_menu.is_item_disabled(oxygen), "The equipped oxygen specialization is disabled")
        expect(not "(équipé)" in hover.action_menu.get_item_text(basic), "The former specialization loses its equipped marker")
        expect(hover.action_menu.is_item_disabled(feeding), "Feeding starts locked even after the oxygen upgrade")
        cell.physiology.stabilized = true
        hover._update_menu()
        expect(not hover.action_menu.is_item_disabled(feeding), "The existing menu unlocks an affordable feeding option when stabilization is reached")
        expect(not "après stabilisation" in hover.action_menu.get_item_text(feeding), "The unlocked entry no longer shows an obsolete prerequisite")
        expect(hover._change_membrane("nutrient_exchange_membrane"), "The same initial material budget can install the feeding specialization")
        hover._update_menu()
        expect("(équipé)" in hover.action_menu.get_item_text(feeding), "Refreshing the existing menu tracks an equipped type change without rebuilding")
        expect(hover.action_menu.is_item_disabled(feeding), "Live refresh prevents repurchasing the newly installed feeding specialization")
        expect(not "(équipé)" in hover.action_menu.get_item_text(oxygen), "Live refresh removes the old equipped marker")
        expect(equipped_count(hover.action_menu) == 1, "Live refresh keeps exactly one equipped entry")
    game.free()


func test_unaffordable_options_remain_visible() -> void:
    var game = fixture()
    var cell = game.get_node("organism/StarterCell")
    cell.physiology.stabilized = true
    cell.inventory.set_amount("lipid", 0.0)
    cell.inventory.set_amount("phosphorus", 0.0)
    var hover = build_menu(cell)
    expect(hover._membrane_type_actions.size() == 3, "An empty material inventory does not hide catalog options")
    for type_id in ["oxygen_exchange_membrane", "nutrient_exchange_membrane"]:
        var index: int = membrane_index(hover, type_id)
        expect(index >= 0, "An unaffordable specialization stays visible: " + type_id)
        if index >= 0:
            expect(hover.action_menu.is_item_disabled(index), "An unaffordable specialization remains disabled: " + type_id)
    var current: int = membrane_index(hover, "basic_membrane")
    if current >= 0:
        expect("(équipé)" in hover.action_menu.get_item_text(current), "An equipped marker does not depend on being able to buy the current membrane again")
    game.free()


func test_equipped_selection_never_charges_again() -> void:
    var game = fixture()
    var cell = game.get_node("organism/StarterCell")
    var hover = build_menu(cell)
    var before: Dictionary = cell.inventory.amounts.duplicate()
    expect(not hover._change_membrane("basic_membrane"), "Changing to the already installed specialization is rejected")
    expect(cell.inventory.amounts == before, "An already installed specialization never charges materials")
    var current: int = membrane_index(hover, "basic_membrane")
    if current >= 0:
        hover._on_action(hover.action_menu.get_item_id(current))
        expect(cell.inventory.amounts == before, "The equipped menu action also cannot charge resources")
        expect(hover.action_section.membrane_type_id == "basic_membrane", "The equipped action preserves the membrane type")
    game.free()
