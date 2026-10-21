extends Control


@export var construction_controller: Node
@export var building_catalog: Resource


@onready var factory_button: Button = (
    $Panel/VBox/FactoryButton
)

@onready var storage_button: Button = (
    $Panel/VBox/StorageButton
)

@onready var pipe_button: Button = (
    $Panel/VBox/PipeButton
)


func _ready() -> void:
    factory_button.pressed.connect(
        select_factory
    )

    storage_button.pressed.connect(
        select_storage
    )

    pipe_button.pressed.connect(
        select_pipe
    )


func select_factory() -> void:
    select_building(0)


func select_storage() -> void:
    select_building(1)


func select_pipe() -> void:
    select_building(2)


func select_building(index: int) -> void:
    if construction_controller == null:
        return

    if building_catalog == null:
        return

    if index < 0:
        return

    if index >= building_catalog.buildings.size():
        return

    var selected_data = (
        building_catalog.buildings[index]
    )

    if selected_data == null:
        return

    construction_controller.building_data = (
        selected_data
    )

    construction_controller.construction_active = true
