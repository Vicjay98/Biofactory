extends Camera2D

@export var move_speed: float = 500.0
@export var zoom_speed: float = 0.1
@export var min_zoom: float = 0.5
@export var max_zoom: float = 2.0


func _process(delta: float) -> void:
    var direction := Vector2.ZERO

    if Input.is_key_pressed(KEY_Z):
        direction.y -= 1

    if Input.is_key_pressed(KEY_S):
        direction.y += 1

    if Input.is_key_pressed(KEY_Q):
        direction.x -= 1

    if Input.is_key_pressed(KEY_D):
        direction.x += 1

    if direction != Vector2.ZERO:
        direction = direction.normalized()
        position += direction * move_speed * delta


func _unhandled_input(event: InputEvent) -> void:

    if event is InputEventMouseButton:

        if event.button_index == MOUSE_BUTTON_WHEEL_UP:
            zoom_camera(zoom_speed)

        elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
            zoom_camera(-zoom_speed)


func zoom_camera(amount: float) -> void:

    var new_zoom := zoom.x + amount

    new_zoom = clamp(
        new_zoom,
        min_zoom,
        max_zoom
    )

    zoom = Vector2.ONE * new_zoom
