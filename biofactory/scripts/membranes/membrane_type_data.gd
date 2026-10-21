class_name MembraneTypeData
extends Resource


@export_category("Identification")

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""

@export var tags: Array[String] = []


@export_category("Construction")

# Coût pour UN mètre de membrane.
@export var build_cost_per_meter: Dictionary[String, float] = {}


@export_category("Energy")

# ATP consommé en permanence par mètre de membrane.
@export_range(0.0, 1000.0, 0.001)
var maintenance_atp_per_meter_per_second: float = 0.0


@export_category("Topology")

# Peut exister sur la frontière avec l'environnement.
@export var allowed_external: bool = true

# Peut servir d'interface entre deux cellules.
@export var allowed_shared: bool = true

@export_category("Oxygen Exchange")
## Passive intake per meter for a unit external/internal concentration difference.
@export_range(0.0, 10.0, 0.001)
var oxygen_permeability_per_meter_per_second: float = 0.005

@export_category("Nutrient Exchange")
@export_range(0.0, 10.0, 0.001)
var nutrient_permeability_per_meter_per_second: float = 0.005

@export_category("Progression")
@export var requires_stabilized_cell: bool = false


@export_category("Visual")

@export var display_color: Color = Color(
    0.45,
    0.85,
    0.95
)

@export_range(1.0, 30.0, 0.5)
var display_width: float = 5.0
