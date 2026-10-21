extends Control


@onready var panel: PanelContainer = $Panel

@onready var title_label: Label = (
    $Panel/VBox/Title
)

@onready var type_label: Label = (
    $Panel/VBox/TypeLabel
)

@onready var description_label: Label = (
    $Panel/VBox/DescriptionLabel
)

@onready var length_label: Label = (
    $Panel/VBox/LengthLabel
)

@onready var maintenance_label: Label = (
    $Panel/VBox/MaintenanceLabel
)


func _ready() -> void:

    set_mouse_ignore_recursive(
        self
    )

    hide()


func _process(_delta: float) -> void:

    if visible:
        update_position_near_mouse()


func set_mouse_ignore_recursive(
    control: Control
) -> void:

    control.mouse_filter = (
        Control.MOUSE_FILTER_IGNORE
    )

    for child in control.get_children():

        if child is Control:

            set_mouse_ignore_recursive(
                child
            )


func show_section(
    boundary,
    section
) -> void:

    if boundary == null:
        hide()
        return

    if section == null:
        hide()
        return

    var membrane_data = (
        MembraneTypeDatabase.get_membrane_type(
            section.membrane_type_id
        )
    )

    if membrane_data == null:
        hide()
        return

    var length_m: float = (
        boundary.get_section_length_m(
            section
        )
    )

    var maintenance_atp: float = (
        length_m
        * membrane_data
            .maintenance_atp_per_meter_per_second
    )

    title_label.text = (
        membrane_data.display_name
    )

    type_label.text = (
		"Type : "
        + membrane_data.display_name
    )

    description_label.text = (
        membrane_data.description
    )

    length_label.text = (
		"Longueur : "
        + str(
            snapped(
                length_m,
                0.01
            )
        )
        + " m"
    )

    maintenance_label.text = (
		"Entretien : "
        + str(
            snapped(
                maintenance_atp,
                0.001
            )
        )
        + " ATP/s"
    )

    show()

    update_position_near_mouse()


func update_position_near_mouse() -> void:

    var mouse_position: Vector2 = (
        get_viewport().get_mouse_position()
    )

    var desired_position: Vector2 = (
        mouse_position
        + Vector2(
            20.0,
            20.0
        )
    )

    var viewport_size: Vector2 = (
        get_viewport_rect().size
    )

    var panel_size: Vector2 = panel.size

    desired_position.x = clamp(
        desired_position.x,
        0.0,
        max(
            0.0,
            viewport_size.x - panel_size.x
        )
    )

    desired_position.y = clamp(
        desired_position.y,
        0.0,
        max(
            0.0,
            viewport_size.y - panel_size.y
        )
    )

    position = desired_position
