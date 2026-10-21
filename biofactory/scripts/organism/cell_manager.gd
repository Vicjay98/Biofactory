extends Node


signal cell_registered(cell)
signal cell_unregistered(cell)
signal active_cell_changed(cell)


var cells: Array = []

var active_cell = null


func register_cell(cell) -> void:

    if cell == null:
        return

    if cell in cells:
        return

    for existing_cell in cells:

        if existing_cell == null:
            continue

        if existing_cell.cell_id == cell.cell_id:

            push_error(
				"ID de cellule dupliqué : "
                + cell.cell_id
            )

            return

    cells.append(cell)

    cell_registered.emit(cell)

    if active_cell == null:
        set_active_cell(cell)


func unregister_cell(cell) -> void:

    if cell not in cells:
        return

    cells.erase(cell)

    cell_unregistered.emit(cell)

    if active_cell != cell:
        return

    active_cell = null

    if not cells.is_empty():
        set_active_cell(cells[0])

    else:
        ResourceManager.bind_main_inventory(null)

        active_cell_changed.emit(null)


func set_active_cell(cell) -> void:

    if cell != null and cell not in cells:

        push_warning(
			"Impossible d'activer une cellule non enregistrée."
        )

        return

    active_cell = cell

    if active_cell != null and active_cell.inventory != null:

        ResourceManager.bind_main_inventory(
            active_cell.inventory
        )

    else:

        ResourceManager.bind_main_inventory(null)

    active_cell_changed.emit(active_cell)


func get_cell_by_id(cell_id: String):

    for cell in cells:

        if cell == null:
            continue

        if cell.cell_id == cell_id:
            return cell

    return null


func get_cell_count() -> int:

    return cells.size()
