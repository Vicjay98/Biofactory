extends SceneTree

# Run: godot --headless --path biofactory --script res://tests/test_membrane_selection.gd
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


func fragment(boundary, cuts: Array = [0.25, 0.5, 0.75]) -> void:
    for cut in cuts:
        boundary.split_section_at_t(cut)


func edge_middle(boundary, index: int) -> Vector2:
    return (
        boundary.outline[index]
        + boundary.outline[(index + 1) % boundary.outline.size()]
    ) * 0.5


func run_tests() -> void:
    test_cancelled_anchor_selection_does_not_fragment()
    test_committed_growth_keeps_one_membrane()
    test_whole_contour_group_and_hover()
    test_closed_contour_seam()
    test_different_types_remain_separate()
    test_contact_identity_and_neighbor_order()
    test_explicit_junctions_stop_grouping()
    test_replacement_uses_a_snapshot()
    test_cost_and_display_use_whole_membrane()
    test_grouping_preserves_physical_economy()
    await process_frame
    print("BIOFACTORY_MEMBRANE_TESTS: %d checks, %d failures" % [checks, failures])
    quit(0 if failures == 0 else 1)


func test_cancelled_anchor_selection_does_not_fragment() -> void:
    var game = fixture()
    var cell = game.get_node("organism/StarterCell")
    var boundary = cell.boundary
    var growth = cell.get_node("GrowthController")
    var original_outline: PackedVector2Array = boundary.outline.duplicate()
    growth.mouse_world_position = boundary.to_global(boundary.outline[8])
    growth.select_anchor_a()
    expect(growth.anchor_a_index == 8, "Selecting a real contour point still chooses anchor A")
    expect(boundary.membrane_sections.size() == 1, "Anchor A does not create a membrane section")
    growth.mouse_world_position = boundary.to_global(boundary.outline[26])
    growth.select_anchor_b()
    expect(growth.anchor_b_index == 26, "Selecting a second contour point still chooses anchor B")
    expect(boundary.membrane_sections.size() == 1, "Anchor B does not create a membrane section")
    growth.reset_selection()
    for index in range(12):
        growth.mouse_world_position = boundary.to_global(boundary.outline[index + 1])
        growth.select_anchor_a()
        growth.mouse_world_position = boundary.to_global(boundary.outline[index + 30])
        growth.select_anchor_b()
        growth.reset_selection()
    expect(boundary.membrane_sections.size() == 1, "Repeated cancelled anchor selections leave one membrane")
    expect(boundary.outline == original_outline, "Choosing and cancelling anchors does not change geometry")
    game.free()


func test_committed_growth_keeps_one_membrane() -> void:
    var game = fixture()
    var cell = game.get_node("organism/StarterCell")
    var boundary = cell.boundary
    var growth = cell.get_node("GrowthController")
    var area_before: float = boundary.get_area_m2()
    growth.mouse_world_position = boundary.to_global(boundary.outline[0])
    growth.select_anchor_a()
    growth.mouse_world_position = boundary.to_global(boundary.outline[18])
    growth.select_anchor_b()
    growth.mouse_world_position = boundary.to_global(boundary.outline[9])
    growth.start_span_drag()
    expect(growth.dragging, "The selected span can still start a growth drag")
    growth.mouse_world_position = boundary.to_global(
        growth.original_outline[9] + growth.drag_outward_direction * 16.0
    )
    growth.update_growth_preview()
    expect(growth.preview_valid, "A funded outward drag has a valid growth preview")
    growth.finish_growth()
    expect(boundary.get_area_m2() > area_before, "Committing the drag really increases cell area")
    expect(boundary.membrane_sections.size() == 1, "Committed growth keeps a homogeneous membrane continuous")
    var hovered = boundary.get_section_at_local_position(edge_middle(boundary, 40), 2.0)
    expect(is_equal_approx(boundary.get_logical_section_length_m(hovered), boundary.get_perimeter_m()), "After growth, hover still measures the entire membrane")
    game.free()


func test_whole_contour_group_and_hover() -> void:
    var game = fixture()
    var boundary = game.get_node("organism/StarterCell").boundary
    fragment(boundary)
    var sections: Array = boundary.membrane_sections.duplicate()
    var group: Array = boundary.get_contiguous_membrane_sections(sections[1])
    expect(group.size() == 4, "Artificial fragments of one membrane form one logical group")
    boundary.set_selected_section(sections[1].section_id)
    for section in sections:
        expect(boundary.is_section_selected(section), "Whole-membrane selection highlights every fragment")
    var first = boundary.get_section_at_local_position(edge_middle(boundary, 4), 2.0)
    var last = boundary.get_section_at_local_position(edge_middle(boundary, 62), 2.0)
    expect(first == last, "Hover at opposite sides returns the same logical representative")
    expect(is_equal_approx(boundary.get_logical_section_length_m(first), boundary.get_perimeter_m()), "Whole-contour hover reports the complete physical length")
    boundary.clear_selected_section()
    expect(not boundary.is_section_selected(sections[0]), "Clearing hover clears the whole highlight")
    game.free()


