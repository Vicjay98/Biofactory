extends Control


@onready var panel: PanelContainer = $Panel
@onready var title_label: Label = $Panel/VBox/Header/Title
@onready var close_button: Button = $Panel/VBox/Header/Close
@onready var body_label: Label = $Panel/VBox/Body

var target_cell: Node2D
var pinned: bool = false
var dismissed_cell: Node2D
var _refresh_elapsed: float = 0.0


func _ready() -> void:
    close_button.pressed.connect(close)
    hide()


func _process(delta: float) -> void:
    if not visible:
        return
    _refresh_elapsed += delta
    if _refresh_elapsed >= 0.2:
        _refresh_elapsed = 0.0
        refresh_contents()


func show_hovered_cell(cell: Node2D) -> void:
    if pinned or cell == dismissed_cell:
        return
    target_cell = cell
    refresh_contents()
    show()


func leave_cell(cell: Node2D) -> void:
    if cell == dismissed_cell:
        dismissed_cell = null
    if not pinned and target_cell == cell:
        target_cell = null
        hide()


func toggle_pinned_cell(cell: Node2D) -> void:
    if pinned and target_cell == cell:
        dismissed_cell = cell
        pinned = false
        target_cell = null
        hide()
        return
    dismissed_cell = null
    pinned = true
    target_cell = cell
    if cell.cell_manager != null:
        cell.cell_manager.set_active_cell(cell)
    refresh_contents()
    show()


func close() -> void:
    dismissed_cell = target_cell
    pinned = false
    target_cell = null
    hide()


func refresh_contents() -> void:
    if not is_instance_valid(target_cell) or target_cell.physiology == null:
        close()
        return
    var physiology = target_cell.physiology
    var inventory = target_cell.inventory
    title_label.text = target_cell.display_name + " · " + physiology.get_status_name()
    close_button.visible = pinned
    var lines := PackedStringArray()
    # Keep the same resource order as the moving cytoplasm panel.
    lines.append("ATP : %.1f · Production : %.2f/s" % [inventory.get_amount("atp"), physiology.atp_production_per_second])
    lines.append("O₂ : %.1f · Entrée : %.2f/s" % [inventory.get_amount("oxygen"), physiology.oxygen_intake_per_second])
    lines.append("Nutriments : %.1f · Entrée : %.2f/s" % [inventory.get_amount("nutrient"), physiology.nutrient_intake_per_second])
    lines.append("Surface : %.2f m²" % target_cell.get_area_m2())
    lines.append("Entretien : %.2f ATP/s · Métabolisme : %.0f %%" % [physiology.atp_demand_per_second, physiology.metabolism * 100.0])
    lines.append("")
    lines.append("Diagnostic")
    lines.append("\n".join(physiology.get_alerts()))
    if not pinned:
        lines.append("")
        lines.append("Clic gauche dans le cytoplasme pour épingler.")
    body_label.text = "\n".join(lines)
    panel.reset_size()
