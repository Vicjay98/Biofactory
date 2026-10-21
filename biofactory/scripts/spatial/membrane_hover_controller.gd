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
var _membrane_type_actions: Dictionary[int, String] = {}


func _ready() -> void:
    cell = boundary.get_parent()
    action_menu = PopupMenu.new()
    action_menu.name = "MembraneActions"
    action_menu.add_theme_color_override("font_disabled_color", Color(0.65, 0.65, 0.65))
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
        _build_membrane_menu()
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


func _replacement_cost(type_id: String = "") -> Dictionary[String, float]:
    var cost: Dictionary[String, float] = {}
    var target: String = _replacement_type() if type_id.is_empty() else type_id
    var data = MembraneTypeDatabase.get_membrane_type(target)
    if data == null:
        return cost
    var length_m: float = boundary.get_logical_section_length_m(action_section)
    for resource_id in data.build_cost_per_meter:
        cost[resource_id] = data.build_cost_per_meter[resource_id] * length_m
    return cost


func _can_pay(cost: Dictionary[String, float]) -> bool:
    for resource_id in cost:
        if not cell.inventory.has_amount(resource_id, cost[resource_id]):
            return false
    return true


func _build_membrane_menu() -> void:
    action_menu.clear()
    _membrane_type_actions.clear()
    action_menu.add_item("", 0)
    action_menu.add_item("", 3)
    action_menu.add_separator()
    var types: Array = MembraneTypeDatabase.get_all_membrane_types()
    for index in range(types.size()):
        var data = types[index]
        var action_id: int = 1 if data.id == _replacement_type() else 10 + index
        _membrane_type_actions[action_id] = data.id
        action_menu.add_item(data.display_name, action_id)


func _update_menu() -> void:
    if action_section == null or cell.physiology == null:
        return
    var physiology = cell.physiology
    var oxygen_index: int = action_menu.get_item_index(0)
    var wait: float = physiology.manual_cooldown_remaining
    var text: String = "Absorber %.0f O₂ (secours)" % physiology.profile.manual_oxygen_amount
    if wait > 0.0:
        text += " · %.1f s" % wait
    action_menu.set_item_text(oxygen_index, text)
    action_menu.set_item_disabled(oxygen_index, not action_section.is_external or wait > 0.0 or physiology.get_oxygen_ratio() >= physiology.profile.ambient_oxygen)
    var nutrient_index: int = action_menu.get_item_index(3)
    if nutrient_index >= 0:
        wait = physiology.nutrient_cooldown_remaining
        text = "Absorber %.0f nutriments (secours)" % physiology.profile.manual_nutrient_amount
        if wait > 0.0:
            text += " · %.1f s" % wait
        action_menu.set_item_text(nutrient_index, text)
        action_menu.set_item_disabled(nutrient_index, not action_section.is_external or wait > 0.0 or physiology.get_nutrient_ratio() >= physiology.profile.ambient_nutrient)
    for action_id in _membrane_type_actions:
        var type_id: String = _membrane_type_actions[action_id]
        var data = MembraneTypeDatabase.get_membrane_type(type_id)
        var equipped: bool = type_id == action_section.membrane_type_id
        var locked: bool = data.requires_stabilized_cell and not physiology.stabilized
        var costs := PackedStringArray()
        var available := PackedStringArray()
        var cost: Dictionary[String, float] = _replacement_cost(type_id)
        for resource_id in cost:
            var resource_name: String = ResourceDatabase.get_resource(resource_id).display_name
            costs.append("%.1f %s" % [cost[resource_id], resource_name])
            available.append("%.1f %s" % [cell.inventory.get_amount(resource_id), resource_name])
        var index: int = action_menu.get_item_index(action_id)
        text = data.display_name + " (équipé)" if equipped else data.display_name + " · " + ", ".join(costs)
        if locked and not equipped:
            text += " · après stabilisation"
        action_menu.set_item_text(index, text)
        action_menu.set_item_disabled(index, equipped or locked or not action_section.is_external or not data.allowed_external or not _can_pay(cost))
        var upkeep: float = boundary.get_logical_section_length_m(action_section) * data.maintenance_atp_per_meter_per_second
        action_menu.set_item_tooltip(index, data.description + "\nDisponible : " + ", ".join(available) + "\nEntretien de cette membrane : %.2f ATP/s" % upkeep)


func _change_membrane(type_id: String) -> bool:
    if action_section == null or not boundary.membrane_sections.has(action_section) or not action_section.is_external:
        return false
    if not MembraneTypeDatabase.has_membrane_type(type_id) or type_id == action_section.membrane_type_id:
        return false
    var data = MembraneTypeDatabase.get_membrane_type(type_id)
    if not data.allowed_external or (data.requires_stabilized_cell and not cell.physiology.stabilized):
        return false
    var cost: Dictionary[String, float] = _replacement_cost(type_id)
    if not _can_pay(cost) or not boundary.set_section_membrane_type(action_section.section_id, type_id):
        return false
    for resource_id in cost:
        cell.inventory.remove_resource(resource_id, cost[resource_id])
    return true


func _on_action(action: int) -> void:
    if action == 2:
        if construction_palette != null:
            construction_palette.open_for_cell(cell)
        return
    if action_section == null or not boundary.membrane_sections.has(action_section):
        return
    if action == 0:
        cell.physiology.absorb_oxygen(action_section)
    elif action == 3:
        cell.physiology.absorb_nutrients(action_section)
    elif _membrane_type_actions.has(action):
        _change_membrane(_membrane_type_actions[action])
    elif action == 1:
        _change_membrane(_replacement_type())