func test_closed_contour_seam() -> void:
    var game = fixture()
    var boundary = game.get_node("organism/StarterCell").boundary
    fragment(boundary)
    var sections: Array = boundary.membrane_sections.duplicate()
    sections[1].membrane_type_id = "oxygen_exchange_membrane"
    var group: Array = boundary.get_contiguous_membrane_sections(sections[0])
    expect(group.size() == 3, "A continuous membrane groups across the contour's 0/1 seam")
    expect(group.has(sections[3]) and group.has(sections[2]), "Both tail fragments belong to the seam-crossing group")
    expect(not group.has(sections[1]), "Seam grouping stops at the distinct membrane type")
    var near_start = boundary.get_section_at_local_position(edge_middle(boundary, 2), 2.0)
    var near_end = boundary.get_section_at_local_position(edge_middle(boundary, 68), 2.0)
    expect(near_start == near_end, "Hover is consistent on either side of the 0/1 seam")
    var expected_length: float = boundary.get_perimeter_m() - boundary.get_section_length_m(sections[1])
    expect(is_equal_approx(boundary.get_logical_section_length_m(near_end), expected_length), "Seam group length excludes the other membrane type")
    game.free()


func test_different_types_remain_separate() -> void:
    var game = fixture()
    var boundary = game.get_node("organism/StarterCell").boundary
    fragment(boundary)
    var sections: Array = boundary.membrane_sections.duplicate()
    sections[1].membrane_type_id = "oxygen_exchange_membrane"
    sections[3].membrane_type_id = "oxygen_exchange_membrane"
    expect(boundary.get_contiguous_membrane_sections(sections[0]).size() == 1, "A different type separates otherwise identical membranes")
    expect(not boundary.get_contiguous_membrane_sections(sections[0]).has(sections[2]), "Noncontiguous matching types do not form a single membrane")
    boundary.set_selected_section(sections[0].section_id)
    expect(not boundary.is_section_selected(sections[1]) and not boundary.is_section_selected(sections[2]), "Highlight never crosses intervening membrane types")
    game.free()


func test_contact_identity_and_neighbor_order() -> void:
    var game = fixture()
    var boundary = game.get_node("organism/StarterCell").boundary
    fragment(boundary)
    var sections: Array = boundary.membrane_sections.duplicate()
    for section in [sections[1], sections[2], sections[3]]:
        section.is_external = false
    sections[1].adjacent_cell_ids.assign(["cell_a", "cell_b"])
    sections[2].adjacent_cell_ids.assign(["cell_b", "cell_a"])
    sections[3].adjacent_cell_ids.assign(["cell_c"])
    var group: Array = boundary.get_contiguous_membrane_sections(sections[1])
    expect(group.size() == 2 and group.has(sections[2]), "The same contact groups independently of neighbor-ID order")
    expect(not group.has(sections[0]), "An external membrane never merges into a shared contact")
    expect(not group.has(sections[3]), "Contacts with different cells stay separate")
    game.free()


func test_explicit_junctions_stop_grouping() -> void:
    var game = fixture()
    var boundary = game.get_node("organism/StarterCell").boundary
    fragment(boundary)
    var sections: Array = boundary.membrane_sections.duplicate()
    sections[0].end_junction_id = "junction_a"
    sections[1].start_junction_id = "junction_a"
    sections[2].end_junction_id = "junction_b"
    sections[3].start_junction_id = "junction_b"
    var first_group: Array = boundary.get_contiguous_membrane_sections(sections[0])
    var second_group: Array = boundary.get_contiguous_membrane_sections(sections[1])
    expect(first_group.size() == 2 and first_group.has(sections[3]), "Explicit junctions preserve the seam-side membrane")
    expect(second_group.size() == 2 and second_group.has(sections[2]), "Explicit junctions preserve the opposite membrane")
    expect(not first_group.has(sections[1]), "Matching types do not erase a real junction")
    boundary.set_selected_section(sections[0].section_id)
    expect(not boundary.is_section_selected(sections[1]), "A junction bounds the highlighted logical membrane")
    boundary.split_section_at_t(0.125)
    var split_tail = boundary.get_section_at_t(0.2)
    expect(split_tail.end_junction_id == "junction_a", "A technical split preserves the original real end junction")
    expect(sections[0].end_junction_id.is_empty() and split_tail.start_junction_id.is_empty(), "A technical split does not invent a new junction")
    expect(boundary.get_contiguous_membrane_sections(sections[0]).size() == 3, "Technical pieces still group without crossing the preserved real junction")
    game.free()


