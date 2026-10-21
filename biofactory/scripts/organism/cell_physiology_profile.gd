class_name CellPhysiologyProfile
extends Resource

## First playable balance. All amounts refer to the owning cell's inventory.
@export_range(0.0, 10.0, 0.001) var basal_atp_per_m2_per_second: float = 0.04
@export_range(0.01, 100.0, 0.1) var oxygen_capacity_per_m2: float = 2.0
@export_range(0.0, 100.0, 0.1) var ambient_oxygen: float = 1.0
@export_range(0.0, 1.0, 0.01) var critical_oxygen_ratio: float = 0.02
@export_range(0.0, 1.0, 0.01) var low_oxygen_ratio: float = 0.15
@export_range(0.0, 100.0, 0.1) var critical_atp: float = 2.0
@export_range(0.0, 100.0, 0.1) var low_atp: float = 12.0
## A metabolic floor avoids an ATP shortage permanently disabling ATP production.
@export_range(0.1, 1.0, 0.05) var stressed_metabolism: float = 0.65
@export_range(0.1, 60.0, 0.1) var manual_oxygen_amount: float = 2.0
@export_range(0.1, 60.0, 0.1) var manual_oxygen_cooldown: float = 4.0
@export_range(1.0, 120.0, 1.0) var stabilization_seconds: float = 20.0
