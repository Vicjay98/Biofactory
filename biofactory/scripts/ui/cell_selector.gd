extends Control


@export var cell_manager: Node

@onready var cell_option: OptionButton = $Panel/VBox/CellOption


func _ready() -> void:

    if cell_manager == null:
        push_error(
			"CellSelector : aucun CellManager assigné."
        )
        return

    cell_manager.cell_registered.connect(
        _on_cell_registered
    )

    cell_manager.cell_unregistered.connect(
        _on_cell_unregistered
    )

    cell_manager.active_cell_changed.connect(
        _on_active_cell_changed
    )

    cell_option.item_selected.connect(
        _on_cell_selected
    )

    rebuild_cell_list()


func rebuild_cell_list() -> void:

    cell_option.clear()

    for cell in cell_manager.cells:

        if cell == null:
            continue

        cell_option.add_item(
            cell.display_name
        )

    update_selected_cell()


func update_selected_cell() -> void:

    if cell_manager.active_cell == null:
        return

    for index in range(cell_manager.cells.size()):

        var cell = cell_manager.cells[index]

        if cell == cell_manager.active_cell:

            cell_option.select(index)

            return


func _on_cell_selected(index: int) -> void:

    if index < 0:
        return

    if index >= cell_manager.cells.size():
        return

    var selected_cell = cell_manager.cells[index]

    cell_manager.set_active_cell(
        selected_cell
    )


func _on_cell_registered(_cell) -> void:

    rebuild_cell_list()


func _on_cell_unregistered(_cell) -> void:

    rebuild_cell_list()


func _on_active_cell_changed(_cell) -> void:

    update_selected_cell()
