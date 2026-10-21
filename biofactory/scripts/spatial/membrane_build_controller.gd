extends Node2D


@export var membrane_network: Node2D

@export var snap_distance: float = 18.0


var current_junction = null

var mouse_world_position: Vector2 = Vector2.ZERO


func _process(_delta: float) -> void:

    mouse_world_position = get_global_mouse_position()

    queue_redraw()


func _unhandled_input(event: InputEvent) -> void:

    if event is InputEventMouseButton:

        if (
            event.button_index == MOUSE_BUTTON_LEFT
            and event.pressed
        ):

            handle_left_click()

        elif (
            event.button_index == MOUSE_BUTTON_RIGHT
            and event.pressed
        ):

            cancel_current_chain()


func handle_left_click() -> void:

    if membrane_network == null:
        return

    var target_junction = membrane_network.find_nearest_junction(
        mouse_world_position,
        snap_distance
    )

    if current_junction == null:

        if target_junction == null:

            current_junction = membrane_network.create_junction(
                mouse_world_position
            )

        else:

            current_junction = target_junction

        return

    if target_junction == null:

        target_junction = membrane_network.create_junction(
            mouse_world_position
        )

    if target_junction == current_junction:
        return

    membrane_network.create_section(
        current_junction,
        target_junction
    )

    current_junction = target_junction


func cancel_current_chain() -> void:

    current_junction = null

    queue_redraw()


func _draw() -> void:

    if current_junction == null:
        return

    var start_position: Vector2 = to_local(
        current_junction.global_position
    )

    var end_position: Vector2 = to_local(
        mouse_world_position
    )

    draw_line(
        start_position,
        end_position,
        Color(0.5, 0.8, 0.9, 0.5),
        3.0,
        true
    )
