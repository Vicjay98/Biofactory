extends SceneTree

# Run: godot --headless --path biofactory --script res://tests/test_cell_information_ui.gd
var checks: int = 0
var failures: int = 0


func expect(condition: bool, message: String) -> void:
    checks += 1
    if not condition:
        failures += 1
        push_error(message)


func _initialize() -> void:
    call_deferred("run_tests")


func run_tests() -> void:
    var game = load("res://scene/main/game.tscn").instantiate()
    root.add_child(game)
    game.process_mode = Node.PROCESS_MODE_DISABLED
    var cell = game.get_node("organism/StarterCell")
    var fixed = game.get_node("HUD/CellInfoPanel")
    var moving = game.get_node("HUD/MembraneInfoPanel")
    var missions = game.get_node("HUD/ResourceDisplay")

    expect(missions.visible, "The mission panel is permanently visible")
    expect(not fixed.visible, "The cell panel starts hidden outside a cell")
    fixed.show_hovered_cell(cell)
    expect(fixed.visible and fixed.target_cell == cell, "Hovering a cell opens its fixed information panel")
    expect(not fixed.pinned and not fixed.close_button.visible, "A hover-only panel is not presented as pinned")
    var fixed_lines: PackedStringArray = fixed.body_label.text.split("\n")
    moving.show_cell(cell)
    var moving_lines: PackedStringArray = moving.body_label.text.split("\n")
    expect(fixed_lines[0].begins_with("ATP") and fixed_lines[1].begins_with("O₂") and fixed_lines[2].begins_with("Nutriments"), "The fixed panel orders ATP, oxygen and nutrients consistently")
    expect(moving_lines[0].begins_with("ATP") and moving_lines[1].begins_with("O₂") and moving_lines[2].begins_with("Nutriments"), "The moving cytoplasm panel uses the same resource order")
    expect(moving_lines[3].begins_with("Surface") and moving_lines[4].begins_with("Entretien"), "The moving cytoplasm panel matches the complete fixed information order")
    expect("Diagnostic" in moving.body_label.text, "Cytoplasm hover retains the cell diagnostic")

    fixed.toggle_pinned_cell(cell)
    expect(fixed.visible and fixed.pinned and fixed.close_button.visible, "A cytoplasm click pins the panel and exposes its close button")
    fixed.leave_cell(cell)
    expect(fixed.visible, "A pinned panel stays visible after the pointer leaves")
    fixed.toggle_pinned_cell(cell)
    expect(not fixed.visible and not fixed.pinned, "Clicking the same cytoplasm again closes its pinned panel")
    fixed.show_hovered_cell(cell)
    expect(not fixed.visible, "A click-closed panel stays closed until the pointer leaves")
    fixed.leave_cell(cell)
    fixed.show_hovered_cell(cell)
    expect(fixed.visible, "Re-entering the cell restores hover information")
    fixed.toggle_pinned_cell(cell)
    fixed.close()
    expect(not fixed.visible and not fixed.pinned, "The close button action clears the pinned selection")

    moving.show_building(cell.buildings[0])
    expect(not "Diagnostic de la cellule" in moving.body_label.text, "Factory information omits the cell diagnostic")
    moving.show_section(cell.boundary, cell.boundary.membrane_sections[0])
    expect(not "Diagnostic de la cellule" in moving.body_label.text, "Membrane information omits the cell diagnostic")
    expect(not game.has_node("organism/BuildController"), "The abandoned grid preview controller is absent")
    expect(not game.has_node("organism/MembraneBuildController"), "The abandoned free membrane drawing controller is absent")
    expect(not game.has_node("ConstructionMenu"), "The superseded construction menu is absent")

    game.free()
    await process_frame
    print("BIOFACTORY_CELL_UI_TESTS: %d checks, %d failures" % [checks, failures])
    quit(0 if failures == 0 else 1)
