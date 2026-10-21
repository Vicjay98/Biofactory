extends Node


@export var boundary: Node2D
@export var info_panel: Control

@export var selection_distance_pixels: float = 14.0


func _unhandled_input(
    event: InputEvent
) -> void:

    if not (
        event is InputEventMouseButton
    ):
        return

    if not event.pressed:
        return

    if event.button_index != MOUSE_BUTTON_LEFT:
        return

    if not event.shift_pressed:
        return

    select_at_mouse()

    get_viewport().set_input_as_handled()


func select_at_mouse() -> void:

    if boundary == null:
        return

    var mouse_world: Vector2 = (
        boundary.get_global_mouse_position()
    )

    var mouse_local: Vector2 = (
        boundary.to_local(
            mouse_world
        )
    )

    var section = (
        boundary.get_section_at_local_position(
            mouse_local,
            selection_distance_pixels
        )
    )

    if section == null:

        boundary.clear_selected_section()

        if info_panel != null:
            info_panel.hide()

        return

    boundary.set_selected_section(
        section.section_id
    )

    if info_panel != null:

        info_panel.show_section(
            boundary,
            section
        )