func test_replacement_uses_a_snapshot() -> void:
    var game = fixture()
    var boundary = game.get_node("organism/StarterCell").boundary
    fragment(boundary, [0.125, 0.25, 0.5, 0.75])
    var sections: Array = boundary.membrane_sections.duplicate()
    sections[2].membrane_type_id = "oxygen_exchange_membrane"
    sections[4].membrane_type_id = "oxygen_exchange_membrane"
    var signals: Array[int] = [0]
    boundary.membrane_topology_changed.connect(func(): signals[0] += 1)
    expect(boundary.set_section_membrane_type(sections[0].section_id, "oxygen_exchange_membrane"), "The group replacement action succeeds")
    expect(sections[0].membrane_type_id == "oxygen_exchange_membrane" and sections[1].membrane_type_id == "oxygen_exchange_membrane", "Replacement changes every original group member")
    expect(sections[3].membrane_type_id == "basic_membrane", "Replacement never spreads through new matching neighbors into another membrane")
    expect(signals[0] == 1, "One group replacement emits one topology update")
    game.free()


func test_cost_and_display_use_whole_membrane() -> void:
    var game = fixture()
    var cell = game.get_node("organism/StarterCell")
    var boundary = cell.boundary
    fragment(boundary)
    var section = boundary.membrane_sections[2]
    var hover = cell.get_node("MembraneHoverController")
    hover.action_section = section
    var cost: Dictionary = hover._replacement_cost()
    var length_m: float = boundary.get_perimeter_m()
    expect(is_equal_approx(cost.get("lipid", 0.0), length_m * 1.5), "Replacement charges lipids for the entire logical membrane")
    expect(is_equal_approx(cost.get("phosphorus", 0.0), length_m * 0.2), "Replacement charges phosphorus for the entire logical membrane")
    var panel = game.get_node("HUD/MembraneInfoPanel")
    panel.show_section(boundary, section)
    expect("Longueur : %.2f m" % length_m in panel.body_label.text, "Hover diagnostics display the entire logical membrane length")
    var lipids_before: float = cell.inventory.get_amount("lipid")
    hover._on_action(1)
    expect(is_equal_approx(cell.inventory.get_amount("lipid"), lipids_before - cost["lipid"]), "The menu pays the same whole-group cost that it displays")
    game.free()


func test_grouping_preserves_physical_economy() -> void:
    var game = fixture()
    var cell = game.get_node("organism/StarterCell")
    var boundary = cell.boundary
    fragment(boundary)
    var sections: Array = boundary.membrane_sections.duplicate()
    var original_outline: PackedVector2Array = boundary.outline.duplicate()
    var inventory: Dictionary = cell.inventory.amounts.duplicate()
    cell.recalculate_membrane_maintenance()
    var upkeep_before: float = cell.membrane_maintenance_atp_per_second
    var oxygen_before: float = cell.oxygen_conductance
    var larger_outline := PackedVector2Array()
    for point in original_outline:
        larger_outline.append(point * 1.1)
    var economy = cell.get_node("GrowthController").growth_economy
    var cost_before: Dictionary = economy.calculate_cost(boundary, original_outline, larger_outline)
    for section in sections:
        boundary.get_contiguous_membrane_sections(section)
        boundary.get_logical_section_length_m(section)
        boundary.set_selected_section(section.section_id)
    cell.recalculate_membrane_maintenance()
    var cost_after: Dictionary = economy.calculate_cost(boundary, original_outline, larger_outline)
    expect(boundary.membrane_sections == sections, "Selection groups do not replace or mutate physical fragments")
    expect(boundary.outline == original_outline, "Grouping leaves the physical contour unchanged")
    expect(cell.inventory.amounts == inventory, "Hover grouping never spends resources")
    expect(is_equal_approx(cell.membrane_maintenance_atp_per_second, upkeep_before), "Grouping does not double-count membrane upkeep")
    expect(is_equal_approx(cell.oxygen_conductance, oxygen_before), "Grouping does not double-count oxygen permeability")
    expect(cost_before == cost_after, "Growth costs still count physical membrane pieces exactly once")
    game.free()
