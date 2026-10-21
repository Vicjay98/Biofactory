extends Control


@onready var membrane_button: Button = $Panel/VBox/MembraneButton
@onready var atp_factory_button: Button = $Panel/VBox/ATPFactoryButton

var membrane_data: BuildingData = preload(
	"res://data/buildings/membrane.tres"
)

var atp_factory_data: BuildingData = preload(
	"res://data/buildings/atp_factory.tres"
)

@onready var build_controller: Node2D = $"../organism/BuildController"


func _ready() -> void:

    membrane_button.pressed.connect(_on_membrane_button_pressed)
    atp_factory_button.pressed.connect(_on_atp_factory_button_pressed)

    update_menu()


func _process(_delta: float) -> void:

    update_menu()


func update_menu() -> void:

    update_building_button(
        membrane_button,
        membrane_data
    )

    update_building_button(
        atp_factory_button,
        atp_factory_data
    )


func update_building_button(
    button: Button,
    building_data: BuildingData
) -> void:

    var cost_text := ""

    for resource_id in building_data.build_cost:

        var amount: float = building_data.build_cost[resource_id]

        cost_text += resource_id + " : " + str(amount)

    button.text = building_data.display_name + " — " + cost_text

    button.disabled = not can_pay_cost(building_data)


func can_pay_cost(building_data: BuildingData) -> bool:

    for resource_id in building_data.build_cost:

        var amount: float = building_data.build_cost[resource_id]

        if not ResourceManager.has_amount(
            resource_id,
            amount
        ):
            return false

    return true


func _on_membrane_button_pressed() -> void:

    build_controller.select_building(membrane_data)


func _on_atp_factory_button_pressed() -> void:

    build_controller.select_building(atp_factory_data)
