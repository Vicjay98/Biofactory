extends Node


@export var boundary: Node2D
@export var info_panel: Control
@export var growth_controller: Node

@export var hover_distance_pixels: float = 14.0


var hovered_section = null
var hovered_section_id: String = ""


func _process(_delta: float) -> void:

    update_hover()


func _unhandled_input(
    event: InputEvent
) -> void:

    if not (
        event is InputEventMouseButton
    ):
        return

    if not event.pressed:
        return

    if event.button_index != MOUSE_BUTTON_RIGHT:
        return

    if hovered_section == null:
        return

    if (
        growth_controller != null
        and growth_controller.has_active_selection()
    ):
        return

    toggle_hovered_membrane_type()

    get_viewport().set_input_as_handled()


func update_hover() -> void:

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
            hover_distance_pixels
        )
    )

    if section == null:

        clear_hover()

        return

    hovered_section = section
    hovered_section_id = section.section_id

    boundary.set_selected_section(
        section.section_id
    )

    if info_panel != null:

        info_panel.show_section(
            boundary,
            section
        )


func clear_hover() -> void:

    if (
        hovered_section == null
        and hovered_section_id.is_empty()
    ):
        return

    hovered_section = null
    hovered_section_id = ""

    if boundary != null:

        boundary.clear_selected_section()

    if info_panel != null:

        info_panel.hide()


func toggle_hovered_membrane_type() -> void:

    if hovered_section == null:
        return

    var new_type_id: String = ""

    match hovered_section.membrane_type_id:

        "basic_membrane":

            new_type_id = (
				"oxygen_exchange_membrane"
            )

        "oxygen_exchange_membrane":

            new_type_id = (
				"basic_membrane"
            )

        _:

            new_type_id = (
				"basic_membrane"
            )

    var changed: bool = (
        boundary.set_section_membrane_type(
            hovered_section.section_id,
            new_type_id
        )
    )

    if not changed:
        return

    if info_panel != null:

        info_panel.show_section(
            boundary,
            hovered_section
        )
