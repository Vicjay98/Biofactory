extends Control


@onready var resource_list: VBoxContainer = $Panel/VBox


var labels_by_resource_id: Dictionary[String, Label] = {}


func _ready() -> void:

    create_resource_labels()

    ResourceManager.resources_changed.connect(
        update_display
    )

    update_display()


func create_resource_labels() -> void:

    for child in resource_list.get_children():
        child.queue_free()

    labels_by_resource_id.clear()

    for resource_data in ResourceDatabase.get_all_resources():

        if resource_data == null:
            continue

        var label := Label.new()

        resource_list.add_child(label)

        labels_by_resource_id[resource_data.id] = label


func update_display() -> void:

    for resource_data in ResourceDatabase.get_all_resources():

        if resource_data == null:
            continue

        if not labels_by_resource_id.has(resource_data.id):
            continue

        var label: Label = labels_by_resource_id[
            resource_data.id
        ]

        var amount: float = ResourceManager.get_amount(
            resource_data.id
        )

        label.text = (
            resource_data.display_name
            + " : "
            + str(amount)
            + " "
            + resource_data.unit_name
        )
