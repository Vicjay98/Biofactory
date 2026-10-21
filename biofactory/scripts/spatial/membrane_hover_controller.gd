extends Node


@export var boundary: Node2D
@export var info_panel: Control
@export var growth_controller: Node
@export var construction_palette: Control
@export var hover_distance_pixels: float = 14.0

var hovered_section
var hovered_section_id: String = ""
var action_section
var action_menu: PopupMenu
var cell: Node2D
var membrane_menu: bool = true


func _ready() -> void:
    cell = boundary.get_parent()
    action_menu = PopupMenu.new()
    action_menu.name = "MembraneActions"
    action_menu.add_item("Absorber un peu d'O₂ (secours)", 0)
    action_menu.add_item("", 1)
    action_menu.id_pressed.connect(_on_action)
    add_child(action_menu)


func _process(_delta: float) -> void:
    if action_menu.visible:
        if membrane_menu:
            _update_menu()
    else:
        update_hover()


func _unhandled_input(event: InputEvent) -> void:
    if not event is InputEventMouseButton or not event.pressed:
        return
    if event.button_index != MOUSE_BUTTON_RIGHT:
        return
    if growth_controller != null and growth_controller.has_active_selection():
        return
    if hovered_section != null:
        action_section = hovered_section
        membrane_menu = true
        action_menu.clear()
        action_menu.add_item("", 0)
        action_menu.add_item("", 1)
        _update_menu()
    elif boundary.contains_local_point(boundary.get_local_mouse_position()):
        membrane_menu = false
        action_menu.clear()
        action_menu.add_item("Construction", 2)
    else:
        return
    info_panel.hide()
    action_menu.position = Vector2i(get_viewport().get_mouse_position())
    action_menu.popup()
    get_viewport().set_input_as_handled()


func update_hover() -> void:
    if boundary == null or info_panel == null or cell.physiology == null:
        return
    var control: Control = get_viewport().gui_get_hovered_control()
    if control != null and control.mouse_filter != Control.MOUSE_FILTER_IGNORE:
        clear_hover()
        return
    var mouse_local: Vector2 = boundary.get_local_mouse_position()
    var section = boundary.get_section_at_local_position(mouse_local, hover_distance_pixels)
    if section != null:
        hovered_section = section
        hovered_section_id = section.section_id
        boundary.set_selected_section(section.section_id)
        info_panel.show_section(boundary, section)
        return
    hovered_section = null
    hovered_section_id = ""
    boundary.clear_selected_section()
    for building in cell.buildings:
        if is_instance_valid(building) and building.contains_local_point(building.get_local_mouse_position()):
            info_panel.show_building(building)
            return
    if boundary.contains_local_point(mouse_local):
        info_panel.show_cell(cell)
    else:
        info_panel.hide()


func clear_hover() -> void:
    hovered_section = null
    hovered_section_id = ""
    boundary.clear_selected_section()
    if info_panel != null:
        info_panel.hide()


func _replacement_type() -> String:
    return "basic_membrane" if action_section.membrane_type_id == "oxygen_exchange_membrane" else "oxygen_exchange_membrane"


func _replacement_cost() -> Dictionary[String, float]:
    var cost: Dictionary[String, float] = {}
    var data = MembraneTypeDatabase.get_membrane_type(_replacement_type())
    var length_m: float = boundary.get_section_length_m(action_section)
    for resource_id in data.build_cost_per_meter:
        cost[resource_id] = data.build_cost_per_meter[resource_id] * length_m
    return cost


func _can_pay(cost: Dictionary[String, float]) -> bool:
    for resource_id in cost:
        if not cell.inventory.has_amount(resource_id, cost[resource_id]):
            return false
    return true


func _update_menu() -> void:
    if action_section == null or cell.physiology == null:
        return
    var physiology = cell.physiology
    var wait: float = physiology.manual_cooldown_remaining
    var absorption_text: String = "Absorber %.0f O₂ (secours)" % physiology.profile.manual_oxygen_amount
    if wait > 0.0:
        absorption_text += " · %.1f s" % wait
    action_menu.set_item_text(0, absorption_text)
    action_menu.set_item_disabled(0, not action_section.is_external or wait > 0.0 or physiology.get_oxygen_ratio() >= physiology.profile.ambient_oxygen)
    var data = MembraneTypeDatabase.get_membrane_type(_replacement_type())
    var costs := PackedStringArray()
    var cost: Dictionary[String, float] = _replacement_cost()
    for resource_id in cost:
        costs.append("%.1f %s" % [cost[resource_id], ResourceDatabase.get_resource(resource_id).display_name])
    action_menu.set_item_text(1, data.display_name + " · " + ", ".join(costs))
    action_menu.set_item_disabled(1, not action_section.is_external or not _can_pay(cost))


func _on_action(action: int) -> void:
    if action == 2:
        if construction_palette != null:
            construction_palette.open_for_cell(cell)
        return
    if action_section == null or not boundary.membrane_sections.has(action_section):
        return
    if action == 0:
        cell.physiology.absorb_oxygen(action_section)
        return
    if action != 1 or not action_section.is_external:
        return
    var cost: Dictionary[String, float] = _replacement_cost()
    if not _can_pay(cost):
        return
    var replacement: String = _replacement_type()
    if not boundary.set_section_membrane_type(action_section.section_id, replacement):
        return
    for resource_id in cost:
        cell.inventory.remove_resource(resource_id, cost[resource_id])
