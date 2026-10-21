extends Control


@onready var panel: PanelContainer = $Panel
@onready var title_label: Label = $Panel/VBox/Title
@onready var body_label: Label = $Panel/VBox/Body

var target_cell: Node2D
var target_building: Node2D
var target_section
var _refresh_elapsed: float = 0.0


func _ready() -> void:
    hide()


func _process(delta: float) -> void:
    if not visible:
        return
    _refresh_elapsed += delta
    if _refresh_elapsed >= 0.2:
        _refresh_elapsed = 0.0
        refresh_contents()
    update_position_near_mouse()


func show_section(boundary, section) -> void:
    if visible and target_section == section and target_cell == boundary.get_parent():
        return
    target_cell = boundary.get_parent()
    target_section = section
    target_building = null
    _show_target()


func show_cell(cell: Node2D) -> void:
    if visible and target_cell == cell and target_section == null and target_building == null:
        return
    target_cell = cell
    target_building = null
    target_section = null
    _show_target()


func show_building(building: Node2D) -> void:
    if visible and target_building == building:
        return
    target_building = building
    target_cell = building.owning_cell
    target_section = null
    _show_target()


func _show_target() -> void:
    refresh_contents()
    show()
    update_position_near_mouse()


func refresh_contents() -> void:
    if not is_instance_valid(target_cell) or target_cell.physiology == null:
        hide()
        return
    var physiology = target_cell.physiology
    var inventory = target_cell.inventory
    var lines := PackedStringArray()
    if is_instance_valid(target_building):
        title_label.text = target_building.data.display_name
        lines.append(target_building.data.description)
        var processor = target_building.recipe_processor
        if processor != null:
            if processor.cycle_running:
                lines.append("Cycle en cours : %.0f %%" % (processor.get_progress_ratio() * 100.0))
            else:
                lines.append("En attente de ressources" if not target_building.is_functional else "Prête")
            lines.append("Par cycle : %s → %s" % [
                _recipe_amounts(processor.recipe.inputs),
                _recipe_amounts(processor.recipe.outputs)
            ])
            lines.append("Métabolisme de la cellule : %.0f %%" % (physiology.metabolism * 100.0))
        for problem in target_building.problems:
            lines.append("⚠ " + problem)
    elif target_section != null:
        var data = MembraneTypeDatabase.get_membrane_type(target_section.membrane_type_id)
        var length_m: float = target_cell.boundary.get_section_length_m(target_section)
        title_label.text = data.display_name
        lines.append(data.description)
        lines.append("Longueur : %.2f m" % length_m)
        lines.append("Entretien : %.2f ATP/s" % (length_m * data.maintenance_atp_per_meter_per_second))
        var gradient: float = maxf(physiology.profile.ambient_oxygen - physiology.get_oxygen_ratio(), 0.0)
        var intake: float = length_m * data.oxygen_permeability_per_meter_per_second * gradient
        if not target_section.is_external:
            intake = 0.0
        lines.append("O₂ entrant par cette section : %.2f/s" % intake)
        lines.append("Clic droit : secours O₂ ou spécialisation")
    else:
        title_label.text = target_cell.display_name + " · " + physiology.get_state_name()
        lines.append("Surface : %.2f m²" % target_cell.get_area_m2())
        lines.append("O₂ : %.1f · Entrée : %.2f/s" % [inventory.get_amount("oxygen"), physiology.oxygen_intake_per_second])
        lines.append("ATP : %.1f · Production : %.2f/s" % [inventory.get_amount("atp"), physiology.atp_production_per_second])
        lines.append("Entretien total : %.2f ATP/s" % physiology.atp_demand_per_second)
        lines.append("Métabolisme : %.0f %%" % (physiology.metabolism * 100.0))
    lines.append("")
    lines.append("Diagnostic de la cellule")
    lines.append("\n".join(physiology.get_alerts()))
    body_label.text = "\n".join(lines)
    panel.reset_size()


func _recipe_amounts(amounts: Dictionary[String, float]) -> String:
    var parts := PackedStringArray()
    for resource_id in amounts:
        var data = ResourceDatabase.get_resource(resource_id)
        parts.append("%.1f %s" % [amounts[resource_id], data.display_name])
    return " + ".join(parts)


func update_position_near_mouse() -> void:
    var desired: Vector2 = get_viewport().get_mouse_position() + Vector2(22.0, 18.0)
    var limit: Vector2 = get_viewport_rect().size - panel.size - Vector2(8.0, 8.0)
    position = desired.clamp(Vector2(8.0, 8.0), limit.max(Vector2(8.0, 8.0)))
