# Mini Planète — CODE_1_SIMULATION_ET_DONNEES

Règles du jeu (simulation pure, testable), données JSON, textes FR/EN et tests.

Version du jeu : 0.6.x — 39 fichiers. Chaque fichier commence par une ligne « ### FICHIER : chemin ». Pour modifier un fichier, renvoie-le EN ENTIER avec son chemin.

## Sommaire
- VERSION
- data/buildings.json
- data/customization.json
- data/events.json
- data/game_config.json
- data/locale/en.json
- data/locale/fr.json
- data/objectives.json
- data/professions.json
- data/resources.json
- data/terrains.json
- data/townhall.json
- data/tutorial.json
- project.godot
- scripts/core/config.gd
- scripts/core/game_state.gd
- scripts/core/localization.gd
- scripts/core/save_manager.gd
- scripts/core/user_settings.gd
- scripts/simulation/economy.gd
- scripts/simulation/events.gd
- scripts/simulation/fixed_stepper.gd
- scripts/simulation/hex_grid.gd
- scripts/simulation/objectives.gd
- scripts/simulation/planet_generator.gd
- scripts/simulation/planet_state.gd
- scripts/simulation/simulation.gd
- tests/run_tests.gd
- tests/test_case.gd
- tests/unit/test_customization.gd
- tests/unit/test_economy.gd
- tests/unit/test_features.gd
- tests/unit/test_fixed_stepper.gd
- tests/unit/test_hex_grid.gd
- tests/unit/test_needs.gd
- tests/unit/test_planet.gd
- tests/unit/test_save_manager.gd
- tests/unit/test_simulation.gd
- tests/unit/test_townhall.gd


### FICHIER : VERSION

```
0.6
```


### FICHIER : data/buildings.json

```json
{
	"_comment": "Buildings. cost/produces in resources; produces = per day with full workers. extracts = takes that resource from its cell and neighbours. territory = buildable radius (in cells) around it. order = position in the build menu; priority = who gets workers first (lower first). consumes = inputs per day (production slows when they run out). tool_bonus = +25% while tools are in stock. water_bonus = multiplier next to water. happiness / health = village bonus while staffed. category = build menu tab. upgrade_to = building it can be upgraded into (paying the target's upgrade_cost). buildable=false hides it from the build menu. profession = trained villagers needed to work here. build_days = construction time (1 day = 60 s at x1).",
	"buildings": {
		"campfire": {
			"name_key": "BLD_CAMPFIRE",
			"desc_key": "BLD_CAMPFIRE_DESC",
			"age": "stone",
			"order": 1,
			"priority": 0,
			"cost": {
				"wood": 8,
				"stone": 5
			},
			"workers": 0,
			"housing": 0,
			"territory": 1,
			"growth_bonus": 1,
			"terrains": [
				"plains",
				"forest",
				"beach",
				"desert",
				"hills"
			],
			"short_key": "BLD_CAMPFIRE_SHORT",
			"category": "housing",
			"happiness": 5,
			"build_days": 0.2
		},
		"hut": {
			"name_key": "BLD_HUT",
			"desc_key": "BLD_HUT_DESC",
			"age": "stone",
			"order": 0,
			"priority": 0,
			"cost": {
				"wood": 10
			},
			"workers": 0,
			"housing": 4,
			"territory": 1,
			"terrains": [
				"plains",
				"forest",
				"beach",
				"desert",
				"hills"
			],
			"short_key": "BLD_HUT_SHORT",
			"category": "housing",
			"upgrade_to": "longhouse",
			"build_days": 0.3
		},
		"gatherer": {
			"name_key": "BLD_GATHERER",
			"desc_key": "BLD_GATHERER_DESC",
			"age": "stone",
			"order": 10,
			"priority": 1,
			"cost": {
				"wood": 5
			},
			"workers": 2,
			"produces": {
				"food": 6
			},
			"fertility_bonus": true,
			"territory": 1,
			"terrains": [
				"plains",
				"forest",
				"beach"
			],
			"short_key": "BLD_GATHERER_SHORT",
			"category": "food",
			"tool_bonus": true,
			"profession": "gatherer",
			"build_days": 0.25
		},
		"woodcutter": {
			"name_key": "BLD_WOODCUTTER",
			"desc_key": "BLD_WOODCUTTER_DESC",
			"age": "stone",
			"order": 20,
			"priority": 2,
			"cost": {
				"wood": 5
			},
			"workers": 2,
			"produces": {
				"wood": 4
			},
			"extracts": "wood",
			"territory": 1,
			"terrains": [
				"plains",
				"forest",
				"beach",
				"desert",
				"hills"
			],
			"short_key": "BLD_WOODCUTTER_SHORT",
			"category": "resources",
			"tool_bonus": true,
			"profession": "woodcutter",
			"build_days": 0.25
		},
		"quarry": {
			"name_key": "BLD_QUARRY",
			"desc_key": "BLD_QUARRY_DESC",
			"age": "stone",
			"order": 21,
			"priority": 3,
			"cost": {
				"wood": 15
			},
			"workers": 3,
			"produces": {
				"stone": 3
			},
			"extracts": "stone",
			"territory": 1,
			"terrains": [
				"plains",
				"forest",
				"beach",
				"desert",
				"hills"
			],
			"short_key": "BLD_QUARRY_SHORT",
			"category": "resources",
			"tool_bonus": true,
			"profession": "stonecutter",
			"build_days": 0.4
		},
		"field": {
			"name_key": "BLD_FIELD",
			"desc_key": "BLD_FIELD_DESC",
			"short_key": "BLD_FIELD_SHORT",
			"age": "stone",
			"category": "food",
			"order": 11,
			"priority": 1,
			"cost": {
				"wood": 10
			},
			"workers": 2,
			"produces": {
				"grain": 10
			},
			"fertility_bonus": true,
			"tool_bonus": true,
			"territory": 1,
			"terrains": [
				"plains",
				"beach"
			],
			"profession": "farmer",
			"build_days": 0.3
		},
		"mill": {
			"name_key": "BLD_MILL",
			"desc_key": "BLD_MILL_DESC",
			"short_key": "BLD_MILL_SHORT",
			"age": "stone",
			"category": "food",
			"order": 12,
			"priority": 2,
			"cost": {
				"wood": 12,
				"stone": 8
			},
			"workers": 1,
			"consumes": {
				"grain": 10
			},
			"produces": {
				"flour": 10
			},
			"territory": 1,
			"terrains": [
				"plains",
				"forest",
				"beach",
				"desert",
				"hills"
			],
			"profession": "miller",
			"build_days": 0.5
		},
		"bakery": {
			"name_key": "BLD_BAKERY",
			"desc_key": "BLD_BAKERY_DESC",
			"short_key": "BLD_BAKERY_SHORT",
			"age": "stone",
			"category": "food",
			"order": 13,
			"priority": 2,
			"cost": {
				"wood": 10,
				"stone": 12
			},
			"workers": 2,
			"consumes": {
				"flour": 8,
				"wood": 1
			},
			"produces": {
				"food": 24
			},
			"happiness": 3,
			"territory": 1,
			"terrains": [
				"plains",
				"forest",
				"beach",
				"desert",
				"hills"
			],
			"profession": "baker",
			"build_days": 0.6
		},
		"well": {
			"name_key": "BLD_WELL",
			"desc_key": "BLD_WELL_DESC",
			"short_key": "BLD_WELL_SHORT",
			"age": "stone",
			"category": "resources",
			"order": 22,
			"priority": 1,
			"cost": {
				"wood": 10
			},
			"workers": 1,
			"produces": {
				"water": 8
			},
			"water_bonus": 1.5,
			"territory": 1,
			"terrains": [
				"plains",
				"forest",
				"beach",
				"desert",
				"hills"
			],
			"profession": "water_carrier",
			"build_days": 0.3
		},
		"workshop": {
			"name_key": "BLD_WORKSHOP",
			"desc_key": "BLD_WORKSHOP_DESC",
			"short_key": "BLD_WORKSHOP_SHORT",
			"age": "stone",
			"category": "resources",
			"order": 23,
			"priority": 4,
			"cost": {
				"wood": 15,
				"stone": 10
			},
			"workers": 2,
			"consumes": {
				"wood": 2,
				"stone": 2
			},
			"produces": {
				"tools": 2
			},
			"territory": 1,
			"terrains": [
				"plains",
				"forest",
				"beach",
				"desert",
				"hills"
			],
			"profession": "artisan",
			"build_days": 0.6
		},
		"healer": {
			"name_key": "BLD_HEALER",
			"desc_key": "BLD_HEALER_DESC",
			"short_key": "BLD_HEALER_SHORT",
			"age": "stone",
			"category": "services",
			"order": 30,
			"priority": 1,
			"cost": {
				"wood": 12,
				"stone": 6
			},
			"workers": 1,
			"health": 15,
			"territory": 1,
			"terrains": [
				"plains",
				"forest",
				"beach",
				"desert",
				"hills"
			],
			"profession": "healer",
			"build_days": 0.6
		},
		"stone_circle": {
			"name_key": "BLD_STONE_CIRCLE",
			"desc_key": "BLD_STONE_CIRCLE_DESC",
			"short_key": "BLD_STONE_CIRCLE_SHORT",
			"age": "stone",
			"category": "services",
			"order": 31,
			"priority": 0,
			"cost": {
				"wood": 10,
				"stone": 15
			},
			"workers": 0,
			"happiness": 10,
			"territory": 1,
			"terrains": [
				"plains",
				"forest",
				"beach",
				"desert",
				"hills"
			],
			"build_days": 0.8
		},
		"longhouse": {
			"name_key": "BLD_LONGHOUSE",
			"desc_key": "BLD_LONGHOUSE_DESC",
			"short_key": "BLD_LONGHOUSE_SHORT",
			"age": "stone",
			"category": "housing",
			"order": 2,
			"priority": 0,
			"buildable": false,
			"upgrade_cost": {
				"wood": 20,
				"stone": 10
			},
			"cost": {
				"wood": 30,
				"stone": 10
			},
			"workers": 0,
			"housing": 9,
			"happiness": 1,
			"territory": 1,
			"terrains": [
				"plains",
				"forest",
				"beach",
				"desert",
				"hills"
			],
			"build_days": 0.8
		},
		"townhall": {
			"name_key": "BLD_TOWNHALL",
			"desc_key": "BLD_TOWNHALL_DESC",
			"short_key": "BLD_TOWNHALL_SHORT",
			"age": "stone",
			"category": "housing",
			"order": -1,
			"priority": 0,
			"buildable": false,
			"cost": {},
			"workers": 0,
			"housing": 0,
			"territory": 3,
			"build_days": 0,
			"terrains": [
				"plains",
				"forest",
				"beach",
				"desert",
				"hills"
			]
		},
		"outpost": {
			"name_key": "BLD_OUTPOST",
			"desc_key": "BLD_OUTPOST_DESC",
			"short_key": "BLD_OUTPOST_SHORT",
			"age": "stone",
			"category": "housing",
			"order": 3,
			"priority": 0,
			"cost": {
				"wood": 30,
				"stone": 20
			},
			"workers": 0,
			"housing": 0,
			"territory": 3,
			"build_days": 0.8,
			"terrains": [
				"plains",
				"forest",
				"beach",
				"desert",
				"hills"
			]
		}
	},
	"start": {
		"stocks": {
			"food": 40,
			"wood": 30,
			"stone": 10,
			"water": 40
		},
		"population": 4,
		"buildings": [
			"townhall"
		],
		"trained": {}
	},
	"categories": [
		{
			"id": "housing",
			"name_key": "CAT_HOUSING"
		},
		{
			"id": "food",
			"name_key": "CAT_FOOD"
		},
		{
			"id": "resources",
			"name_key": "CAT_RESOURCES"
		},
		{
			"id": "services",
			"name_key": "CAT_SERVICES"
		}
	]
}
```


### FICHIER : data/customization.json

```json
{
	"_comment": "Player customization options. Palettes override terrain colors (hex sRGB); missing terrains keep their default color from terrains.json. Skies: top/horizon/bottom gradient colors, stars 0..1, ambient and sun light colors.",
	"planet_sizes": [
		{
			"id": "small",
			"name_key": "SIZE_SMALL",
			"frequency": 8
		},
		{
			"id": "medium",
			"name_key": "SIZE_MEDIUM",
			"frequency": 12
		},
		{
			"id": "large",
			"name_key": "SIZE_LARGE",
			"frequency": 16
		},
		{
			"id": "huge",
			"name_key": "SIZE_HUGE",
			"frequency": 20
		}
	],
	"palettes": {
		"classic": {
			"name_key": "PALETTE_CLASSIC",
			"order": 0,
			"colors": {}
		},
		"autumn": {
			"name_key": "PALETTE_AUTUMN",
			"order": 1,
			"colors": {
				"plains": "c9b458",
				"forest": "c46b2e",
				"hills": "a8834f",
				"beach": "ead9a6",
				"desert": "d9a066"
			}
		},
		"pastel": {
			"name_key": "PALETTE_PASTEL",
			"order": 2,
			"colors": {
				"ocean": "6c9fd8",
				"shallow": "8ec5ea",
				"plains": "a8dba0",
				"forest": "7cbf8e",
				"desert": "f0d9a8",
				"hills": "c3cf9a",
				"mountain": "b0a7b8",
				"beach": "f6e7c1"
			}
		},
		"mars": {
			"name_key": "PALETTE_MARS",
			"order": 3,
			"colors": {
				"ocean": "3b4f7a",
				"shallow": "5672a1",
				"plains": "c8754a",
				"forest": "8f4a3a",
				"desert": "e0a066",
				"hills": "b06a45",
				"mountain": "7a4b3e",
				"beach": "e8c29a",
				"ice": "f2e6e0"
			}
		},
		"frost": {
			"name_key": "PALETTE_FROST",
			"order": 4,
			"colors": {
				"ocean": "244a7a",
				"shallow": "3a6fa8",
				"plains": "b9d6c9",
				"forest": "5f8f86",
				"desert": "d8d2c4",
				"hills": "9fb3b0",
				"beach": "dfe6e8"
			}
		},
		"tropical": {
			"name_key": "PALETTE_TROPICAL",
			"order": 5,
			"colors": {
				"ocean": "1f78b4",
				"shallow": "3fc1c9",
				"beach": "f7e3a1",
				"plains": "5fd068",
				"forest": "1f9e5a",
				"hills": "8cc56a",
				"desert": "f2c46d"
			}
		},
		"golden": {
			"name_key": "PALETTE_GOLDEN",
			"order": 6,
			"colors": {
				"plains": "d8c06a",
				"forest": "a8923a",
				"hills": "c9a75a",
				"desert": "f0cf7a",
				"beach": "f3e2b0",
				"mountain": "9c8466"
			}
		},
		"night": {
			"name_key": "PALETTE_NIGHT",
			"order": 7,
			"colors": {
				"ocean": "141a40",
				"shallow": "243080",
				"beach": "7d6fb3",
				"plains": "3f5fb8",
				"forest": "2a3f8a",
				"hills": "5b5fc2",
				"desert": "9c7fd0",
				"mountain": "6a5a9a",
				"ice": "d8e4ff"
			}
		}
	},
	"village_colors": [
		"d9b45c",
		"c0503a",
		"e07b39",
		"3a7bc0",
		"2fa3a3",
		"5aa35a",
		"8a5ac0",
		"d0568f",
		"e8e8e8",
		"4a4a4a"
	],
	"skies": {
		"soft": {
			"name_key": "SKY_SOFT",
			"order": 0,
			"top": "8ecae6",
			"horizon": "ffe3cf",
			"bottom": "fff1e2",
			"stars": 0.0,
			"ambient": "f3e6ff",
			"sun": "fff0d6"
		},
		"sunset": {
			"name_key": "SKY_SUNSET",
			"order": 1,
			"top": "7a6ad8",
			"horizon": "ffb08a",
			"bottom": "ffd9b8",
			"stars": 0.15,
			"ambient": "ffd8e6",
			"sun": "ffc79a"
		},
		"stars": {
			"name_key": "SKY_STARS",
			"order": 2,
			"top": "141a3a",
			"horizon": "3a3f78",
			"bottom": "241d48",
			"stars": 1.0,
			"ambient": "b8c2ff",
			"sun": "fff0d6"
		},
		"aurora": {
			"name_key": "SKY_AURORA",
			"order": 3,
			"top": "0f3440",
			"horizon": "7fe0c3",
			"bottom": "1d4a52",
			"stars": 0.6,
			"ambient": "cff7ec",
			"sun": "f0fff6"
		},
		"mist": {
			"name_key": "SKY_MIST",
			"order": 4,
			"top": "cfd8e3",
			"horizon": "f5efe6",
			"bottom": "ebe3d8",
			"stars": 0.0,
			"ambient": "f2f0ff",
			"sun": "ffffff"
		}
	},
	"name_syllables": [
		"ka",
		"lo",
		"mi",
		"ra",
		"ze",
		"vu",
		"no",
		"ta",
		"li",
		"so",
		"bel",
		"dra",
		"or",
		"in",
		"ul",
		"ma",
		"pe",
		"ri",
		"go",
		"ny"
	],
	"default_size": 12,
	"water_levels": {
		"islands": {
			"name_key": "WATER_ISLANDS",
			"order": 0,
			"ocean_fraction": 0.7
		},
		"balanced": {
			"name_key": "WATER_BALANCED",
			"order": 1,
			"ocean_fraction": 0.55
		},
		"continents": {
			"name_key": "WATER_CONTINENTS",
			"order": 2,
			"ocean_fraction": 0.38
		}
	},
	"reliefs": {
		"flat": {
			"name_key": "RELIEF_FLAT",
			"order": 0,
			"hills_threshold": 0.62,
			"mountain_threshold": 0.86
		},
		"normal": {
			"name_key": "RELIEF_NORMAL",
			"order": 1,
			"hills_threshold": 0.48,
			"mountain_threshold": 0.7
		},
		"mountains": {
			"name_key": "RELIEF_MOUNTAINS",
			"order": 2,
			"hills_threshold": 0.36,
			"mountain_threshold": 0.56
		}
	},
	"decorations": {
		"_comment": "Cosmetic extras around the planet (per planet).",
		"rings": {
			"name_key": "DECOR_RINGS",
			"default": false
		},
		"moon": {
			"name_key": "DECOR_MOON",
			"default": true
		}
	}
}
```


### FICHIER : data/events.json

```json
{
	"_comment": "Random events with choices. effects: stocks (+/-), population (+/-, newcomers need room), happiness, health (points). weight = relative chance. min_population / min_day = conditions.",
	"events": [
		{
			"id": "travelers",
			"title_key": "EV_TRAVELERS",
			"text_key": "EV_TRAVELERS_TEXT",
			"weight": 3,
			"min_day": 4,
			"choices": [
				{
					"label_key": "EV_TRAVELERS_A",
					"effects": {
						"population": 3,
						"happiness": 3
					}
				},
				{
					"label_key": "EV_TRAVELERS_B",
					"effects": {
						"food": 10
					}
				}
			]
		},
		{
			"id": "harvest",
			"title_key": "EV_HARVEST",
			"text_key": "EV_HARVEST_TEXT",
			"weight": 3,
			"choices": [
				{
					"label_key": "EV_HARVEST_A",
					"effects": {
						"food": 30
					}
				},
				{
					"label_key": "EV_HARVEST_B",
					"effects": {
						"food": 12,
						"happiness": 8
					}
				}
			]
		},
		{
			"id": "storm",
			"title_key": "EV_STORM",
			"text_key": "EV_STORM_TEXT",
			"weight": 2,
			"min_day": 6,
			"choices": [
				{
					"label_key": "EV_STORM_A",
					"effects": {
						"wood": -15
					}
				},
				{
					"label_key": "EV_STORM_B",
					"effects": {
						"happiness": -8,
						"health": -5
					}
				}
			]
		},
		{
			"id": "spring",
			"title_key": "EV_SPRING",
			"text_key": "EV_SPRING_TEXT",
			"weight": 2,
			"choices": [
				{
					"label_key": "EV_SPRING_A",
					"effects": {
						"water": 40
					}
				},
				{
					"label_key": "EV_SPRING_B",
					"effects": {
						"health": 10
					}
				}
			]
		},
		{
			"id": "stones",
			"title_key": "EV_STONES",
			"text_key": "EV_STONES_TEXT",
			"weight": 2,
			"choices": [
				{
					"label_key": "EV_STONES_A",
					"effects": {
						"stone": 25
					}
				},
				{
					"label_key": "EV_STONES_B",
					"effects": {
						"happiness": 6
					}
				}
			]
		},
		{
			"id": "fever",
			"title_key": "EV_FEVER",
			"text_key": "EV_FEVER_TEXT",
			"weight": 1,
			"min_day": 10,
			"min_population": 8,
			"choices": [
				{
					"label_key": "EV_FEVER_A",
					"effects": {
						"food": -15,
						"health": 5
					}
				},
				{
					"label_key": "EV_FEVER_B",
					"effects": {
						"health": -15
					}
				}
			]
		},
		{
			"id": "festival",
			"title_key": "EV_FESTIVAL",
			"text_key": "EV_FESTIVAL_TEXT",
			"weight": 2,
			"min_population": 6,
			"choices": [
				{
					"label_key": "EV_FESTIVAL_A",
					"effects": {
						"food": -20,
						"happiness": 15
					}
				},
				{
					"label_key": "EV_FESTIVAL_B",
					"effects": {}
				}
			]
		}
	]
}
```


### FICHIER : data/game_config.json

```json
{
	"_comment": "Global tuning values. Edit freely: no code change needed.",
	"tick_rate_hz": 10,
	"ticks_per_day": 600,
	"max_ticks_per_frame": 40,
	"allowed_speeds": [
		0,
		1,
		2,
		4
	],
	"autosave_interval_seconds": 30,
	"offline_progress_cap_hours": 8,
	"offline_progress_efficiency": 0.5,
	"planet": {
		"_comment": "Default size for new planets: frequency 12 = 1442 cells (10*f*f+2). Sizes offered in-game: data/customization.json.",
		"frequency": 12,
		"ocean_fraction": 0.55,
		"shallow_band": 0.12,
		"mountain_threshold": 0.7,
		"hills_threshold": 0.48,
		"beach_threshold": 0.1,
		"ice_latitude_land": 0.8,
		"ice_latitude_water": 0.9,
		"noise_frequency": 1.3,
		"moisture_frequency": 1.7,
		"territory_reference_frequency": 8
	},
	"economy": {
		"_comment": "Per day values. A day lasts ticks_per_day / tick_rate_hz seconds at x1 (60 s).",
		"food_per_person_per_day": 1.0,
		"famine_loss": 0.1,
		"water_per_person_per_day": 1.0,
		"wellbeing": {
			"_comment": "Happiness and health (0-100) move each day toward a target.",
			"happiness_base": 50,
			"happiness_start": 60,
			"health_base": 65,
			"health_start": 80,
			"leisure_cap": 30,
			"health_bonus_cap": 30,
			"famine_happiness": -25,
			"thirst_happiness": -20,
			"homeless_happiness": -15,
			"unemployment_happiness": -8,
			"famine_health": -20,
			"thirst_health": -30,
			"crowding_health": -10,
			"happiness_speed": 0.25,
			"health_speed": 0.2,
			"tool_use_per_day": 0.05,
			"tool_bonus": 1.25
		}
	},
	"event_settings": {
		"_comment": "Random events: daily chance after first_day, never two at once.",
		"first_day": 4,
		"daily_chance": 0.12
	}
}
```


### FICHIER : data/locale/en.json

```json
{
	"APP_TITLE": "Mini Planet",
	"HELLO_PLANET": "Hello, Planet!",
	"HINT_DRAG": "Drag to spin · pinch to zoom · tap a tile",
	"DAY_N": "Day %d",
	"SPEED_PAUSE": "Pause",
	"SPEED_X": "x%d",
	"OFFLINE_WELCOME": "While you were away, %d days went by.",
	"VERSION": "Version %s",
	"TERRAIN_OCEAN": "Ocean",
	"TERRAIN_SHALLOW": "Shallow water",
	"TERRAIN_BEACH": "Beach",
	"TERRAIN_PLAINS": "Plains",
	"TERRAIN_FOREST": "Forest",
	"TERRAIN_DESERT": "Desert",
	"TERRAIN_HILLS": "Hills",
	"TERRAIN_MOUNTAIN": "Mountain",
	"TERRAIN_ICE": "Ice",
	"RES_WOOD": "Wood",
	"RES_STONE": "Stone",
	"RES_ORE": "Ore",
	"RES_FISH": "Fish",
	"RES_OIL": "Oil",
	"RES_URANIUM": "Uranium",
	"CELL_FERTILITY": "Fertility: %d %%",
	"CELL_WATER": "Body of water",
	"CELL_BUILDABLE": "Buildable",
	"CELL_NOT_BUILDABLE": "Not buildable",
	"CELL_RESOURCES": "Resources: %s",
	"CELL_NO_RESOURCE": "No visible resource",
	"CELL_PENTAGON": "Pentagonal tile (one of the planet's 12)",
	"RES_FOOD": "Food",
	"PER_DAY": "/d",
	"DECIMAL_SEPARATOR": ".",
	"FREE": "Free",
	"POP_LINE": "Population %d / %d · Workers %d / %d",
	"BLD_CAMPFIRE": "Campfire",
	"BLD_CAMPFIRE_DESC": "Gathering place: speeds up births and cheers the village up.",
	"BLD_HUT": "Hut",
	"BLD_HUT_DESC": "A shelter of branches and straw.",
	"BLD_GATHERER": "Gatherer",
	"BLD_GATHERER_DESC": "Collects berries and roots. More fertile land, bigger harvest.",
	"BLD_WOODCUTTER": "Woodcutter",
	"BLD_WOODCUTTER_DESC": "Cuts wood on its tile and the neighbouring ones. Forests regrow slowly.",
	"BLD_QUARRY": "Quarry",
	"BLD_QUARRY_DESC": "Extracts stone from its tile and neighbouring hills or mountains.",
	"BLD_HOUSING": "Houses %d people",
	"BLD_WORKERS": "Workers: %d / %d",
	"BLD_PRODUCTION": "Production per day: %s",
	"BLD_IDLE": "Idle: not enough people to work here.",
	"BLD_DEPLETED": "Deposit exhausted: nothing left to extract nearby.",
	"BLD_VILLAGE_CENTER": "Village center (cannot be demolished).",
	"DEMOLISH": "Demolish (50% refunded)",
	"DEMOLISH_CONFIRM": "Tap again to confirm",
	"BUILD_TITLE": "Build here:",
	"BUILD_ERR_TERRITORY": "Too far from the village: build next to your buildings.",
	"BUILD_NOTHING": "Nothing can be built here yet.",
	"ALERT_FAMINE": "Famine! People are starving. Build gatherers.",
	"ALERT_HOMELESS": "Not enough huts: someone leaves the planet.",
	"BUILD": "Build",
	"BUILD_WHAT": "What do you want to build?",
	"BUILD_HERE": "Build here",
	"CANCEL": "Cancel",
	"PLACE_HINT": "%s: tap a green tile on the planet.",
	"BUILT": "%s: construction started!",
	"BUILD_NO_SPOT": "No possible tile: expand your territory or find the right terrain.",
	"BUILD_ERR_OCCUPIED": "This tile is already taken.",
	"BUILD_ERR_TERRAIN": "This can't be built on this terrain.",
	"BUILD_ERR_DEPOSIT": "Needs a deposit on this tile or right next to it.",
	"BUILD_ERR_COST": "Not enough resources.",
	"BUILD_ERR_UNKNOWN": "Unknown building.",
	"WORKERS_SHORT": "workers %d/%d",
	"BLD_STATUS": "%s per day · workers %d/%d",
	"BLD_HUT_SHORT": "Houses 4 people",
	"BLD_GATHERER_SHORT": "Food, better on fertile land",
	"BLD_WOODCUTTER_SHORT": "Wood from nearby forests",
	"BLD_QUARRY_SHORT": "Stone from hills and mountains",
	"BLD_CAMPFIRE_SHORT": "More births and happiness",
	"SETTINGS": "Settings",
	"SECTION_PLANET": "My planet",
	"SECTION_DISPLAY": "Display",
	"SECTION_GAME": "Game",
	"SECTION_NEW_PLANET": "New planet",
	"PLANET_NAME": "Planet name",
	"PALETTE": "Planet colors",
	"VILLAGE_COLOR": "Village color",
	"PALETTE_CLASSIC": "Classic",
	"PALETTE_AUTUMN": "Autumn",
	"PALETTE_PASTEL": "Pastel",
	"PALETTE_MARS": "Martian",
	"PALETTE_FROST": "Frost",
	"SKY": "Sky",
	"SKY_STARS": "Starry night",
	"CLOUDS": "Clouds",
	"OUTLINES": "Tile outlines",
	"HAPTICS": "Vibrations",
	"LANGUAGE": "Language",
	"LANG_FR": "Français",
	"LANG_EN": "English",
	"NEW_PLANET_INFO": "Your current planet will be replaced.",
	"SIZE_SMALL": "Small",
	"SIZE_MEDIUM": "Medium",
	"SIZE_LARGE": "Large",
	"CELLS_N": "%d tiles",
	"NEW_PLANET": "Create a new planet",
	"NEW_PLANET_CONFIRM": "Tap again to confirm",
	"RES_WATER": "Water",
	"RES_GRAIN": "Grain",
	"RES_FLOUR": "Flour",
	"RES_TOOLS": "Tools",
	"CAT_HOUSING": "Housing",
	"CAT_FOOD": "Food",
	"CAT_RESOURCES": "Resources",
	"CAT_SERVICES": "Services",
	"BLD_FIELD": "Field",
	"BLD_FIELD_DESC": "Grows grain. More fertile land, bigger harvest.",
	"BLD_FIELD_SHORT": "Grain, better on fertile land",
	"BLD_MILL": "Millstone",
	"BLD_MILL_DESC": "Grinds grain into flour.",
	"BLD_MILL_SHORT": "Turns grain into flour",
	"BLD_BAKERY": "Bread oven",
	"BLD_BAKERY_DESC": "Bakes flour into bread: lots of food and a bit of happiness.",
	"BLD_BAKERY_SHORT": "Flour + wood: lots of food",
	"BLD_WELL": "Well",
	"BLD_WELL_DESC": "Draws water from the ground. Better next to a lake or the sea.",
	"BLD_WELL_SHORT": "Water, +50% next to water",
	"BLD_WORKSHOP": "Workshop",
	"BLD_WORKSHOP_DESC": "Makes stone and wood tools. Tools speed up work.",
	"BLD_WORKSHOP_SHORT": "Wood + stone: tools (+25% production)",
	"BLD_HEALER": "Healer",
	"BLD_HEALER_DESC": "Cares for people with plants.",
	"BLD_HEALER_SHORT": "Improves health",
	"BLD_STONE_CIRCLE": "Stone circle",
	"BLD_STONE_CIRCLE_DESC": "A place for feasts and legends around the fire.",
	"BLD_STONE_CIRCLE_SHORT": "Makes people happier",
	"TREND_UP": "rising",
	"TREND_DOWN": "falling",
	"TREND_STABLE": "stable",
	"NEEDS_TITLE": "Village needs",
	"NEED_FOOD": "%d in stock (%s/d)",
	"NEED_WATER": "%d in stock (%s/d)",
	"NEED_HOUSING": "Housing",
	"NEED_HOUSING_TEXT": "%d people for %d places",
	"NEED_WORK": "Work",
	"NEED_WORK_TEXT": "%d workers for %d jobs",
	"HAPPINESS": "Happiness",
	"HEALTH": "Health",
	"NEED_PRODUCTIVITY": "productivity %d %%",
	"NEED_STOCKS": "Stocks",
	"NEED_TIP": "Happiness sets work speed and births. Below 20%, people leave; health below 25% causes deaths.",
	"WB_BASE": "Base",
	"WB_LEISURE": "Leisure (fires, circles, bread)",
	"WB_FAMINE": "Famine",
	"WB_THIRST": "No water",
	"WB_HOMELESS": "Homeless",
	"WB_UNEMPLOYED": "Unemployment",
	"WB_HEALTH": "Health",
	"WB_CARE": "Care",
	"WB_CROWDING": "Crowding",
	"BLD_GIVES_HAPPINESS": "Village happiness +%d",
	"BLD_GIVES_HEALTH": "Village health +%d · healers %d/%d",
	"BLD_WAITING": "Waiting: missing %s.",
	"ALERT_THIRST": "No water left! Someone died of thirst. Build wells.",
	"ALERT_SICKNESS": "Sickness: someone died. Mind water, food and healers.",
	"ALERT_UNHAPPY": "People are unhappy: one of them leaves the planet.",
	"UPDATE_INSTALLED": "Version %s installed. Enjoy!",
	"SIZE_HUGE": "Huge",
	"WATER_ISLANDS": "Islands",
	"WATER_BALANCED": "Balanced",
	"WATER_CONTINENTS": "Continents",
	"RELIEF_FLAT": "Flat",
	"RELIEF_NORMAL": "Varied",
	"RELIEF_MOUNTAINS": "Mountainous",
	"PALETTE_TROPICAL": "Tropical",
	"PALETTE_GOLDEN": "Golden",
	"PALETTE_NIGHT": "Night",
	"SKY_AURORA": "Aurora",
	"SKY_SUNSET": "Sunset",
	"DECORATIONS": "Decorations",
	"DECOR_RINGS": "Rings",
	"DECOR_MOON": "Moon",
	"START_CURRENT": "%s · day %d · %d people",
	"START_CONTINUE": "Continue",
	"START_NEW": "New planet",
	"START_TUTORIAL": "How to play?",
	"START_SCREEN": "Home screen",
	"NEW_PLANET_TITLE": "New planet",
	"PLANET_SIZE": "Size",
	"PLANET_WATER": "Oceans",
	"PLANET_RELIEF": "Relief",
	"PLANET_SEED": "Seed (optional)",
	"PLANET_SEED_HINT": "A word or number to find a planet again",
	"BACK": "Back",
	"TUTO_SKIP": "Skip",
	"TUTO_NEXT": "Next",
	"TUTO_STEP": "Tutorial · step %d / %d",
	"TUTO_WELCOME": "Welcome to %s! I'll show you how to grow your village.",
	"TUTO_ROTATE": "Drag a finger on the planet to spin it.",
	"TUTO_ZOOM": "Pinch with two fingers to zoom in on your village.",
	"TUTO_SELECT": "Tap a tile to see its terrain and resources.",
	"TUTO_WELL": "Your people are thirsty. Tap Build, Resources tab, pick the Well, then a green tile.",
	"TUTO_GATHERER": "They also need food: build a Gatherer (Food tab).",
	"TUTO_HUT": "Build a Hut (Housing tab) to welcome more people.",
	"TUTO_NEEDS": "Tap the Population / Happiness / Health row to see the village needs.",
	"TUTO_SPEED": "Tap the x1 button to speed up time.",
	"TUTO_GOALS": "Tap the trophy to see your goals and their rewards.",
	"TUTO_DONE": "Well done, your village is on its way! Train your people, grow the town hall and colonize the planet.",
	"GOALS_TITLE": "Goals",
	"GOALS_PROGRESS": "%d of %d goals reached",
	"GOAL_STATUS": "%d / %d · reward: %s",
	"GOAL_DONE": "Goal reached: %s! Reward: %s",
	"OBJ_FIRST_WELL": "Build a well",
	"OBJ_FIRST_GATHERER": "Build a gatherer",
	"OBJ_POP": "Reach %d people",
	"OBJ_HUTS": "Have %d huts",
	"OBJ_BREAD": "Bake bread (bread oven)",
	"OBJ_TOOLS": "Have %d tools in stock",
	"OBJ_HAPPY": "Reach %d%% happiness",
	"OBJ_LONGHOUSE": "Upgrade a hut into a longhouse",
	"OBJ_BUILDINGS": "Have %d buildings",
	"OBJ_DAYS": "Survive %d days",
	"BLD_LONGHOUSE": "Longhouse",
	"BLD_LONGHOUSE_DESC": "A large house of wood and thatch.",
	"BLD_LONGHOUSE_SHORT": "Houses 9 people",
	"UPGRADE": "Upgrade: %s (%s)",
	"UPGRADED": "Building upgraded!",
	"EV_NOTHING": "No effect",
	"EFFECT_PEOPLE": "people",
	"EV_TRAVELERS": "Travelers",
	"EV_TRAVELERS_TEXT": "A small family from far away asks to join the village.",
	"EV_TRAVELERS_A": "Welcome them (if there is room)",
	"EV_TRAVELERS_B": "Trade some food and let them go",
	"EV_HARVEST": "Bountiful harvest",
	"EV_HARVEST_TEXT": "The bushes are heavy with berries this season!",
	"EV_HARVEST_A": "Store everything",
	"EV_HARVEST_B": "Throw a feast",
	"EV_STORM": "Storm",
	"EV_STORM_TEXT": "A violent storm threatens the village.",
	"EV_STORM_A": "Protect the huts with wood",
	"EV_STORM_B": "Wait it out",
	"EV_SPRING": "A spring!",
	"EV_SPRING_TEXT": "Children found a clear water spring.",
	"EV_SPRING_A": "Fill the reserves",
	"EV_SPRING_B": "Make it a bathing spot",
	"EV_STONES": "Landslide",
	"EV_STONES_TEXT": "Part of a hill collapsed, revealing fine stones.",
	"EV_STONES_A": "Collect the stones",
	"EV_STONES_B": "Make it a sacred place",
	"EV_FEVER": "Fever",
	"EV_FEVER_TEXT": "A fever is spreading among some villagers.",
	"EV_FEVER_A": "Give them the best food",
	"EV_FEVER_B": "Hope they heal on their own",
	"EV_FESTIVAL": "Village feast",
	"EV_FESTIVAL_TEXT": "People would like to celebrate the new moon.",
	"EV_FESTIVAL_A": "A big feast!",
	"EV_FESTIVAL_B": "Not this time",
	"SKY_SOFT": "Soft day",
	"SKY_MIST": "Mist",
	"VILLAGE_TITLE": "My village",
	"TAB_TOWNHALL": "Town hall",
	"TAB_PEOPLE": "People",
	"TAB_GOALS": "Goals",
	"LOCKED_AT": "Unlocked at town hall level %d",
	"LIMIT_REACHED": "Maximum reached (%d/%d): upgrade the town hall",
	"BUILD_ERR_BUILDERS": "All builders are busy",
	"BUILD_ERR_LOCKED": "Not unlocked yet",
	"BUILD_ERR_LIMIT": "Maximum number reached",
	"BUILDERS_FREE": "Free builders: %d / %d",
	"OPEN_TOWNHALL": "Open the town hall",
	"BLD_UNDER_CONSTRUCTION": "Construction: %d %% · %s left",
	"TH_UPGRADING": "Upgrading to level %d · %s left",
	"BLD_TOWNHALL_STATUS": "Level %d · %d housing places in total",
	"BLD_NEEDS_TRAINED": "Nobody works here: train a %s (Village, People tab)",
	"TH_LEVEL": "Town hall · level %d / %d",
	"TH_STATS": "%d places · builders %d/%d · %d training(s) at once",
	"TH_SKILLS": "Village skills",
	"TH_UPGRADING_TITLE": "Upgrading to level %d",
	"TH_TIME_LEFT": "%s left",
	"TH_MAX": "Maximum level",
	"TH_MAX_TEXT": "Your town hall has reached the peak of the stone age. Antiquity is coming soon!",
	"TH_UNLOCKS": "Unlocks: %s",
	"TH_MORE": "Town hall housing: %d · builders: %d",
	"TH_NEEDS_POP": "Population needed: %d (you have %d)",
	"TH_COST": "Cost: %s · time: %s",
	"TH_NEXT": "Level %d",
	"TH_UPGRADE": "Upgrade the town hall",
	"TH_STARTED": "Town hall works have started!",
	"TH_ERR_REQUIREMENT": "Not enough people yet",
	"TH_ERR_MAX": "Maximum level",
	"TH_ERR_BUSY": "Works in progress",
	"PEOPLE_SUMMARY": "Villagers without a job: %d of %d · trainings: %d/%d",
	"TRAINING_ROW": "Training: %s",
	"PROF_STATUS": "Trained: %d · jobs: %d",
	"TRAIN": "Train (%s)",
	"TRAIN_ERR_NO_VILLAGER": "No free villager",
	"TRAIN_ERR_SLOTS": "Queue full",
	"TIME_SECONDS": "%d s",
	"TIME_MINUTES": "%d min",
	"CONSTRUCTION_DONE": "%s: construction finished!",
	"TRAINING_DONE": "A villager became a %s!",
	"LEVEL_UP_TITLE": "Town hall level %d!",
	"LEVEL_UP_TEXT": "Well done! New: %s.",
	"LEVEL_UP_MORE": "more buildings and housing",
	"LEVEL_UP_OK": "Great!",
	"PROF_WATER": "water carrier",
	"PROF_GATHERER": "gatherer",
	"PROF_WOODCUTTER": "woodcutter",
	"PROF_STONECUTTER": "stonecutter",
	"PROF_FARMER": "farmer",
	"PROF_MILLER": "miller",
	"PROF_BAKER": "baker",
	"PROF_ARTISAN": "artisan",
	"PROF_HEALER": "healer",
	"PERK_GATHERING": "Expert gathering (+10% food)",
	"PERK_BUILDERS": "Fast builders (+25% speed)",
	"PERK_TEACHERS": "Master teachers (training +50%)",
	"PERK_LUMBER": "Skilled woodcutters (+10% wood)",
	"PERK_FESTIVALS": "Festive traditions (+5 happiness)",
	"PERK_MASONS": "Masons (+15% stone)",
	"PERK_HARVEST": "Great harvests (+10% food)",
	"BLD_TOWNHALL": "Town hall",
	"BLD_TOWNHALL_DESC": "The heart of the village: houses people, trains jobs and grows the territory.",
	"BLD_TOWNHALL_SHORT": "Heart of the village",
	"BLD_OUTPOST": "Outpost",
	"BLD_OUTPOST_DESC": "A forward camp that expands the territory to colonize the planet.",
	"BLD_OUTPOST_SHORT": "Expands the territory",
	"OBJ_TRAINED": "Train %d people",
	"OBJ_TOWNHALL": "Town hall level %d",
	"OBJ_OUTPOST": "Found an outpost",
	"WB_PERKS": "Skills",
	"TUTO_TOWNHALL": "This is your town hall, the heart of the village. Tap the Village button (bottom) to explore it.",
	"TUTO_TRAIN_WATER": "A well needs a water carrier. Open Village, People tab, and train a water carrier.",
	"TUTO_TRAIN_GATHERER": "Train 2 gatherers in Village, People tab.",
	"TUTO_UPGRADE": "Once you have 6 people and enough wood and stone, upgrade the town hall to unlock new buildings and skills."
}
```


### FICHIER : data/locale/fr.json

```json
{
	"APP_TITLE": "Mini Planète",
	"HELLO_PLANET": "Bonjour, Planète !",
	"HINT_DRAG": "Glisse pour tourner · pince pour zoomer · touche une case",
	"DAY_N": "Jour %d",
	"SPEED_PAUSE": "Pause",
	"SPEED_X": "x%d",
	"OFFLINE_WELCOME": "Pendant ton absence, %d jours se sont écoulés.",
	"VERSION": "Version %s",
	"TERRAIN_OCEAN": "Océan",
	"TERRAIN_SHALLOW": "Eaux peu profondes",
	"TERRAIN_BEACH": "Plage",
	"TERRAIN_PLAINS": "Plaine",
	"TERRAIN_FOREST": "Forêt",
	"TERRAIN_DESERT": "Désert",
	"TERRAIN_HILLS": "Collines",
	"TERRAIN_MOUNTAIN": "Montagne",
	"TERRAIN_ICE": "Glace",
	"RES_WOOD": "Bois",
	"RES_STONE": "Pierre",
	"RES_ORE": "Minerai",
	"RES_FISH": "Poissons",
	"RES_OIL": "Pétrole",
	"RES_URANIUM": "Uranium",
	"CELL_FERTILITY": "Fertilité : %d %%",
	"CELL_WATER": "Étendue d'eau",
	"CELL_BUILDABLE": "Constructible",
	"CELL_NOT_BUILDABLE": "Non constructible",
	"CELL_RESOURCES": "Ressources : %s",
	"CELL_NO_RESOURCE": "Aucune ressource visible",
	"CELL_PENTAGON": "Case pentagonale (l'une des 12 de la planète)",
	"RES_FOOD": "Nourriture",
	"PER_DAY": "/j",
	"DECIMAL_SEPARATOR": ",",
	"FREE": "Gratuit",
	"POP_LINE": "Habitants %d / %d · Ouvriers %d / %d",
	"BLD_CAMPFIRE": "Feu de camp",
	"BLD_CAMPFIRE_DESC": "Lieu de rassemblement : accélère les naissances et rend le village plus joyeux.",
	"BLD_HUT": "Hutte",
	"BLD_HUT_DESC": "Un abri de branches et de paille.",
	"BLD_GATHERER": "Cueilleur",
	"BLD_GATHERER_DESC": "Récolte baies et racines. Plus la terre est fertile, plus il récolte.",
	"BLD_WOODCUTTER": "Bûcheron",
	"BLD_WOODCUTTER_DESC": "Coupe le bois de sa case et des cases voisines. Les forêts repoussent lentement.",
	"BLD_QUARRY": "Carrière",
	"BLD_QUARRY_DESC": "Extrait la pierre de sa case et des collines ou montagnes voisines.",
	"BLD_HOUSING": "Loge %d habitants",
	"BLD_WORKERS": "Ouvriers : %d / %d",
	"BLD_PRODUCTION": "Production par jour : %s",
	"BLD_IDLE": "À l'arrêt : il manque des habitants pour y travailler.",
	"BLD_DEPLETED": "Gisement épuisé : plus rien à extraire autour.",
	"BLD_VILLAGE_CENTER": "Centre du village (ne peut pas être démoli).",
	"DEMOLISH": "Démolir (50 % remboursés)",
	"DEMOLISH_CONFIRM": "Toucher encore pour confirmer",
	"BUILD_TITLE": "Construire ici :",
	"BUILD_ERR_TERRITORY": "Trop loin du village : construis à côté de tes bâtiments.",
	"BUILD_NOTHING": "Rien ne peut être construit ici pour l'instant.",
	"ALERT_FAMINE": "Famine ! Des habitants meurent de faim. Construis des cueilleurs.",
	"ALERT_HOMELESS": "Pas assez de huttes : un habitant quitte la planète.",
	"BUILD": "Construire",
	"BUILD_WHAT": "Que veux-tu construire ?",
	"BUILD_HERE": "Construire ici",
	"CANCEL": "Annuler",
	"PLACE_HINT": "%s : touche une case verte sur la planète.",
	"BUILT": "%s : chantier lancé !",
	"BUILD_NO_SPOT": "Aucune case possible : agrandis ton territoire ou cherche le bon terrain.",
	"BUILD_ERR_OCCUPIED": "Cette case est déjà occupée.",
	"BUILD_ERR_TERRAIN": "Impossible de construire ça sur ce terrain.",
	"BUILD_ERR_DEPOSIT": "Il faut un gisement sur cette case ou juste à côté.",
	"BUILD_ERR_COST": "Pas assez de ressources.",
	"BUILD_ERR_UNKNOWN": "Bâtiment inconnu.",
	"WORKERS_SHORT": "ouvriers %d/%d",
	"BLD_STATUS": "%s par jour · ouvriers %d/%d",
	"BLD_HUT_SHORT": "Loge 4 habitants",
	"BLD_GATHERER_SHORT": "Nourriture, mieux sur terre fertile",
	"BLD_WOODCUTTER_SHORT": "Bois des forêts voisines",
	"BLD_QUARRY_SHORT": "Pierre des collines et montagnes",
	"BLD_CAMPFIRE_SHORT": "Plus de naissances et de bonheur",
	"SETTINGS": "Réglages",
	"SECTION_PLANET": "Ma planète",
	"SECTION_DISPLAY": "Affichage",
	"SECTION_GAME": "Jeu",
	"SECTION_NEW_PLANET": "Nouvelle planète",
	"PLANET_NAME": "Nom de la planète",
	"PALETTE": "Couleurs de la planète",
	"VILLAGE_COLOR": "Couleur du village",
	"PALETTE_CLASSIC": "Classique",
	"PALETTE_AUTUMN": "Automne",
	"PALETTE_PASTEL": "Pastel",
	"PALETTE_MARS": "Martienne",
	"PALETTE_FROST": "Givre",
	"SKY": "Ciel",
	"SKY_STARS": "Nuit étoilée",
	"CLOUDS": "Nuages",
	"OUTLINES": "Contours des cases",
	"HAPTICS": "Vibrations",
	"LANGUAGE": "Langue",
	"LANG_FR": "Français",
	"LANG_EN": "English",
	"NEW_PLANET_INFO": "Ta planète actuelle sera remplacée.",
	"SIZE_SMALL": "Petite",
	"SIZE_MEDIUM": "Moyenne",
	"SIZE_LARGE": "Grande",
	"CELLS_N": "%d cases",
	"NEW_PLANET": "Créer une nouvelle planète",
	"NEW_PLANET_CONFIRM": "Toucher encore pour confirmer",
	"RES_WATER": "Eau",
	"RES_GRAIN": "Céréales",
	"RES_FLOUR": "Farine",
	"RES_TOOLS": "Outils",
	"CAT_HOUSING": "Habitat",
	"CAT_FOOD": "Nourriture",
	"CAT_RESOURCES": "Ressources",
	"CAT_SERVICES": "Services",
	"BLD_FIELD": "Champ",
	"BLD_FIELD_DESC": "Cultive des céréales. Plus la terre est fertile, plus il produit.",
	"BLD_FIELD_SHORT": "Céréales, mieux sur terre fertile",
	"BLD_MILL": "Meule",
	"BLD_MILL_DESC": "Écrase les céréales pour en faire de la farine.",
	"BLD_MILL_SHORT": "Transforme les céréales en farine",
	"BLD_BAKERY": "Four à pain",
	"BLD_BAKERY_DESC": "Cuit la farine en pain : beaucoup de nourriture et un peu de bonheur.",
	"BLD_BAKERY_SHORT": "Farine + bois : beaucoup de nourriture",
	"BLD_WELL": "Puits",
	"BLD_WELL_DESC": "Puise l'eau du sol. Plus efficace près d'un lac ou de la mer.",
	"BLD_WELL_SHORT": "Eau, +50 % près de l'eau",
	"BLD_WORKSHOP": "Atelier",
	"BLD_WORKSHOP_DESC": "Taille des outils en pierre et en bois. Les outils accélèrent le travail.",
	"BLD_WORKSHOP_SHORT": "Bois + pierre : outils (+25 % de production)",
	"BLD_HEALER": "Guérisseur",
	"BLD_HEALER_DESC": "Soigne les habitants avec des plantes.",
	"BLD_HEALER_SHORT": "Améliore la santé",
	"BLD_STONE_CIRCLE": "Cercle de pierres",
	"BLD_STONE_CIRCLE_DESC": "Lieu de fêtes et de légendes autour du feu.",
	"BLD_STONE_CIRCLE_SHORT": "Rend les habitants plus heureux",
	"TREND_UP": "en hausse",
	"TREND_DOWN": "en baisse",
	"TREND_STABLE": "stable",
	"NEEDS_TITLE": "Besoins du village",
	"NEED_FOOD": "%d en stock (%s/j)",
	"NEED_WATER": "%d en stock (%s/j)",
	"NEED_HOUSING": "Logement",
	"NEED_HOUSING_TEXT": "%d habitants pour %d places",
	"NEED_WORK": "Travail",
	"NEED_WORK_TEXT": "%d ouvriers pour %d emplois",
	"HAPPINESS": "Bonheur",
	"HEALTH": "Santé",
	"NEED_PRODUCTIVITY": "productivité %d %%",
	"NEED_STOCKS": "Stocks",
	"NEED_TIP": "Le bonheur règle la vitesse de travail et les naissances. Sous 20 %, des habitants partent ; une santé sous 25 % provoque des décès.",
	"WB_BASE": "Base",
	"WB_LEISURE": "Loisirs (feux, cercles, pain)",
	"WB_FAMINE": "Famine",
	"WB_THIRST": "Manque d'eau",
	"WB_HOMELESS": "Sans-abri",
	"WB_UNEMPLOYED": "Chômage",
	"WB_HEALTH": "État de santé",
	"WB_CARE": "Soins",
	"WB_CROWDING": "Entassement",
	"BLD_GIVES_HAPPINESS": "Bonheur du village +%d",
	"BLD_GIVES_HEALTH": "Santé du village +%d · guérisseurs %d/%d",
	"BLD_WAITING": "En attente : il manque %s.",
	"ALERT_THIRST": "Plus d'eau ! Un habitant meurt de soif. Construis des puits.",
	"ALERT_SICKNESS": "Maladie : un habitant est mort. Pense à l'eau, à la nourriture et aux guérisseurs.",
	"ALERT_UNHAPPY": "Les habitants sont malheureux : l'un d'eux quitte la planète.",
	"UPDATE_INSTALLED": "Version %s installée. Bon jeu !",
	"SIZE_HUGE": "Immense",
	"WATER_ISLANDS": "Archipels",
	"WATER_BALANCED": "Équilibré",
	"WATER_CONTINENTS": "Continents",
	"RELIEF_FLAT": "Plat",
	"RELIEF_NORMAL": "Varié",
	"RELIEF_MOUNTAINS": "Montagneux",
	"PALETTE_TROPICAL": "Tropicale",
	"PALETTE_GOLDEN": "Dorée",
	"PALETTE_NIGHT": "Nuit",
	"SKY_AURORA": "Aurore",
	"SKY_SUNSET": "Coucher de soleil",
	"DECORATIONS": "Décorations",
	"DECOR_RINGS": "Anneaux",
	"DECOR_MOON": "Lune",
	"START_CURRENT": "%s · jour %d · %d habitants",
	"START_CONTINUE": "Continuer",
	"START_NEW": "Nouvelle planète",
	"START_TUTORIAL": "Comment jouer ?",
	"START_SCREEN": "Écran d'accueil",
	"NEW_PLANET_TITLE": "Nouvelle planète",
	"PLANET_SIZE": "Taille",
	"PLANET_WATER": "Océans",
	"PLANET_RELIEF": "Relief",
	"PLANET_SEED": "Graine (facultatif)",
	"PLANET_SEED_HINT": "Un mot ou un nombre pour retrouver une planète",
	"BACK": "Retour",
	"TUTO_SKIP": "Passer",
	"TUTO_NEXT": "Suivant",
	"TUTO_STEP": "Didacticiel · étape %d / %d",
	"TUTO_WELCOME": "Bienvenue sur %s ! Je vais t'apprendre à faire grandir ton village.",
	"TUTO_ROTATE": "Glisse un doigt sur la planète pour la faire tourner.",
	"TUTO_ZOOM": "Pince avec deux doigts pour zoomer sur ton village.",
	"TUTO_SELECT": "Touche une case pour voir son terrain et ses ressources.",
	"TUTO_WELL": "Tes habitants ont soif. Touche Construire, onglet Ressources, choisis le Puits, puis une case verte.",
	"TUTO_GATHERER": "Il faut aussi manger : construis un Cueilleur (onglet Nourriture).",
	"TUTO_HUT": "Construis une Hutte (onglet Habitat) pour accueillir plus d'habitants.",
	"TUTO_NEEDS": "Touche la ligne Habitants / Bonheur / Santé pour voir les besoins du village.",
	"TUTO_SPEED": "Touche le bouton x1 pour accélérer le temps.",
	"TUTO_GOALS": "Touche le trophée pour voir tes objectifs et leurs récompenses.",
	"TUTO_DONE": "Bravo, ton village est lancé ! Forme tes habitants, fais grandir l'Hôtel de ville et colonise la planète.",
	"GOALS_TITLE": "Objectifs",
	"GOALS_PROGRESS": "%d objectifs atteints sur %d",
	"GOAL_STATUS": "%d / %d · récompense : %s",
	"GOAL_DONE": "Objectif atteint : %s ! Récompense : %s",
	"OBJ_FIRST_WELL": "Construire un puits",
	"OBJ_FIRST_GATHERER": "Construire un cueilleur",
	"OBJ_POP": "Atteindre %d habitants",
	"OBJ_HUTS": "Avoir %d huttes",
	"OBJ_BREAD": "Cuire du pain (four à pain)",
	"OBJ_TOOLS": "Avoir %d outils en stock",
	"OBJ_HAPPY": "Atteindre %d %% de bonheur",
	"OBJ_LONGHOUSE": "Améliorer une hutte en maison longue",
	"OBJ_BUILDINGS": "Avoir %d bâtiments",
	"OBJ_DAYS": "Survivre %d jours",
	"BLD_LONGHOUSE": "Maison longue",
	"BLD_LONGHOUSE_DESC": "Grande maison de bois et de chaume.",
	"BLD_LONGHOUSE_SHORT": "Loge 9 habitants",
	"UPGRADE": "Améliorer : %s (%s)",
	"UPGRADED": "Bâtiment amélioré !",
	"EV_NOTHING": "Aucun effet",
	"EFFECT_PEOPLE": "habitants",
	"EV_TRAVELERS": "Des voyageurs",
	"EV_TRAVELERS_TEXT": "Une petite famille venue de loin demande à rejoindre le village.",
	"EV_TRAVELERS_A": "Les accueillir (s'il reste de la place)",
	"EV_TRAVELERS_B": "Échanger quelques vivres et les laisser partir",
	"EV_HARVEST": "Récolte abondante",
	"EV_HARVEST_TEXT": "Les buissons croulent sous les baies cette saison !",
	"EV_HARVEST_A": "Tout stocker",
	"EV_HARVEST_B": "Organiser un festin",
	"EV_STORM": "Tempête",
	"EV_STORM_TEXT": "Un violent orage menace le village.",
	"EV_STORM_A": "Protéger les huttes avec du bois",
	"EV_STORM_B": "Attendre que ça passe",
	"EV_SPRING": "Source découverte",
	"EV_SPRING_TEXT": "Des enfants ont trouvé une source d'eau claire.",
	"EV_SPRING_A": "Remplir les réserves",
	"EV_SPRING_B": "Y faire des bains",
	"EV_STONES": "Éboulement",
	"EV_STONES_TEXT": "Un pan de colline s'est effondré, révélant de belles pierres.",
	"EV_STONES_A": "Ramasser les pierres",
	"EV_STONES_B": "En faire un lieu sacré",
	"EV_FEVER": "Fièvre",
	"EV_FEVER_TEXT": "Une fièvre touche plusieurs habitants.",
	"EV_FEVER_A": "Leur donner les meilleures provisions",
	"EV_FEVER_B": "Espérer qu'ils guérissent seuls",
	"EV_FESTIVAL": "Fête du village",
	"EV_FESTIVAL_TEXT": "Les habitants voudraient fêter la nouvelle lune.",
	"EV_FESTIVAL_A": "Une grande fête !",
	"EV_FESTIVAL_B": "Pas cette fois",
	"SKY_SOFT": "Jour doux",
	"SKY_MIST": "Brume",
	"VILLAGE_TITLE": "Mon village",
	"TAB_TOWNHALL": "Mairie",
	"TAB_PEOPLE": "Habitants",
	"TAB_GOALS": "Objectifs",
	"LOCKED_AT": "Débloqué au niveau %d de l'Hôtel de ville",
	"LIMIT_REACHED": "Maximum atteint (%d/%d) : améliore l'Hôtel de ville",
	"BUILD_ERR_BUILDERS": "Tous les bâtisseurs sont occupés",
	"BUILD_ERR_LOCKED": "Pas encore débloqué",
	"BUILD_ERR_LIMIT": "Nombre maximum atteint",
	"BUILDERS_FREE": "Bâtisseurs libres : %d / %d",
	"OPEN_TOWNHALL": "Ouvrir l'Hôtel de ville",
	"BLD_UNDER_CONSTRUCTION": "Chantier : %d %% · encore %s",
	"TH_UPGRADING": "Amélioration vers le niveau %d · encore %s",
	"BLD_TOWNHALL_STATUS": "Niveau %d · %d places de logement au total",
	"BLD_NEEDS_TRAINED": "Personne n'y travaille : forme un %s (Village, onglet Habitants)",
	"TH_LEVEL": "Hôtel de ville · niveau %d / %d",
	"TH_STATS": "%d places · bâtisseurs %d/%d · %d formation(s) à la fois",
	"TH_SKILLS": "Compétences du village",
	"TH_UPGRADING_TITLE": "Amélioration vers le niveau %d",
	"TH_TIME_LEFT": "Encore %s",
	"TH_MAX": "Niveau maximum",
	"TH_MAX_TEXT": "Ton Hôtel de ville est au sommet de l'âge de pierre. L'Antiquité arrive bientôt !",
	"TH_UNLOCKS": "Débloque : %s",
	"TH_MORE": "Logement de l'Hôtel de ville : %d · bâtisseurs : %d",
	"TH_NEEDS_POP": "Population requise : %d (tu as %d)",
	"TH_COST": "Coût : %s · durée : %s",
	"TH_NEXT": "Niveau %d",
	"TH_UPGRADE": "Améliorer l'Hôtel de ville",
	"TH_STARTED": "Les travaux de l'Hôtel de ville commencent !",
	"TH_ERR_REQUIREMENT": "Pas encore assez d'habitants",
	"TH_ERR_MAX": "Niveau maximum",
	"TH_ERR_BUSY": "Travaux en cours",
	"PEOPLE_SUMMARY": "Villageois sans métier : %d sur %d · formations en cours : %d/%d",
	"TRAINING_ROW": "Formation : %s",
	"PROF_STATUS": "Formés : %d · postes : %d",
	"TRAIN": "Former (%s)",
	"TRAIN_ERR_NO_VILLAGER": "Aucun villageois libre",
	"TRAIN_ERR_SLOTS": "File pleine",
	"TIME_SECONDS": "%d s",
	"TIME_MINUTES": "%d min",
	"CONSTRUCTION_DONE": "%s : construction terminée !",
	"TRAINING_DONE": "Un villageois est devenu %s !",
	"LEVEL_UP_TITLE": "Hôtel de ville niveau %d !",
	"LEVEL_UP_TEXT": "Bravo ! Nouveautés : %s.",
	"LEVEL_UP_MORE": "plus de bâtiments et de logements",
	"LEVEL_UP_OK": "Super !",
	"PROF_WATER": "porteur d'eau",
	"PROF_GATHERER": "cueilleur",
	"PROF_WOODCUTTER": "bûcheron",
	"PROF_STONECUTTER": "tailleur de pierre",
	"PROF_FARMER": "fermier",
	"PROF_MILLER": "meunier",
	"PROF_BAKER": "boulanger",
	"PROF_ARTISAN": "artisan",
	"PROF_HEALER": "guérisseur",
	"PERK_GATHERING": "Cueillette experte (+10 % de nourriture)",
	"PERK_BUILDERS": "Bâtisseurs rapides (+25 % de vitesse)",
	"PERK_TEACHERS": "Maîtres d'apprentissage (formations +50 %)",
	"PERK_LUMBER": "Bûcherons habiles (+10 % de bois)",
	"PERK_FESTIVALS": "Traditions festives (+5 de bonheur)",
	"PERK_MASONS": "Maçons (+15 % de pierre)",
	"PERK_HARVEST": "Grandes récoltes (+10 % de nourriture)",
	"BLD_TOWNHALL": "Hôtel de ville",
	"BLD_TOWNHALL_DESC": "Le cœur du village : loge les habitants, forme les métiers et fait grandir le territoire.",
	"BLD_TOWNHALL_SHORT": "Cœur du village",
	"BLD_OUTPOST": "Avant-poste",
	"BLD_OUTPOST_DESC": "Un camp avancé qui agrandit le territoire pour coloniser la planète.",
	"BLD_OUTPOST_SHORT": "Agrandit le territoire",
	"OBJ_TRAINED": "Former %d habitants",
	"OBJ_TOWNHALL": "Hôtel de ville niveau %d",
	"OBJ_OUTPOST": "Fonder un avant-poste",
	"WB_PERKS": "Compétences",
	"TUTO_TOWNHALL": "Voici ton Hôtel de ville, le cœur du village. Touche le bouton Village (en bas) pour le découvrir.",
	"TUTO_TRAIN_WATER": "Un puits a besoin d'un porteur d'eau. Ouvre Village, onglet Habitants, et forme un porteur d'eau.",
	"TUTO_TRAIN_GATHERER": "Forme 2 cueilleurs dans Village, onglet Habitants.",
	"TUTO_UPGRADE": "Quand tu auras 6 habitants et assez de bois et de pierre, améliore l'Hôtel de ville pour débloquer de nouveaux bâtiments et compétences."
}
```


### FICHIER : data/objectives.json

```json
{
	"_comment": "Goals shown in the Goals screen. type: townhall | trained | population | building (id) | buildings_total | happiness | health | day | stock (res). reward: resources given once.",
	"objectives": [
		{
			"id": "first_well",
			"title_key": "OBJ_FIRST_WELL",
			"type": "building",
			"target": "well",
			"value": 1,
			"reward": {
				"wood": 10
			}
		},
		{
			"id": "first_gatherer",
			"title_key": "OBJ_FIRST_GATHERER",
			"type": "building",
			"target": "gatherer",
			"value": 1,
			"reward": {
				"food": 15
			}
		},
		{
			"id": "train_3",
			"title_key": "OBJ_TRAINED",
			"type": "trained",
			"value": 3,
			"reward": {
				"food": 15
			}
		},
		{
			"id": "pop_10",
			"title_key": "OBJ_POP",
			"type": "population",
			"value": 10,
			"reward": {
				"wood": 20,
				"stone": 10
			}
		},
		{
			"id": "townhall_2",
			"title_key": "OBJ_TOWNHALL",
			"type": "townhall",
			"value": 2,
			"reward": {
				"wood": 30,
				"stone": 15
			}
		},
		{
			"id": "huts_4",
			"title_key": "OBJ_HUTS",
			"type": "building",
			"target": "hut",
			"value": 4,
			"reward": {
				"food": 20
			}
		},
		{
			"id": "bread",
			"title_key": "OBJ_BREAD",
			"type": "building",
			"target": "bakery",
			"value": 1,
			"reward": {
				"wood": 25
			}
		},
		{
			"id": "tools",
			"title_key": "OBJ_TOOLS",
			"type": "stock",
			"target": "tools",
			"value": 5,
			"reward": {
				"stone": 20
			}
		},
		{
			"id": "townhall_3",
			"title_key": "OBJ_TOWNHALL",
			"type": "townhall",
			"value": 3,
			"reward": {
				"wood": 50,
				"stone": 40
			}
		},
		{
			"id": "happy_70",
			"title_key": "OBJ_HAPPY",
			"type": "happiness",
			"value": 70,
			"reward": {
				"food": 30
			}
		},
		{
			"id": "pop_25",
			"title_key": "OBJ_POP",
			"type": "population",
			"value": 25,
			"reward": {
				"wood": 40,
				"stone": 30
			}
		},
		{
			"id": "longhouse",
			"title_key": "OBJ_LONGHOUSE",
			"type": "building",
			"target": "longhouse",
			"value": 1,
			"reward": {
				"stone": 25
			}
		},
		{
			"id": "buildings_20",
			"title_key": "OBJ_BUILDINGS",
			"type": "buildings_total",
			"value": 20,
			"reward": {
				"tools": 10
			}
		},
		{
			"id": "day_30",
			"title_key": "OBJ_DAYS",
			"type": "day",
			"value": 30,
			"reward": {
				"food": 40,
				"water": 40
			}
		},
		{
			"id": "pop_50",
			"title_key": "OBJ_POP",
			"type": "population",
			"value": 50,
			"reward": {
				"wood": 80,
				"stone": 60
			}
		},
		{
			"id": "townhall_4",
			"title_key": "OBJ_TOWNHALL",
			"type": "townhall",
			"value": 4,
			"reward": {
				"tools": 15,
				"food": 60
			}
		},
		{
			"id": "outpost",
			"title_key": "OBJ_OUTPOST",
			"type": "building",
			"target": "outpost",
			"value": 1,
			"reward": {
				"wood": 40
			}
		}
	]
}
```


### FICHIER : data/professions.json

```json
{
	"_comment": "Jobs villagers are trained for at the town hall. cost/days = price and time of one training.",
	"professions": {
		"water_carrier": {
			"name_key": "PROF_WATER",
			"icon": "water",
			"cost": {
				"food": 4
			},
			"days": 0.2
		},
		"gatherer": {
			"name_key": "PROF_GATHERER",
			"icon": "gatherer",
			"cost": {
				"food": 4
			},
			"days": 0.2
		},
		"woodcutter": {
			"name_key": "PROF_WOODCUTTER",
			"icon": "woodcutter",
			"cost": {
				"food": 5
			},
			"days": 0.25
		},
		"stonecutter": {
			"name_key": "PROF_STONECUTTER",
			"icon": "quarry",
			"cost": {
				"food": 6
			},
			"days": 0.3
		},
		"farmer": {
			"name_key": "PROF_FARMER",
			"icon": "field",
			"cost": {
				"food": 6
			},
			"days": 0.3
		},
		"miller": {
			"name_key": "PROF_MILLER",
			"icon": "mill",
			"cost": {
				"food": 8
			},
			"days": 0.4
		},
		"baker": {
			"name_key": "PROF_BAKER",
			"icon": "bakery",
			"cost": {
				"food": 8
			},
			"days": 0.4
		},
		"artisan": {
			"name_key": "PROF_ARTISAN",
			"icon": "workshop",
			"cost": {
				"food": 10,
				"wood": 5
			},
			"days": 0.5
		},
		"healer": {
			"name_key": "PROF_HEALER",
			"icon": "healer",
			"cost": {
				"food": 12
			},
			"days": 0.6
		}
	}
}
```


### FICHIER : data/resources.json

```json
{
	"_comment": "Natural resources found on cells. hidden = not shown until a later age reveals it.",
	"resources": {
		"wood": {
			"name_key": "RES_WOOD",
			"hidden": false
		},
		"stone": {
			"name_key": "RES_STONE",
			"hidden": false
		},
		"ore": {
			"name_key": "RES_ORE",
			"hidden": false
		},
		"fish": {
			"name_key": "RES_FISH",
			"hidden": false
		},
		"oil": {
			"name_key": "RES_OIL",
			"hidden": true
		},
		"uranium": {
			"name_key": "RES_URANIUM",
			"hidden": true
		},
		"food": {
			"name_key": "RES_FOOD",
			"hidden": false,
			"stock": true
		},
		"water": {
			"name_key": "RES_WATER",
			"hidden": false,
			"stock": true
		},
		"grain": {
			"name_key": "RES_GRAIN",
			"hidden": false,
			"stock": true
		},
		"flour": {
			"name_key": "RES_FLOUR",
			"hidden": false,
			"stock": true
		},
		"tools": {
			"name_key": "RES_TOOLS",
			"hidden": false,
			"stock": true
		}
	}
}
```


### FICHIER : data/terrains.json

```json
{
	"_comment": "Terrain types. color = hex sRGB; height = top above sea level (planet radius 1); peak = extra height at the cell center; fertility 0..1; resources: id -> [chance 0..1, min, max]. regrow: id -> [amount per day, maximum].",
	"terrains": {
		"ocean": {
			"name_key": "TERRAIN_OCEAN",
			"color": "5aa9d6",
			"height": 0.0,
			"peak": 0.0,
			"water": true,
			"buildable": false,
			"fertility": 0.0,
			"resources": {
				"fish": [
					0.3,
					20,
					50
				]
			}
		},
		"shallow": {
			"name_key": "TERRAIN_SHALLOW",
			"color": "86d0e0",
			"height": 0.0,
			"peak": 0.0,
			"water": true,
			"buildable": false,
			"fertility": 0.0,
			"resources": {
				"fish": [
					0.7,
					30,
					70
				],
				"oil": [
					0.08,
					40,
					100
				]
			}
		},
		"beach": {
			"name_key": "TERRAIN_BEACH",
			"color": "f7e1b5",
			"height": 0.012,
			"peak": 0.0,
			"water": false,
			"buildable": true,
			"fertility": 0.25,
			"resources": {
				"stone": [
					0.1,
					10,
					25
				]
			}
		},
		"plains": {
			"name_key": "TERRAIN_PLAINS",
			"color": "a8d98a",
			"height": 0.018,
			"peak": 0.0,
			"water": false,
			"buildable": true,
			"fertility": 0.85,
			"resources": {
				"wood": [
					0.15,
					10,
					25
				]
			},
			"regrow": {
				"wood": [
					0.1,
					25
				]
			}
		},
		"forest": {
			"name_key": "TERRAIN_FOREST",
			"color": "79c47a",
			"height": 0.022,
			"peak": 0.0,
			"water": false,
			"buildable": true,
			"fertility": 0.5,
			"resources": {
				"wood": [
					1.0,
					40,
					90
				]
			},
			"regrow": {
				"wood": [
					1.0,
					90
				]
			}
		},
		"desert": {
			"name_key": "TERRAIN_DESERT",
			"color": "f1d39b",
			"height": 0.02,
			"peak": 0.0,
			"water": false,
			"buildable": true,
			"fertility": 0.08,
			"resources": {
				"stone": [
					0.25,
					15,
					40
				],
				"oil": [
					0.22,
					30,
					90
				]
			}
		},
		"hills": {
			"name_key": "TERRAIN_HILLS",
			"color": "c5d68f",
			"height": 0.03,
			"peak": 0.02,
			"water": false,
			"buildable": true,
			"fertility": 0.4,
			"resources": {
				"stone": [
					0.8,
					20,
					60
				],
				"ore": [
					0.25,
					15,
					40
				]
			}
		},
		"mountain": {
			"name_key": "TERRAIN_MOUNTAIN",
			"color": "b8aea4",
			"height": 0.035,
			"peak": 0.075,
			"peak_color": "fffaf3",
			"water": false,
			"buildable": false,
			"fertility": 0.0,
			"resources": {
				"stone": [
					1.0,
					50,
					100
				],
				"ore": [
					0.5,
					30,
					80
				],
				"uranium": [
					0.06,
					10,
					30
				]
			}
		},
		"ice": {
			"name_key": "TERRAIN_ICE",
			"color": "f4f8fb",
			"height": 0.016,
			"peak": 0.0,
			"water": false,
			"buildable": false,
			"fertility": 0.0,
			"resources": {}
		}
	}
}
```


### FICHIER : data/townhall.json

```json
{
	"_comment": "Town hall levels. buildings = max count of each building at this level (absent = locked). cost/requires/days = price, conditions and time of the upgrade to this level. perks are cumulative skills.",
	"levels": [
		{
			"level": 1,
			"housing": 4,
			"territory": 3,
			"builders": 1,
			"training_slots": 1,
			"buildings": {
				"hut": 4,
				"campfire": 1,
				"gatherer": 2,
				"woodcutter": 2,
				"well": 2,
				"quarry": 1
			},
			"professions": [
				"water_carrier",
				"gatherer",
				"woodcutter",
				"stonecutter"
			],
			"perks": []
		},
		{
			"level": 2,
			"cost": {
				"wood": 40,
				"stone": 15
			},
			"requires": {
				"population": 6
			},
			"days": 1.0,
			"housing": 6,
			"territory": 4,
			"builders": 1,
			"training_slots": 2,
			"buildings": {
				"hut": 6,
				"campfire": 1,
				"gatherer": 3,
				"woodcutter": 3,
				"well": 3,
				"quarry": 2,
				"field": 2
			},
			"professions": [
				"water_carrier",
				"gatherer",
				"woodcutter",
				"stonecutter",
				"farmer"
			],
			"perks": [
				{
					"id": "gathering",
					"name_key": "PERK_GATHERING",
					"production": {
						"food": 1.1
					}
				}
			]
		},
		{
			"level": 3,
			"cost": {
				"wood": 80,
				"stone": 50
			},
			"requires": {
				"population": 12
			},
			"days": 1.5,
			"housing": 8,
			"territory": 5,
			"builders": 2,
			"training_slots": 2,
			"buildings": {
				"hut": 9,
				"campfire": 2,
				"gatherer": 4,
				"woodcutter": 4,
				"well": 4,
				"quarry": 3,
				"field": 3,
				"mill": 1,
				"bakery": 1,
				"workshop": 1,
				"outpost": 2
			},
			"professions": [
				"water_carrier",
				"gatherer",
				"woodcutter",
				"stonecutter",
				"farmer",
				"miller",
				"baker",
				"artisan"
			],
			"perks": [
				{
					"id": "builders",
					"name_key": "PERK_BUILDERS",
					"build_speed": 1.25
				}
			]
		},
		{
			"level": 4,
			"cost": {
				"wood": 140,
				"stone": 100,
				"tools": 10
			},
			"requires": {
				"population": 20
			},
			"days": 2.0,
			"housing": 10,
			"territory": 6,
			"builders": 2,
			"training_slots": 3,
			"buildings": {
				"hut": 12,
				"longhouse": 6,
				"campfire": 2,
				"gatherer": 5,
				"woodcutter": 5,
				"well": 5,
				"quarry": 4,
				"field": 5,
				"mill": 2,
				"bakery": 2,
				"workshop": 2,
				"outpost": 3,
				"healer": 2,
				"stone_circle": 1
			},
			"professions": [
				"water_carrier",
				"gatherer",
				"woodcutter",
				"stonecutter",
				"farmer",
				"miller",
				"baker",
				"artisan",
				"healer"
			],
			"perks": [
				{
					"id": "teachers",
					"name_key": "PERK_TEACHERS",
					"training_speed": 1.5
				},
				{
					"id": "lumber",
					"name_key": "PERK_LUMBER",
					"production": {
						"wood": 1.1
					}
				}
			]
		},
		{
			"level": 5,
			"cost": {
				"wood": 240,
				"stone": 180,
				"tools": 25,
				"food": 80
			},
			"requires": {
				"population": 32
			},
			"days": 3.0,
			"housing": 12,
			"territory": 7,
			"builders": 3,
			"training_slots": 3,
			"buildings": {
				"hut": 15,
				"longhouse": 10,
				"campfire": 3,
				"gatherer": 6,
				"woodcutter": 6,
				"well": 6,
				"quarry": 5,
				"field": 7,
				"mill": 3,
				"bakery": 3,
				"workshop": 3,
				"outpost": 4,
				"healer": 3,
				"stone_circle": 2
			},
			"professions": [
				"water_carrier",
				"gatherer",
				"woodcutter",
				"stonecutter",
				"farmer",
				"miller",
				"baker",
				"artisan",
				"healer"
			],
			"perks": [
				{
					"id": "festivals",
					"name_key": "PERK_FESTIVALS",
					"happiness": 5
				}
			]
		},
		{
			"level": 6,
			"cost": {
				"wood": 400,
				"stone": 300,
				"tools": 50,
				"food": 150
			},
			"requires": {
				"population": 50
			},
			"days": 4.0,
			"housing": 14,
			"territory": 8,
			"builders": 3,
			"training_slots": 4,
			"buildings": {
				"hut": 18,
				"longhouse": 14,
				"campfire": 4,
				"gatherer": 8,
				"woodcutter": 8,
				"well": 8,
				"quarry": 6,
				"field": 9,
				"mill": 4,
				"bakery": 4,
				"workshop": 4,
				"outpost": 6,
				"healer": 4,
				"stone_circle": 3
			},
			"professions": [
				"water_carrier",
				"gatherer",
				"woodcutter",
				"stonecutter",
				"farmer",
				"miller",
				"baker",
				"artisan",
				"healer"
			],
			"perks": [
				{
					"id": "masons",
					"name_key": "PERK_MASONS",
					"production": {
						"stone": 1.15
					}
				},
				{
					"id": "harvest",
					"name_key": "PERK_HARVEST",
					"production": {
						"food": 1.1
					}
				}
			]
		}
	]
}
```


### FICHIER : data/tutorial.json

```json
{
	"_comment": "Tutorial steps. condition: next | rotate | zoom | select | building:<id>:<count> | trained:<profession>:<count> | village | speed. highlight: build, village, speed, needs.",
	"steps": [
		{
			"id": "welcome",
			"text_key": "TUTO_WELCOME",
			"condition": "next"
		},
		{
			"id": "rotate",
			"text_key": "TUTO_ROTATE",
			"condition": "rotate"
		},
		{
			"id": "zoom",
			"text_key": "TUTO_ZOOM",
			"condition": "zoom"
		},
		{
			"id": "townhall",
			"text_key": "TUTO_TOWNHALL",
			"condition": "village",
			"highlight": "village"
		},
		{
			"id": "well",
			"text_key": "TUTO_WELL",
			"condition": "building:well:1",
			"highlight": "build"
		},
		{
			"id": "train_water",
			"text_key": "TUTO_TRAIN_WATER",
			"condition": "trained:water_carrier:1",
			"highlight": "village"
		},
		{
			"id": "gatherer",
			"text_key": "TUTO_GATHERER",
			"condition": "building:gatherer:1",
			"highlight": "build"
		},
		{
			"id": "train_gatherer",
			"text_key": "TUTO_TRAIN_GATHERER",
			"condition": "trained:gatherer:2",
			"highlight": "village"
		},
		{
			"id": "hut",
			"text_key": "TUTO_HUT",
			"condition": "building:hut:1",
			"highlight": "build"
		},
		{
			"id": "upgrade",
			"text_key": "TUTO_UPGRADE",
			"condition": "next"
		},
		{
			"id": "speed",
			"text_key": "TUTO_SPEED",
			"condition": "speed",
			"highlight": "speed"
		},
		{
			"id": "done",
			"text_key": "TUTO_DONE",
			"condition": "next"
		}
	]
}
```


### FICHIER : project.godot

```ini
; Engine configuration file.
; Mini Planète — Godot 4 project settings.
; Edit with care: the CI reads this file headless.

config_version=5

[application]

config/name="Mini Planète"
config/description="Une petite planète à faire grandir, d'âge en âge."
config/version="0.3.0"
run/main_scene="res://scenes/main.tscn"
config/features=PackedStringArray("4.7", "Mobile")
config/icon="res://assets/icons/app_icon_1024.png"
boot_splash/bg_color=Color(1, 0.965, 0.914, 1)
boot_splash/show_image=false

[autoload]

Loc="*res://scripts/core/localization.gd"
UserSettings="*res://scripts/core/user_settings.gd"
GameState="*res://scripts/core/game_state.gd"

[display]

window/size/viewport_width=390
window/size/viewport_height=844
window/size/window_width_override=390
window/size/window_height_override=844
window/stretch/mode="canvas_items"
window/stretch/aspect="expand"
window/handheld/orientation=1
window/energy_saving/keep_screen_on=false

[input_devices]

pointing/emulate_touch_from_mouse=true
pointing/emulate_mouse_from_touch=true

[internationalization]

locale/fallback="fr"

[physics]

common/physics_ticks_per_second=30

[rendering]

renderer/rendering_method="mobile"
renderer/rendering_method.mobile="mobile"
textures/vram_compression/import_etc2_astc=true
anti_aliasing/quality/msaa_3d=1
lights_and_shadows/directional_shadow/size=1024
environment/defaults/default_clear_color=Color(0.56, 0.79, 0.9, 1)
```


### FICHIER : scripts/core/config.gd

```gdscript
## Loads JSON data files from res://data. Keeps game tuning out of the code.
extends RefCounted


static func load_json(path: String, fallback: Dictionary = {}) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_warning("Data file missing: %s" % path)
		return fallback
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Invalid JSON in %s" % path)
		return fallback
	return parsed


static func game_config() -> Dictionary:
	return load_json("res://data/game_config.json")
```


### FICHIER : scripts/core/game_state.gd

```gdscript
## Autoload "GameState": owns the Simulation, drives it with fixed ticks,
## handles autosave and offline progress. The bridge between the pure
## simulation and the rest of the app (rendering, UI, OS events).
extends Node

const Simulation := preload("res://scripts/simulation/simulation.gd")
const FixedStepper := preload("res://scripts/simulation/fixed_stepper.gd")
const SaveManager := preload("res://scripts/core/save_manager.gd")
const Config := preload("res://scripts/core/config.gd")

signal ticked

var config: Dictionary
var sim: Simulation
var stepper: FixedStepper
## The start screen is shown once per app launch (not after a scene reload).
var start_menu_shown := false
## Days simulated while the app was closed; the UI shows then clears it.
var pending_offline_days := 0
var _autosave_timer := 0.0
## False when the save on disk comes from a newer app version (never overwrite it).
var _saving_enabled := true


func _ready() -> void:
	# Keep simulating when a modal UI pauses the tree later on.
	process_mode = Node.PROCESS_MODE_ALWAYS
	config = Config.game_config()
	config["terrains"] = Config.load_json("res://data/terrains.json").get("terrains", {})
	config["resources"] = Config.load_json("res://data/resources.json").get("resources", {})
	var buildings_file := Config.load_json("res://data/buildings.json")
	config["buildings"] = buildings_file.get("buildings", {})
	config["start"] = buildings_file.get("start", {})
	config["building_categories"] = buildings_file.get("categories", [])
	config["customization"] = Config.load_json("res://data/customization.json")
	config["objectives"] = Config.load_json("res://data/objectives.json").get("objectives", [])
	config["events"] = Config.load_json("res://data/events.json").get("events", [])
	config["tutorial"] = Config.load_json("res://data/tutorial.json")
	config["townhall"] = Config.load_json("res://data/townhall.json").get("levels", [])
	config["professions"] = Config.load_json("res://data/professions.json").get("professions", {})
	stepper = FixedStepper.new(float(config.get("tick_rate_hz", 10)), int(config.get("max_ticks_per_frame", 40)))
	_load_or_create()


func _process(delta: float) -> void:
	var ticks := stepper.advance(delta, sim.speed)
	if ticks > 0:
		sim.run_ticks(ticks)
		ticked.emit()
	_autosave_timer += delta
	if _autosave_timer >= float(config.get("autosave_interval_seconds", 30)):
		save_game()


func _notification(what: int) -> void:
	# iOS can kill a backgrounded app at any time: save as soon as we leave.
	match what:
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_CLOSE_REQUEST:
			save_game()
		NOTIFICATION_APPLICATION_RESUMED:
			stepper.reset()


func save_game() -> void:
	_autosave_timer = 0.0
	if not _saving_enabled:
		return
	var err := SaveManager.save_to_file(sim.to_dict())
	if err != OK:
		push_warning("Save failed: %s" % error_string(err))


## Replaces the current planet with a brand new one, saves it and restarts
## the scene. The previous planet is lost.
## options: frequency, ocean_fraction, hills_threshold, mountain_threshold,
##          seed (-1 = random), name ("" = generated), palette, village_color.
func new_world(options: Dictionary) -> void:
	var world_config := config.duplicate(true)
	for key in ["frequency", "ocean_fraction", "hills_threshold", "mountain_threshold"]:
		if options.has(key):
			world_config["planet"][key] = options[key]
	var world_seed := int(options.get("seed", -1))
	if world_seed < 0:
		world_seed = randi()
	sim = Simulation.new(world_seed, world_config)
	if str(options.get("name", "")).strip_edges() != "":
		sim.custom["planet_name"] = str(options.name).strip_edges()
	for key in ["palette", "village_color", "rings", "moon"]:
		if options.has(key):
			sim.custom[key] = options[key]
	_saving_enabled = true
	stepper.reset()
	save_game()
	get_tree().reload_current_scene()


## Turns any text into a planet seed, so friends can share planets.
static func seed_from_text(text: String) -> int:
	var clean := text.strip_edges()
	if clean == "":
		return -1
	if clean.is_valid_int():
		return absi(clean.to_int())
	return absi(hash(clean.to_lower()))


func new_game(seed_value: int = -1) -> void:
	if seed_value < 0:
		seed_value = randi()
	sim = Simulation.new(seed_value, config)


func _load_or_create() -> void:
	var result := SaveManager.load_from_file()
	match result.status:
		SaveManager.LoadStatus.OK:
			var envelope: Dictionary = result.envelope
			new_game(int(envelope.game.get("world_seed", 0)))
			sim.from_dict(envelope.game)
			_apply_offline_progress(float(envelope.get("saved_at_unix", 0.0)))
		SaveManager.LoadStatus.TOO_NEW:
			# Never overwrite a save from a newer version: play on a temporary world.
			push_warning("Save is from a newer version; starting a temporary world.")
			_saving_enabled = false
			new_game()
		_:
			new_game()


func _apply_offline_progress(saved_at_unix: float) -> void:
	if saved_at_unix <= 0.0:
		return
	var away := Time.get_unix_time_from_system() - saved_at_unix
	if away < 60.0:
		return
	var day_before := sim.day()
	sim.advance_offline(
		away,
		float(config.get("tick_rate_hz", 10)),
		float(config.get("offline_progress_cap_hours", 8)) * 3600.0,
		float(config.get("offline_progress_efficiency", 0.5)))
	pending_offline_days = sim.day() - day_before
```


### FICHIER : scripts/core/localization.gd

```gdscript
## Autoload "Loc": loads UI strings from res://data/locale/<lang>.json.
##
## JSON keeps texts editable without the Godot editor. French is the default;
## the device language is used when a translation exists for it.
extends Node

const LOCALE_DIR := "res://data/locale/"
const DEFAULT_LOCALE := "fr"

var available_locales: PackedStringArray = []


func _ready() -> void:
	_load_all()
	var device := OS.get_locale_language()
	set_locale(device if device in available_locales else DEFAULT_LOCALE)


func set_locale(locale: String) -> void:
	TranslationServer.set_locale(locale)


func _load_all() -> void:
	var dir := DirAccess.open(LOCALE_DIR)
	if dir == null:
		push_error("Locale folder missing")
		return
	for file_name in dir.get_files():
		# Exported builds may list remapped names; keep only the .json sources.
		if not file_name.ends_with(".json"):
			continue
		var locale := file_name.get_basename()
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(LOCALE_DIR + file_name))
		if typeof(parsed) != TYPE_DICTIONARY:
			push_error("Invalid locale file: %s" % file_name)
			continue
		var translation := Translation.new()
		translation.locale = locale
		for key in parsed:
			translation.add_message(key, str(parsed[key]))
		TranslationServer.add_translation(translation)
		available_locales.append(locale)
```


### FICHIER : scripts/core/save_manager.gd

```gdscript
## Versioned JSON save files with forward migrations.
##
## File layout:
##   { "version": <int>, "saved_at_unix": <float>, "game": { ...simulation... } }
##
## RULE: never break an existing save. When the format changes:
##   1. bump SAVE_VERSION,
##   2. add a `_migrate_vN_to_vN+1` function and register it in _migrate().
## Writes are atomic (temp file + rename) and the previous save is kept as .bak.
extends RefCounted

const SAVE_VERSION := 1
const DEFAULT_PATH := "user://savegame.json"

enum LoadStatus { OK, NO_SAVE, CORRUPTED, TOO_NEW }


## Wraps game data into the versioned envelope.
static func build_envelope(game: Dictionary, now_unix: float) -> Dictionary:
	return {"version": SAVE_VERSION, "saved_at_unix": now_unix, "game": game}


static func save_to_file(game: Dictionary, path: String = DEFAULT_PATH) -> Error:
	var envelope := build_envelope(game, Time.get_unix_time_from_system())
	var tmp_path := path + ".tmp"
	var file := FileAccess.open(tmp_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(envelope))  # Compact: big planets have thousands of cells.
	file.close()
	if FileAccess.file_exists(path):
		DirAccess.copy_absolute(path, path + ".bak")
	return DirAccess.rename_absolute(tmp_path, path)


## Returns { "status": LoadStatus, "envelope": Dictionary }.
## The envelope is already migrated to SAVE_VERSION when status is OK.
static func load_from_file(path: String = DEFAULT_PATH) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"status": LoadStatus.NO_SAVE, "envelope": {}}
	var text := FileAccess.get_file_as_string(path)
	var result := parse_and_migrate(text)
	if result.status == LoadStatus.CORRUPTED and FileAccess.file_exists(path + ".bak"):
		# Fall back to the previous save rather than losing everything.
		result = parse_and_migrate(FileAccess.get_file_as_string(path + ".bak"))
	return result


## Pure function (no I/O): parses JSON text and migrates it. Unit-tested.
static func parse_and_migrate(text: String) -> Dictionary:
	# JSON.new().parse() reports errors silently (parse_string logs an engine error).
	var json := JSON.new()
	if json.parse(text) != OK or typeof(json.data) != TYPE_DICTIONARY:
		return {"status": LoadStatus.CORRUPTED, "envelope": {}}
	var envelope: Dictionary = json.data
	var version := int(envelope.get("version", 0))
	if version > SAVE_VERSION:
		# Save written by a newer app version: do not touch it.
		return {"status": LoadStatus.TOO_NEW, "envelope": envelope}
	return {"status": LoadStatus.OK, "envelope": _migrate(envelope)}


static func _migrate(envelope: Dictionary) -> Dictionary:
	var data := envelope.duplicate(true)
	var version := int(data.get("version", 0))
	while version < SAVE_VERSION:
		match version:
			0:
				data = _migrate_v0_to_v1(data)
			_:
				push_error("No migration from save version %d" % version)
				break
		version = int(data.get("version", version + 1))
	return data


## v0 = early prototype format: { "ticks": n, "seed": s } at the root.
## Kept as the reference example of how migrations are written.
static func _migrate_v0_to_v1(old: Dictionary) -> Dictionary:
	return {
		"version": 1,
		"saved_at_unix": float(old.get("saved_at_unix", 0.0)),
		"game": {
			"world_seed": int(old.get("seed", 0)),
			"tick": int(old.get("ticks", 0)),
			"speed": 1,
		},
	}
```


### FICHIER : scripts/core/user_settings.gd

```gdscript
## Autoload "UserSettings": device preferences (not tied to a planet).
## Stored in user://settings.json, separate from the game save.
extends Node

signal changed(key: String)

const PATH := "user://settings.json"
const Haptics := preload("res://scripts/platform/haptics.gd")
const DEFAULTS := {
	"haptics": true,
	"language": "",     # "" = follow the device language
	"clouds": true,
	"outlines": true,
	"sky": "soft",
	"last_version": "",  # Used to greet the player after an update.
}

var values: Dictionary = DEFAULTS.duplicate()


func _ready() -> void:
	if FileAccess.file_exists(PATH):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if typeof(parsed) == TYPE_DICTIONARY:
			for key in parsed:
				if DEFAULTS.has(key) and typeof(parsed[key]) == typeof(DEFAULTS[key]):
					values[key] = parsed[key]
	# Skies from older versions no longer exist: fall back to the default.
	if not (str(values.sky) in ["soft", "sunset", "stars", "aurora", "mist"]):
		values.sky = DEFAULTS.sky
	_apply()


func get_value(key: String):
	return values.get(key, DEFAULTS.get(key))


func set_value(key: String, value) -> void:
	values[key] = value
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(values, "\t"))
	_apply()
	changed.emit(key)


func _apply() -> void:
	Haptics.enabled = bool(values.haptics)
	var language := str(values.language)
	if language != "" and language in Loc.available_locales:
		Loc.set_locale(language)
```


### FICHIER : scripts/simulation/economy.gd

```gdscript
## Economy: stocks, buildings, production chains, workers, population needs.
##
## Pure logic (no node, no rendering), driven by Simulation with a time step
## expressed in days, so the same code serves live play (tiny steps) and
## offline progress (big steps). Rules and numbers come from data/*.json.
##
## Each building may:
##   produce   resources per day (scaled by workers, fertility, tools, happiness),
##   consume   inputs per day (production slows down when inputs run out),
##   extract   from deposits on its cell and neighbours,
##   give      housing, happiness or health to the whole village.
extends RefCounted

## Buildings changed: rendering and UI must refresh.
signal changed
## Something the player should know about (localization key).
signal alert(key: String)
## A construction site (or an upgrade) is finished.
signal construction_done(cell: int)
## The town hall reached a new level.
signal level_up(level: int)
## A villager finished training for a profession.
signal training_done(profession: String)

const ERR_UNKNOWN := "BUILD_ERR_UNKNOWN"
const ERR_OCCUPIED := "BUILD_ERR_OCCUPIED"
const ERR_TERRAIN := "BUILD_ERR_TERRAIN"
const ERR_DEPOSIT := "BUILD_ERR_DEPOSIT"
const ERR_TERRITORY := "BUILD_ERR_TERRITORY"
const ERR_COST := "BUILD_ERR_COST"
const ERR_LOCKED := "BUILD_ERR_LOCKED"
const ERR_LIMIT := "BUILD_ERR_LIMIT"
const ERR_BUILDERS := "BUILD_ERR_BUILDERS"
const ERR_NO_VILLAGER := "TRAIN_ERR_NO_VILLAGER"
const ERR_SLOTS := "TRAIN_ERR_SLOTS"
const ERR_REQUIREMENT := "TH_ERR_REQUIREMENT"
const ERR_MAX := "TH_ERR_MAX"
const ERR_BUSY := "TH_ERR_BUSY"
const BASE_RESOURCES := ["food", "wood", "stone", "water", "grain", "flour", "tools"]

var planet  # PlanetState (untyped to avoid a cyclic preload)
var defs: Dictionary = {}
var terrain_defs: Dictionary = {}
var settings: Dictionary = {}

var stocks: Dictionary = {}
var population := 0
var village_center := -1
## Village well-being, 0..100.
var happiness := 60.0
var health := 80.0
## Territory radii are multiplied by this on planets with many small cells.
var territory_scale := 1
## Net change per day of each resource, measured during the last update.
var rates: Dictionary = {}

## Town hall progression (data/townhall.json) and professions (data/professions.json).
var townhall_levels: Array = []
var professions: Dictionary = {}
var townhall_level := 1
## Days left before the town hall upgrade is done (-1 = no upgrade running).
var townhall_upgrade_left := -1.0
## Trained villagers per profession.
var trained: Dictionary = {}
## Trainings in progress: [{"profession": id, "left": days}, ...]
var training: Array = []
## Construction sites: cell -> {"left": days, "total": days}
var construction: Dictionary = {}

var _building_cells: Array[int] = []
var _territory: Dictionary = {}
var _staffing: Dictionary = {}        # cell -> 0..1
var _building_rates: Dictionary = {}  # cell -> {resource: produced per day}
var _building_inputs: Dictionary = {} # cell -> {resource: consumed per day}
var _waiting: Dictionary = {}         # cell -> true when inputs are missing
var _short_food := false              # Ran out of food since the last daily update.
var _short_water := false


func setup(p_planet, p_defs: Dictionary, p_terrain_defs: Dictionary, p_settings: Dictionary) -> void:
	planet = p_planet
	defs = p_defs
	terrain_defs = p_terrain_defs
	settings = p_settings
	var wb := _wb()
	happiness = float(wb.get("happiness_start", 60.0))
	health = float(wb.get("health_start", 80.0))
	for res in BASE_RESOURCES:
		if not stocks.has(res):
			stocks[res] = 0.0
	_rebuild_caches()


# --- Queries -----------------------------------------------------------------

func building_at(cell: int) -> String:
	return planet.buildings[cell]


func building_cells() -> Array[int]:
	return _building_cells


func def_of(cell: int) -> Dictionary:
	return defs.get(planet.buildings[cell], {})


func housing() -> int:
	var total := 0
	for cell in _building_cells:
		if not is_active(cell):
			continue
		if cell == village_center:
			total += int(level_def().get("housing", 4))
		else:
			total += int(def_of(cell).get("housing", 0))
	return total


func jobs() -> int:
	var total := 0
	for cell in _building_cells:
		if is_active(cell):
			total += int(def_of(cell).get("workers", 0))
	return total


func employed() -> int:
	var total := 0
	for cell in _building_cells:
		total += workers_at(cell)
	return total


# --- Town hall, professions, construction ------------------------------------------

func level_def(level: int = -1) -> Dictionary:
	if level < 0:
		level = townhall_level
	for def in townhall_levels:
		if int(def.get("level", 0)) == level:
			return def
	return {"level": level, "housing": 4, "territory": 3, "builders": 1, "training_slots": 1, "buildings": {}, "professions": []}


func max_level() -> int:
	return maxi(townhall_levels.size(), 1)


## Max number of `id` allowed at the current level (0 = locked).
## Without progression data (old tests, tools), everything is allowed.
func building_limit(id: String) -> int:
	if townhall_levels.is_empty():
		return 999
	return int(level_def().get("buildings", {}).get(id, 0))


## First town hall level that unlocks `id` (0 if never).
func unlock_level(id: String) -> int:
	for def in townhall_levels:
		if int(def.get("buildings", {}).get(id, 0)) > 0:
			return int(def.level)
	return 0


func building_count(id: String) -> int:
	return planet.buildings.count(id)


func is_active(cell: int) -> bool:
	return not construction.has(cell)


## 0..1 progress of the construction site on `cell` (1 when finished).
func construction_progress(cell: int) -> float:
	if not construction.has(cell):
		return 1.0
	var site: Dictionary = construction[cell]
	return clampf(1.0 - float(site.left) / maxf(float(site.total), 0.001), 0.0, 1.0)


func construction_left(cell: int) -> float:
	return float(construction.get(cell, {}).get("left", 0.0)) / _build_speed()


func builders() -> int:
	return int(level_def().get("builders", 1))


func busy_builders() -> int:
	return construction.size() + (1 if townhall_upgrade_left >= 0.0 else 0)


func free_builders() -> int:
	return maxi(0, builders() - busy_builders())


func training_slots() -> int:
	return int(level_def().get("training_slots", 1))


func trained_total() -> int:
	var total := 0
	for p in trained:
		total += int(trained[p])
	return total


func trained_count(profession: String) -> int:
	return int(trained.get(profession, 0))


## Villagers without a profession (and not in training).
func idle_villagers() -> int:
	return maxi(0, population - trained_total() - training.size())


func is_profession_unlocked(profession: String) -> bool:
	if townhall_levels.is_empty():
		return true
	return profession in level_def().get("professions", [])


func profession_jobs(profession: String) -> int:
	var total := 0
	for cell in _building_cells:
		if is_active(cell) and str(def_of(cell).get("profession", "")) == profession:
			total += int(def_of(cell).get("workers", 0))
	return total


func can_train(profession: String) -> String:
	if not professions.has(profession) or not is_profession_unlocked(profession):
		return ERR_LOCKED
	if idle_villagers() <= 0:
		return ERR_NO_VILLAGER
	if training.size() >= training_slots():
		return ERR_SLOTS
	if not can_afford(professions[profession].get("cost", {})):
		return ERR_COST
	return ""


func train(profession: String) -> bool:
	if can_train(profession) != "":
		return false
	var def: Dictionary = professions[profession]
	_pay(def.get("cost", {}))
	training.append({"profession": profession, "left": float(def.get("days", 0.25))})
	return true


## Sends a trained villager back to being a plain villager.
func untrain(profession: String) -> bool:
	if trained_count(profession) <= 0:
		return false
	trained[profession] = trained_count(profession) - 1
	return true


## "" when the town hall can be upgraded now, otherwise the reason key.
func can_upgrade_townhall() -> String:
	if townhall_level >= max_level():
		return ERR_MAX
	if townhall_upgrade_left >= 0.0:
		return ERR_BUSY
	var next := level_def(townhall_level + 1)
	if population < int(next.get("requires", {}).get("population", 0)):
		return ERR_REQUIREMENT
	if free_builders() <= 0:
		return ERR_BUILDERS
	if not can_afford(next.get("cost", {})):
		return ERR_COST
	return ""


func upgrade_townhall() -> bool:
	if can_upgrade_townhall() != "":
		return false
	var next := level_def(townhall_level + 1)
	_pay(next.get("cost", {}))
	townhall_upgrade_left = float(next.get("days", 1.0))
	return true


## Days left for the town hall upgrade, at the current building speed.
func townhall_upgrade_days_left() -> float:
	return maxf(townhall_upgrade_left, 0.0) / _build_speed()


## Skills (perks) unlocked so far, for the UI.
func perks() -> Array:
	var out: Array = []
	for def in townhall_levels:
		if int(def.get("level", 0)) <= townhall_level:
			out.append_array(def.get("perks", []))
	return out


## Test/tool helper: finishes every construction site at once.
func complete_construction() -> void:
	for cell in construction.keys():
		construction.erase(cell)
		construction_done.emit(cell)
	_rebuild_caches()


func workers_at(cell: int) -> int:
	return roundi(float(_staffing.get(cell, 0.0)) * int(def_of(cell).get("workers", 0)))


## Per-day output of a building measured during the last update.
func building_rate(cell: int) -> Dictionary:
	return _building_rates.get(cell, {})


## Per-day inputs used by a building during the last update.
func building_inputs(cell: int) -> Dictionary:
	return _building_inputs.get(cell, {})


## True when a converter (mill, bakery...) is waiting for its inputs.
func is_waiting(cell: int) -> bool:
	return _waiting.has(cell)


func in_territory(cell: int) -> bool:
	return _territory.has(cell)


func stock(res: String) -> float:
	return float(stocks.get(res, 0.0))


## Production multiplier from happiness: 0.6 (miserable) .. 1.2 (joyful).
func productivity() -> float:
	return 0.6 + 0.6 * clampf(happiness, 0.0, 100.0) / 100.0


func can_afford(cost: Dictionary) -> bool:
	for res in cost:
		if stock(res) + 0.0001 < float(cost[res]):
			return false
	return true


## "" when `id` can be built on `cell`, otherwise the localization key of the reason.
## Order matters: the UI hides buildings that can never go on this cell.
func can_build(cell: int, id: String) -> String:
	if not defs.has(id):
		return ERR_UNKNOWN
	if planet.buildings[cell] != "":
		return ERR_OCCUPIED
	var def: Dictionary = defs[id]
	if not def.get("buildable", true):
		return ERR_UNKNOWN
	if building_limit(id) <= 0:
		return ERR_LOCKED
	if not (planet.terrain[cell] in def.get("terrains", [])):
		return ERR_TERRAIN
	if def.has("extracts") and not has_deposit(cell, str(def.extracts)):
		return ERR_DEPOSIT
	if building_count(id) >= building_limit(id):
		return ERR_LIMIT
	if not _territory.has(cell):
		return ERR_TERRITORY
	if float(def.get("build_days", 0.0)) > 0.0 and not townhall_levels.is_empty() and free_builders() <= 0:
		return ERR_BUILDERS
	if not can_afford(def.get("cost", {})):
		return ERR_COST
	return ""


func has_deposit(cell: int, res: String) -> bool:
	for c in _cell_and_neighbors(cell):
		if float(planet.resources[c].get(res, 0.0)) > 0.0:
			return true
	return false


func near_water(cell: int) -> bool:
	for nb in planet.grid.neighbors[cell]:
		if terrain_defs.get(planet.terrain[nb], {}).get("water", false):
			return true
	return false


## What pushes happiness up or down right now: [[localization key, points], ...].
func happiness_factors() -> Array:
	var wb := _wb()
	var factors: Array = [["WB_BASE", float(wb.get("happiness_base", 50))]]
	var leisure := minf(_sum_bonus("happiness"), float(wb.get("leisure_cap", 30)))
	if leisure > 0.0:
		factors.append(["WB_LEISURE", leisure])
	var perk_joy := 0.0
	for perk in perks():
		perk_joy += float(perk.get("happiness", 0.0))
	if perk_joy > 0.0:
		factors.append(["WB_PERKS", perk_joy])
	if _short_food or stock("food") <= 0.0:
		factors.append(["WB_FAMINE", float(wb.get("famine_happiness", -25))])
	if _short_water or stock("water") <= 0.0:
		factors.append(["WB_THIRST", float(wb.get("thirst_happiness", -20))])
	if population > housing():
		factors.append(["WB_HOMELESS", float(wb.get("homeless_happiness", -15))])
	if population > 0 and population - employed() > population * 0.4:
		factors.append(["WB_UNEMPLOYED", float(wb.get("unemployment_happiness", -8))])
	var health_effect := (health - 60.0) * 0.2
	if absf(health_effect) >= 1.0:
		factors.append(["WB_HEALTH", health_effect])
	return factors


## What pushes health up or down right now.
func health_factors() -> Array:
	var wb := _wb()
	var factors: Array = [["WB_BASE", float(wb.get("health_base", 65))]]
	var care := minf(_sum_bonus("health"), float(wb.get("health_bonus_cap", 30)))
	if care > 0.0:
		factors.append(["WB_CARE", care])
	if _short_food or stock("food") <= 0.0:
		factors.append(["WB_FAMINE", float(wb.get("famine_health", -20))])
	if _short_water or stock("water") <= 0.0:
		factors.append(["WB_THIRST", float(wb.get("thirst_health", -30))])
	if population > housing():
		factors.append(["WB_CROWDING", float(wb.get("crowding_health", -10))])
	return factors


static func target_of(factors: Array) -> float:
	var total := 0.0
	for f in factors:
		total += float(f[1])
	return clampf(total, 0.0, 100.0)


# --- Actions -----------------------------------------------------------------

func build(cell: int, id: String) -> bool:
	if can_build(cell, id) != "":
		return false
	_pay(defs[id].get("cost", {}))
	_start_site(cell, float(defs[id].get("build_days", 0.0)))
	_place(cell, id)
	return true


## Building this one can be upgraded into ("" if none).
func upgrade_target(cell: int) -> String:
	return str(def_of(cell).get("upgrade_to", ""))


func upgrade_cost(cell: int) -> Dictionary:
	return defs.get(upgrade_target(cell), {}).get("upgrade_cost", {})


## "" when the building on `cell` can be upgraded now, else the reason key.
func can_upgrade(cell: int) -> String:
	var target := upgrade_target(cell)
	if target == "" or not defs.has(target):
		return ERR_UNKNOWN
	if not is_active(cell):
		return ERR_BUSY
	if building_limit(target) <= 0:
		return ERR_LOCKED
	if building_count(target) >= building_limit(target):
		return ERR_LIMIT
	if not townhall_levels.is_empty() and free_builders() <= 0:
		return ERR_BUILDERS
	if not can_afford(upgrade_cost(cell)):
		return ERR_COST
	return ""


func upgrade(cell: int) -> bool:
	if can_upgrade(cell) != "":
		return false
	var target := upgrade_target(cell)
	_pay(upgrade_cost(cell))
	_start_site(cell, float(defs[target].get("build_days", 0.0)))
	_place(cell, target)
	return true


## Removes a building and refunds half of its cost. The village center stays.
func demolish(cell: int) -> bool:
	var id: String = planet.buildings[cell]
	if id == "" or cell == village_center:
		return false
	var cost: Dictionary = defs.get(id, {}).get("cost", {})
	for res in cost:
		stocks[res] = stock(res) + float(cost[res]) * 0.5
	planet.buildings[cell] = ""
	construction.erase(cell)
	_rebuild_caches()
	changed.emit()
	return true


## New game: starting stocks, population and free buildings on a good spot.
func found_village(start: Dictionary) -> void:
	stocks = {}
	for res in BASE_RESOURCES:
		stocks[res] = 0.0
	var start_stocks: Dictionary = start.get("stocks", {})
	for res in start_stocks:
		stocks[res] = float(start_stocks[res])
	population = int(start.get("population", 4))
	trained = {}
	var start_trained: Dictionary = start.get("trained", {})
	for p in start_trained:
		trained[str(p)] = int(start_trained[p])
	var to_place: Array = start.get("buildings", ["campfire", "hut"])
	if to_place.is_empty():
		return
	village_center = _pick_start_cell(str(to_place[0]))
	if village_center < 0:
		return
	planet.buildings[village_center] = str(to_place[0])
	var candidates: Array = Array(planet.grid.neighbors[village_center])
	candidates.sort_custom(func(a, b): return planet.fertility[a] > planet.fertility[b])
	for k in range(1, to_place.size()):
		var id := str(to_place[k])
		for c in candidates:
			if planet.buildings[c] == "" and planet.terrain[c] in defs.get(id, {}).get("terrains", []):
				planet.buildings[c] = id
				break
	_rebuild_caches()
	changed.emit()


# --- Time --------------------------------------------------------------------

## Continuous production and consumption over `dt_days` (can be a fraction).
func update(dt_days: float) -> void:
	if dt_days <= 0.0:
		return
	var wb := _wb()
	_advance_timers(dt_days)
	_compute_staffing()
	var new_rates := {}
	for res in BASE_RESOURCES:
		new_rates[res] = 0.0
	_building_rates.clear()
	_building_inputs.clear()
	_waiting.clear()
	var village_productivity := productivity()
	for cell in _building_cells:
		var def := def_of(cell)
		var produces: Dictionary = def.get("produces", {})
		if produces.is_empty() or not is_active(cell):
			continue
		var mult: float = float(_staffing.get(cell, 0.0)) * village_productivity
		if mult <= 0.0:
			continue
		if def.get("fertility_bonus", false):
			mult *= 0.4 + planet.fertility[cell]
		if def.has("water_bonus") and near_water(cell):
			mult *= float(def.water_bonus)
		if def.get("tool_bonus", false) and stock("tools") > 0.0:
			mult *= float(wb.get("tool_bonus", 1.25))
			var worn := minf(stock("tools"), float(wb.get("tool_use_per_day", 0.05)) * dt_days)
			stocks["tools"] = stock("tools") - worn
			new_rates["tools"] = float(new_rates["tools"]) - worn / dt_days

		# Inputs: the scarcest one limits the whole production.
		var consumes: Dictionary = def.get("consumes", {})
		var supply := 1.0
		for res in consumes:
			var need := float(consumes[res]) * mult * dt_days
			if need > 0.0:
				supply = minf(supply, stock(res) / need)
		if supply < 0.999 and not consumes.is_empty():
			_waiting[cell] = true
		if supply <= 0.0:
			continue
		var inputs := {}
		for res in consumes:
			var used := float(consumes[res]) * mult * dt_days * supply
			stocks[res] = maxf(0.0, stock(res) - used)
			inputs[res] = used / dt_days
			new_rates[res] = float(new_rates.get(res, 0.0)) - inputs[res]
		var outputs := {}
		for res in produces:
			var amount := float(produces[res]) * mult * dt_days * supply * _perk_production(str(res))
			if def.has("extracts"):
				amount = _extract(cell, str(def.extracts), amount)
			stocks[res] = stock(res) + amount
			outputs[res] = amount / dt_days
			new_rates[res] = float(new_rates.get(res, 0.0)) + outputs[res]
		_building_rates[cell] = outputs
		_building_inputs[cell] = inputs

	# People eat and drink.
	_consume_needs("food", float(settings.get("food_per_person_per_day", 1.0)), dt_days, new_rates)
	_consume_needs("water", float(settings.get("water_per_person_per_day", 1.0)), dt_days, new_rates)
	rates = new_rates


## Once per in-game day: nature regrows, well-being evolves, population changes.
func daily_update() -> void:
	_regrow()
	var wb := _wb()
	happiness += (target_of(happiness_factors()) - happiness) * float(wb.get("happiness_speed", 0.25))
	health += (target_of(health_factors()) - health) * float(wb.get("health_speed", 0.2))
	var capacity := housing()
	if stock("food") <= 0.0 and population > 0:
		var loss := maxi(1, ceili(population * float(settings.get("famine_loss", 0.1))))
		population = maxi(0, population - loss)
		alert.emit("ALERT_FAMINE")
	elif stock("water") <= 0.0 and population > 0:
		population -= 1
		alert.emit("ALERT_THIRST")
	elif population > capacity:
		population -= 1
		alert.emit("ALERT_HOMELESS")
	elif health < 25.0 and population > 0:
		population -= 1
		alert.emit("ALERT_SICKNESS")
	elif happiness < 20.0 and population > 0:
		population -= 1
		alert.emit("ALERT_UNHAPPY")
	elif population < capacity and happiness >= 40.0 and health >= 40.0:
		var births := maxi(1, _growth_bonus()) + (1 if happiness >= 75.0 else 0)
		population += mini(capacity - population, births)
	_trim_trained()
	_short_food = false
	_short_water = false


# --- Save --------------------------------------------------------------------

func to_dict() -> Dictionary:
	var saved_stocks := {}
	for res in stocks:
		saved_stocks[res] = snappedf(stock(res), 0.01)
	return {
		"stocks": saved_stocks,
		"population": population,
		"village_center": village_center,
		"happiness": snappedf(happiness, 0.01),
		"health": snappedf(health, 0.01),
		"townhall_level": townhall_level,
		"townhall_upgrade_left": snappedf(townhall_upgrade_left, 0.0001),
		"trained": trained,
		"training": training,
		"construction": _construction_to_save(),
	}


func from_dict(data: Dictionary) -> void:
	stocks = {}
	for res in BASE_RESOURCES:
		stocks[res] = 0.0
	var saved: Dictionary = data.get("stocks", {})
	for res in saved:
		stocks[str(res)] = float(saved[res])
	# Saves from before Phase 3 had no water: give a fair amount to start with.
	if not saved.has("water"):
		stocks["water"] = 40.0
	population = maxi(int(data.get("population", 0)), 0)
	village_center = int(data.get("village_center", -1))
	var wb := _wb()
	happiness = clampf(float(data.get("happiness", wb.get("happiness_start", 60.0))), 0.0, 100.0)
	health = clampf(float(data.get("health", wb.get("health_start", 80.0))), 0.0, 100.0)
	trained = {}
	var saved_trained: Dictionary = data.get("trained", {})
	for p in saved_trained:
		trained[str(p)] = int(saved_trained[p])
	training = []
	for t in data.get("training", []):
		if typeof(t) == TYPE_DICTIONARY:
			training.append({"profession": str(t.get("profession", "")), "left": float(t.get("left", 0.0))})
	construction = {}
	var saved_sites: Dictionary = data.get("construction", {})
	for key in saved_sites:
		var site: Dictionary = saved_sites[key]
		construction[int(key)] = {"left": float(site.get("left", 0.0)), "total": float(site.get("total", 1.0))}
	if data.has("townhall_level"):
		townhall_level = clampi(int(data.townhall_level), 1, max_level())
		townhall_upgrade_left = float(data.get("townhall_upgrade_left", -1.0))
		_rebuild_caches()
	else:
		_migrate_to_townhall()


# --- Internals ---------------------------------------------------------------

func _wb() -> Dictionary:
	return settings.get("wellbeing", {})


func _consume_needs(res: String, per_person: float, dt_days: float, new_rates: Dictionary) -> void:
	var need := population * per_person
	if need <= 0.0:
		return
	if stock(res) < need * dt_days:
		if res == "food":
			_short_food = true
		else:
			_short_water = true
	stocks[res] = maxf(0.0, stock(res) - need * dt_days)
	new_rates[res] = float(new_rates.get(res, 0.0)) - need


## Sum of a village bonus ("happiness", "health", "growth_bonus") from
## buildings, scaled by how well each one is staffed.
func _sum_bonus(key: String) -> float:
	var total := 0.0
	for cell in _building_cells:
		if not is_active(cell):
			continue
		var value := float(def_of(cell).get(key, 0.0))
		if value != 0.0:
			total += value * float(_staffing.get(cell, 1.0 if int(def_of(cell).get("workers", 0)) == 0 else 0.0))
	return total


func _pay(cost: Dictionary) -> void:
	for res in cost:
		stocks[res] = stock(res) - float(cost[res])


func _start_site(cell: int, days: float) -> void:
	if days > 0.0 and not townhall_levels.is_empty():
		construction[cell] = {"left": days, "total": days}


func _build_speed() -> float:
	var speed := 1.0
	for perk in perks():
		speed *= float(perk.get("build_speed", 1.0))
	return speed


func _train_speed() -> float:
	var speed := 1.0
	for perk in perks():
		speed *= float(perk.get("training_speed", 1.0))
	return speed


func _perk_production(res: String) -> float:
	var mult := 1.0
	for perk in perks():
		mult *= float(perk.get("production", {}).get(res, 1.0))
	return mult


## Construction sites, town hall upgrade and trainings move forward.
func _advance_timers(dt_days: float) -> void:
	var build_step := dt_days * _build_speed()
	var finished: Array = []
	for cell in construction:
		construction[cell].left = float(construction[cell].left) - build_step
		if float(construction[cell].left) <= 0.0:
			finished.append(cell)
	for cell in finished:
		construction.erase(cell)
	if not finished.is_empty():
		_rebuild_caches()
		for cell in finished:
			construction_done.emit(cell)
		changed.emit()
	if townhall_upgrade_left >= 0.0:
		townhall_upgrade_left -= build_step
		if townhall_upgrade_left <= 0.0:
			townhall_upgrade_left = -1.0
			townhall_level = mini(townhall_level + 1, max_level())
			_rebuild_caches()
			level_up.emit(townhall_level)
			changed.emit()
	var train_step := dt_days * _train_speed()
	var done: Array = []
	for t in training:
		t.left = float(t.left) - train_step
		if float(t.left) <= 0.0:
			done.append(t)
	for t in done:
		training.erase(t)
		trained[t.profession] = trained_count(str(t.profession)) + 1
		training_done.emit(str(t.profession))


## When people leave or die, trainings stop first, then jobs are lost
## (from the largest profession).
func _trim_trained() -> void:
	while population < trained_total() + training.size():
		if not training.is_empty():
			training.pop_back()
			continue
		var biggest := ""
		for p in trained:
			if biggest == "" or int(trained[p]) > int(trained[biggest]):
				biggest = p
		if biggest == "" or int(trained[biggest]) <= 0:
			break
		trained[biggest] = int(trained[biggest]) - 1


func _construction_to_save() -> Dictionary:
	var out := {}
	for cell in construction:
		out[str(cell)] = {"left": snappedf(float(construction[cell].left), 0.0001), "total": construction[cell].total}
	return out


## Saves from before the town hall: the central campfire becomes the town
## hall (level 1) and the people already working are trained for their job,
## so the village keeps running exactly as before.
func _migrate_to_townhall() -> void:
	townhall_level = 1
	townhall_upgrade_left = -1.0
	if village_center >= 0 and planet.buildings[village_center] == "campfire" and defs.has("townhall"):
		planet.buildings[village_center] = "townhall"
	_rebuild_caches()
	if townhall_levels.is_empty():
		return
	var free := population
	for cell in _building_cells:
		var def := def_of(cell)
		var profession := str(def.get("profession", ""))
		var need := int(def.get("workers", 0))
		if profession == "" or need <= 0:
			continue
		var got := mini(need, free)
		free -= got
		trained[profession] = trained_count(profession) + got
	_compute_staffing()


func _place(cell: int, id: String) -> void:
	planet.buildings[cell] = id
	_rebuild_caches()
	changed.emit()


func _rebuild_caches() -> void:
	_building_cells.clear()
	if planet == null:
		return
	for i in planet.cell_count():
		if planet.buildings[i] != "":
			_building_cells.append(i)
	_building_cells.sort_custom(func(a, b):
		var pa := int(def_of(a).get("priority", 9))
		var pb := int(def_of(b).get("priority", 9))
		return pa < pb or (pa == pb and a < b))
	_territory = {}
	for cell in _building_cells:
		var radius := int(def_of(cell).get("territory", 2))
		if cell == village_center:
			radius = int(level_def().get("territory", radius))
		_mark_territory(cell, radius * territory_scale)
	_compute_staffing()


func _mark_territory(start: int, radius: int) -> void:
	_territory[start] = true
	var seen := {start: true}
	var frontier: Array = [start]
	for step in radius:
		var next: Array = []
		for c in frontier:
			for nb in planet.grid.neighbors[c]:
				if not seen.has(nb):
					seen[nb] = true
					_territory[nb] = true
					next.append(nb)
		frontier = next


## Gives jobs to trained villagers, building by building (priority order).
## A building only gets villagers trained for its profession. Without
## progression data (old saves/tests), anyone can work anywhere.
func _compute_staffing() -> void:
	_staffing.clear()
	var free := population
	var pools := trained.duplicate()
	for cell in _building_cells:
		var def := def_of(cell)
		var need := int(def.get("workers", 0))
		if not is_active(cell):
			_staffing[cell] = 0.0
			continue
		if need <= 0:
			_staffing[cell] = 1.0
			continue
		var got := 0
		var profession := str(def.get("profession", ""))
		if townhall_levels.is_empty() or profession == "":
			got = mini(need, free)
			free -= got
		else:
			got = mini(need, int(pools.get(profession, 0)))
			pools[profession] = int(pools.get(profession, 0)) - got
		_staffing[cell] = float(got) / float(need)


func _cell_and_neighbors(cell: int) -> Array:
	var cells: Array = [cell]
	cells.append_array(Array(planet.grid.neighbors[cell]))
	return cells


## Takes up to `wanted` of `res` from the cell, then its neighbours.
## Returns the amount actually taken (deposits run out).
func _extract(cell: int, res: String, wanted: float) -> float:
	var remaining := wanted
	for c in _cell_and_neighbors(cell):
		if remaining <= 0.0:
			break
		var deposit: Dictionary = planet.resources[c]
		var available := float(deposit.get(res, 0.0))
		if available <= 0.0:
			continue
		var take := minf(available, remaining)
		if available - take <= 0.001:
			deposit.erase(res)
		else:
			deposit[res] = available - take
		remaining -= take
	return wanted - remaining


func _regrow() -> void:
	for i in planet.cell_count():
		var regrow: Dictionary = terrain_defs.get(planet.terrain[i], {}).get("regrow", {})
		for res in regrow:
			var spec: Array = regrow[res]
			var current := float(planet.resources[i].get(res, 0.0))
			if current < float(spec[1]):
				planet.resources[i][res] = minf(float(spec[1]), current + float(spec[0]))


func _growth_bonus() -> int:
	return int(_sum_bonus("growth_bonus"))


## Most fertile land cell (with some land around) where `id` is allowed.
func _pick_start_cell(id: String) -> int:
	var allowed: Array = defs.get(id, {}).get("terrains", ["plains"])
	var best := -1
	var best_score := -INF
	for i in planet.cell_count():
		if not (planet.terrain[i] in allowed):
			continue
		var land := 0
		var wood_near := false
		var water_near := false
		for nb in planet.grid.neighbors[i]:
			if terrain_defs.get(planet.terrain[nb], {}).get("water", false):
				water_near = true
			else:
				land += 1
			if planet.terrain[nb] == "forest":
				wood_near = true
		var score: float = planet.fertility[i] + 0.06 * land + (0.15 if wood_near else 0.0) + (0.1 if water_near else 0.0)
		if score > best_score:
			best_score = score
			best = i
	return best
```


### FICHIER : scripts/simulation/events.gd

```gdscript
## Random events with choices (travelers, storms, harvests...).
## Pure logic; definitions come from data/events.json.
extends RefCounted


## Picks an event that fits the current state, or "" (weighted random).
static func pick(sim, events: Array, rng: RandomNumberGenerator) -> String:
	var candidates: Array = []
	var total := 0.0
	for ev in events:
		if sim.day() < int(ev.get("min_day", 0)):
			continue
		if sim.economy.population < int(ev.get("min_population", 0)):
			continue
		candidates.append(ev)
		total += float(ev.get("weight", 1))
	if candidates.is_empty():
		return ""
	var roll := rng.randf() * total
	for ev in candidates:
		roll -= float(ev.get("weight", 1))
		if roll <= 0.0:
			return str(ev.id)
	return str(candidates[-1].id)


static func find(events: Array, id: String) -> Dictionary:
	for ev in events:
		if str(ev.get("id", "")) == id:
			return ev
	return {}


## Applies the effects of a choice. Newcomers only arrive if there is room.
static func apply(sim, effects: Dictionary) -> void:
	var eco = sim.economy
	for key in effects:
		var value := float(effects[key])
		match str(key):
			"population":
				if value > 0.0:
					eco.population += mini(int(value), maxi(0, eco.housing() - eco.population))
				else:
					eco.population = maxi(0, eco.population + int(value))
			"happiness":
				eco.happiness = clampf(eco.happiness + value, 0.0, 100.0)
			"health":
				eco.health = clampf(eco.health + value, 0.0, 100.0)
			_:
				eco.stocks[key] = maxf(0.0, eco.stock(str(key)) + value)
```


### FICHIER : scripts/simulation/fixed_stepper.gd

```gdscript
## Converts variable frame time into a whole number of fixed simulation ticks.
##
## Pure logic (no Node, no engine singletons) so it can be unit-tested headless.
## The accumulator keeps the leftover time between frames, which makes the
## simulation independent from the frame rate. A per-frame cap prevents the
## "spiral of death" when a frame takes too long (e.g. app resumed from background).
extends RefCounted

var tick_rate_hz: float = 10.0
var max_ticks_per_frame: int = 40
var _accumulator: float = 0.0


func _init(p_tick_rate_hz: float = 10.0, p_max_ticks_per_frame: int = 40) -> void:
	tick_rate_hz = maxf(p_tick_rate_hz, 0.001)
	max_ticks_per_frame = maxi(p_max_ticks_per_frame, 1)


## Duration of one tick in seconds.
func tick_duration() -> float:
	return 1.0 / tick_rate_hz


## Feeds `delta` real seconds at the given speed multiplier and returns how
## many ticks must be simulated now. Speed 0 means paused.
func advance(delta: float, speed: int) -> int:
	if speed <= 0 or delta <= 0.0:
		return 0
	_accumulator += delta * speed
	var dt := tick_duration()
	var ticks := int(floor(_accumulator / dt))
	if ticks > max_ticks_per_frame:
		# Drop the excess instead of trying to catch up forever.
		ticks = max_ticks_per_frame
		_accumulator = 0.0
	else:
		_accumulator -= ticks * dt
	return ticks


## Fraction (0..1) of the next tick already elapsed: useful for smooth rendering.
func interpolation_alpha() -> float:
	return clampf(_accumulator / tick_duration(), 0.0, 1.0)


func reset() -> void:
	_accumulator = 0.0
```


### FICHIER : scripts/simulation/hex_grid.gd

```gdscript
## Hexagonal tiling of the unit sphere (Goldberg polyhedron).
##
## Built as the dual of a geodesic icosphere of the given frequency:
##   cells = 10 * frequency² + 2  (frequency 6 -> 362 cells),
##   exactly 12 cells are pentagons, all others are hexagons.
## Pure geometry, deterministic, no engine node: unit-tested headless.
extends RefCounted

const ICO_FACES := [
	[0, 11, 5], [0, 5, 1], [0, 1, 7], [0, 7, 10], [0, 10, 11],
	[1, 5, 9], [5, 11, 4], [11, 10, 2], [10, 7, 6], [7, 1, 8],
	[3, 9, 4], [3, 4, 2], [3, 2, 6], [3, 6, 8], [3, 8, 9],
	[4, 9, 5], [2, 4, 11], [6, 2, 10], [8, 6, 7], [9, 8, 1],
]

var frequency := 1
## Unit vector pointing to the center of each cell.
var centers := PackedVector3Array()
## Neighbor cell indices, sorted counter-clockwise (seen from outside).
var neighbors: Array[PackedInt32Array] = []
## Polygon corners (unit vectors), sorted counter-clockwise (seen from outside).
var corners: Array[PackedVector3Array] = []


static func cell_count_for(p_frequency: int) -> int:
	return 10 * p_frequency * p_frequency + 2


func _init(p_frequency: int = 6) -> void:
	frequency = maxi(p_frequency, 1)
	var base := _icosahedron_vertices()
	var index_of := {}
	var triangles: Array[Vector3i] = []
	for face_id in ICO_FACES.size():
		var face: Array = ICO_FACES[face_id]
		var rows: Array[PackedInt32Array] = []
		for i in frequency + 1:
			var row := PackedInt32Array()
			for j in frequency + 1 - i:
				row.append(_vertex(face_id, face[0], face[1], face[2], i, j, base, index_of))
			rows.append(row)
		for i in frequency:
			for j in frequency - i:
				triangles.append(Vector3i(rows[i][j], rows[i + 1][j], rows[i][j + 1]))
				if j < frequency - 1 - i:
					triangles.append(Vector3i(rows[i + 1][j], rows[i + 1][j + 1], rows[i][j + 1]))
	_build_topology(triangles)


func cell_count() -> int:
	return centers.size()


func is_pentagon(cell: int) -> bool:
	return neighbors[cell].size() == 5


## Index of the cell containing the direction `dir` (any length).
func find_cell(dir: Vector3) -> int:
	var d := dir.normalized()
	var best := -1
	var best_dot := -INF
	for i in centers.size():
		var dot := centers[i].dot(d)
		if dot > best_dot:
			best_dot = dot
			best = i
	return best


static func _icosahedron_vertices() -> PackedVector3Array:
	var t := (1.0 + sqrt(5.0)) / 2.0
	var verts := PackedVector3Array([
		Vector3(-1, t, 0), Vector3(1, t, 0), Vector3(-1, -t, 0), Vector3(1, -t, 0),
		Vector3(0, -1, t), Vector3(0, 1, t), Vector3(0, -1, -t), Vector3(0, 1, -t),
		Vector3(t, 0, -1), Vector3(t, 0, 1), Vector3(-t, 0, -1), Vector3(-t, 0, 1),
	])
	for i in verts.size():
		verts[i] = verts[i].normalized()
	return verts


## Returns the shared vertex index for barycentric grid point (i, j) of a face.
## Points on icosahedron edges/corners use canonical keys so that the
## adjacent faces reuse exactly the same vertex (no floating-point rounding).
func _vertex(face_id: int, a: int, b: int, c: int, i: int, j: int,
		base: PackedVector3Array, index_of: Dictionary) -> int:
	var f := frequency
	var key: String
	var pos: Vector3
	if i == 0 and j == 0:
		key = "v%d" % a
		pos = base[a]
	elif i == f:
		key = "v%d" % b
		pos = base[b]
	elif j == f:
		key = "v%d" % c
		pos = base[c]
	elif j == 0:
		var e := _edge_point(a, b, i, base)
		key = e[0]
		pos = e[1]
	elif i == 0:
		var e := _edge_point(a, c, j, base)
		key = e[0]
		pos = e[1]
	elif i + j == f:
		var e := _edge_point(b, c, j, base)
		key = e[0]
		pos = e[1]
	else:
		key = "f%d_%d_%d" % [face_id, i, j]
		pos = base[a] * float(f - i - j) + base[b] * float(i) + base[c] * float(j)
	if index_of.has(key):
		return index_of[key]
	centers.append(pos.normalized())
	index_of[key] = centers.size() - 1
	return centers.size() - 1


## Point k steps (out of frequency) from vertex u toward vertex v.
func _edge_point(u: int, v: int, k: int, base: PackedVector3Array) -> Array:
	if u > v:
		var tmp := u
		u = v
		v = tmp
		k = frequency - k
	var pos := base[u].lerp(base[v], float(k) / float(frequency))
	return ["e%d_%d_%d" % [u, v, k], pos]


func _build_topology(triangles: Array[Vector3i]) -> void:
	var n := centers.size()
	var adjacency: Array[Dictionary] = []
	var triangles_of: Array[PackedInt32Array] = []
	for k in n:
		adjacency.append({})
		triangles_of.append(PackedInt32Array())
	var tri_centers := PackedVector3Array()
	for t in triangles:
		tri_centers.append((centers[t.x] + centers[t.y] + centers[t.z]).normalized())
		var ti := tri_centers.size() - 1
		triangles_of[t.x].append(ti)
		triangles_of[t.y].append(ti)
		triangles_of[t.z].append(ti)
		adjacency[t.x][t.y] = true
		adjacency[t.y][t.x] = true
		adjacency[t.y][t.z] = true
		adjacency[t.z][t.y] = true
		adjacency[t.z][t.x] = true
		adjacency[t.x][t.z] = true

	for v in n:
		var normal := centers[v]
		var t1 := _tangent(normal)
		var t2 := normal.cross(t1)
		var nb: Array = adjacency[v].keys()
		var pts := centers
		nb.sort_custom(func(p, q): return _angle(pts[p] - normal, t1, t2) < _angle(pts[q] - normal, t1, t2))
		neighbors.append(PackedInt32Array(nb))
		var cs: Array = []
		for ti in triangles_of[v]:
			cs.append(tri_centers[ti])
		cs.sort_custom(func(p, q): return _angle(p - normal, t1, t2) < _angle(q - normal, t1, t2))
		corners.append(PackedVector3Array(cs))


static func _tangent(normal: Vector3) -> Vector3:
	var helper := Vector3.UP if absf(normal.y) < 0.9 else Vector3.RIGHT
	return normal.cross(helper).normalized()


static func _angle(d: Vector3, t1: Vector3, t2: Vector3) -> float:
	return atan2(d.dot(t2), d.dot(t1))
```


### FICHIER : scripts/simulation/objectives.gd

```gdscript
## Goals: evaluates progress from the simulation state and grants rewards.
## Pure logic; definitions come from data/objectives.json.
extends RefCounted


## [current, target] for one objective definition.
static func progress(sim, obj: Dictionary) -> Array:
	var eco = sim.economy
	var target := float(obj.get("value", 1))
	var current := 0.0
	match str(obj.get("type", "")):
		"population":
			current = eco.population
		"townhall":
			current = eco.townhall_level
		"trained":
			current = eco.trained_total()
		"building":
			current = sim.planet.buildings.count(str(obj.get("target", "")))
		"buildings_total":
			current = eco.building_cells().size()
		"happiness":
			current = eco.happiness
		"health":
			current = eco.health
		"day":
			current = sim.day()
		"stock":
			current = eco.stock(str(obj.get("target", "")))
	return [minf(current, target), target]


static func is_done(sim, obj: Dictionary) -> bool:
	var p := progress(sim, obj)
	return p[0] >= p[1]


## Marks newly reached objectives as completed, gives their rewards and
## returns their ids.
static func check(sim, objectives: Array) -> Array:
	var newly: Array = []
	for obj in objectives:
		var id := str(obj.get("id", ""))
		if id == "" or id in sim.completed_objectives:
			continue
		if is_done(sim, obj):
			sim.completed_objectives.append(id)
			var reward: Dictionary = obj.get("reward", {})
			for res in reward:
				sim.economy.stocks[res] = sim.economy.stock(res) + float(reward[res])
			newly.append(id)
	return newly
```


### FICHIER : scripts/simulation/planet_generator.gd

```gdscript
## Procedural planet generation from a seed: terrain, fertility, resources.
## Pure and deterministic (same seed + same data = same planet).
## All tuning lives in data/game_config.json ("planet") and data/terrains.json.
extends RefCounted


## Returns { "terrain": PackedStringArray, "fertility": PackedFloat32Array,
##           "resources": Array[Dictionary] } for every cell of `grid`.
static func generate(grid, world_seed: int, terrains: Dictionary, settings: Dictionary) -> Dictionary:
	var n: int = grid.cell_count()
	var elevation_noise := _noise(world_seed, float(settings.get("noise_frequency", 1.3)), 4)
	var moisture_noise := _noise(world_seed + 101, float(settings.get("moisture_frequency", 1.7)), 3)

	var elevation := PackedFloat32Array()
	var moisture := PackedFloat32Array()
	elevation.resize(n)
	moisture.resize(n)
	for i in n:
		var p: Vector3 = grid.centers[i]
		elevation[i] = elevation_noise.get_noise_3dv(p)
		moisture[i] = clampf(moisture_noise.get_noise_3dv(p) * 0.5 + 0.5, 0.0, 1.0)

	# Sea level chosen so that the ocean covers a fixed share of the planet,
	# whatever the seed: every planet stays playable.
	var sorted := elevation.duplicate()
	sorted.sort()
	var ocean_fraction := clampf(float(settings.get("ocean_fraction", 0.55)), 0.0, 0.95)
	var sea := sorted[int(ocean_fraction * float(n - 1))]
	var low := sorted[0]
	var high := sorted[n - 1]
	var shallow_line := sea - (sea - low) * float(settings.get("shallow_band", 0.12)) * 3.0

	var terrain := PackedStringArray()
	terrain.resize(n)
	for i in n:
		var latitude := absf(grid.centers[i].y)
		var e := elevation[i]
		if e < sea:
			if latitude > float(settings.get("ice_latitude_water", 0.9)):
				terrain[i] = "ice"
			elif e > shallow_line:
				terrain[i] = "shallow"
			else:
				terrain[i] = "ocean"
			continue
		if latitude > float(settings.get("ice_latitude_land", 0.8)):
			terrain[i] = "ice"
			continue
		var h := (e - sea) / maxf(high - sea, 0.0001)  # 0 at the shore, 1 at the highest peak
		if h > float(settings.get("mountain_threshold", 0.7)):
			terrain[i] = "mountain"
		elif h > float(settings.get("hills_threshold", 0.48)):
			terrain[i] = "hills"
		else:
			var temperature := 1.0 - latitude * 1.1 - h * 0.3
			if temperature > 0.62 and moisture[i] < 0.4:
				terrain[i] = "desert"
			elif moisture[i] > 0.55:
				terrain[i] = "forest"
			else:
				terrain[i] = "plains"

	# Beaches: low land touching water (second pass: needs the water map).
	var beach_threshold := float(settings.get("beach_threshold", 0.1))
	for i in n:
		if terrain[i] in ["plains", "forest", "desert"]:
			var h := (elevation[i] - sea) / maxf(high - sea, 0.0001)
			if h < beach_threshold and _touches_water(grid, terrain, i, terrains):
				terrain[i] = "beach"

	# Fertility and resources.
	var rng := RandomNumberGenerator.new()
	rng.seed = world_seed + 7
	var fertility := PackedFloat32Array()
	fertility.resize(n)
	var resources: Array[Dictionary] = []
	for i in n:
		var def: Dictionary = terrains.get(terrain[i], {})
		var base := float(def.get("fertility", 0.0))
		fertility[i] = snappedf(clampf(base * (0.75 + 0.5 * moisture[i]), 0.0, 1.0), 0.01)
		var cell_resources := {}
		var table: Dictionary = def.get("resources", {})
		for res_id in table:
			var spec: Array = table[res_id]
			if rng.randf() < float(spec[0]):
				cell_resources[res_id] = rng.randi_range(int(spec[1]), int(spec[2]))
		resources.append(cell_resources)
	return {"terrain": terrain, "fertility": fertility, "resources": resources}


static func _touches_water(grid, terrain: PackedStringArray, cell: int, terrains: Dictionary) -> bool:
	for nb in grid.neighbors[cell]:
		var def: Dictionary = terrains.get(terrain[nb], {})
		if def.get("water", terrain[nb] in ["ocean", "shallow"]):
			return true
	return false


static func _noise(noise_seed: int, frequency: float, octaves: int) -> FastNoiseLite:
	var noise := FastNoiseLite.new()
	noise.seed = noise_seed
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = frequency
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = octaves
	return noise
```


### FICHIER : scripts/simulation/planet_state.gd

```gdscript
## State of every cell of the planet: terrain, fertility, resources, pollution.
## The hex grid geometry is rebuilt from `frequency`; the cell data itself is
## saved, so a planet never changes when the generator is tuned later.
extends RefCounted

const HexGrid := preload("res://scripts/simulation/hex_grid.gd")
const PlanetGenerator := preload("res://scripts/simulation/planet_generator.gd")

var grid: HexGrid
var terrain := PackedStringArray()
var fertility := PackedFloat32Array()
## One Dictionary per cell: resource id -> remaining amount.
var resources: Array[Dictionary] = []
var pollution := PackedFloat32Array()
## Building id on each cell ("" = none).
var buildings := PackedStringArray()


func _init(frequency: int = 6) -> void:
	grid = HexGrid.new(frequency)


func cell_count() -> int:
	return grid.cell_count()


func generate(world_seed: int, terrains: Dictionary, settings: Dictionary) -> void:
	var data := PlanetGenerator.generate(grid, world_seed, terrains, settings)
	terrain = data.terrain
	fertility = data.fertility
	resources = data.resources
	pollution = PackedFloat32Array()
	pollution.resize(cell_count())
	pollution.fill(0.0)
	buildings = PackedStringArray()
	buildings.resize(cell_count())


func count_terrain(terrain_id: String) -> int:
	return terrain.count(terrain_id)


func to_dict() -> Dictionary:
	return {
		"frequency": grid.frequency,
		"terrain": Array(terrain),
		"fertility": Array(fertility),
		"resources": resources,
		"pollution": Array(pollution),
		"buildings": Array(buildings),
	}


## Loads saved cells. Returns false if the data is unusable (caller regenerates).
func from_dict(data: Dictionary) -> bool:
	var frequency := int(data.get("frequency", grid.frequency))
	if frequency != grid.frequency:
		grid = HexGrid.new(frequency)
	var n := cell_count()
	var saved_terrain: Array = data.get("terrain", [])
	var saved_fertility: Array = data.get("fertility", [])
	var saved_resources: Array = data.get("resources", [])
	if saved_terrain.size() != n or saved_fertility.size() != n or saved_resources.size() != n:
		return false
	terrain = PackedStringArray(saved_terrain)
	fertility = PackedFloat32Array(saved_fertility)
	resources.clear()
	for r in saved_resources:
		var cell := {}
		if typeof(r) == TYPE_DICTIONARY:
			for key in r:
				cell[str(key)] = snappedf(float(r[key]), 0.01)
		resources.append(cell)
	var saved_pollution: Array = data.get("pollution", [])
	pollution = PackedFloat32Array(saved_pollution) if saved_pollution.size() == n else PackedFloat32Array()
	if pollution.size() != n:
		pollution.resize(n)
		pollution.fill(0.0)
	var saved_buildings: Array = data.get("buildings", [])
	buildings = PackedStringArray(saved_buildings) if saved_buildings.size() == n else PackedStringArray()
	buildings.resize(n)
	return true
```


### FICHIER : scripts/simulation/simulation.gd

```gdscript
## Core game simulation: pure, deterministic, frame-rate independent.
##
## Never touches nodes, rendering or the file system. The rendering layer
## reads its state; the GameState autoload drives it with fixed ticks.
## Everything that must survive a restart goes through to_dict()/from_dict().
extends RefCounted

signal day_passed(day: int)

const PlanetState := preload("res://scripts/simulation/planet_state.gd")
const Economy := preload("res://scripts/simulation/economy.gd")
const Objectives := preload("res://scripts/simulation/objectives.gd")
const Events := preload("res://scripts/simulation/events.gd")

signal objective_completed(id: String)
signal event_started(id: String)
const DEFAULT_TICKS_PER_DAY := 600

var world_seed: int = 0
var tick: int = 0
var speed: int = 1
var ticks_per_day: int = DEFAULT_TICKS_PER_DAY
var allowed_speeds: Array = [0, 1, 2, 4]

## Deterministic random generator owned by the simulation (seeded from world_seed).
var rng := RandomNumberGenerator.new()
## Every cell of the planet (terrain, resources...).
var planet: PlanetState
var terrain_defs: Dictionary = {}
var planet_settings: Dictionary = {}
## Stocks, buildings, workers, population.
var economy := Economy.new()
var building_defs: Dictionary = {}
var start_settings: Dictionary = {}
var economy_settings: Dictionary = {}
## Player customization of this planet (name, colors).
var custom := {"planet_name": "", "palette": "classic", "village_color": "d9b45c", "rings": false, "moon": true}
## Goals reached so far (ids from data/objectives.json).
var completed_objectives: Array = []
## Random event waiting for the player's choice ("" = none).
var pending_event := ""
## Tutorial progress: index of the current step, -1 when finished/skipped.
var tutorial_step := 0
var objective_defs: Array = []
var event_defs: Array = []
var event_settings: Dictionary = {}
var event_rng := RandomNumberGenerator.new()
var townhall_levels: Array = []
var profession_defs: Dictionary = {}
var name_syllables: Array = []


func _init(p_seed: int = 0, config: Dictionary = {}) -> void:
	world_seed = p_seed
	rng.seed = p_seed
	ticks_per_day = maxi(int(config.get("ticks_per_day", DEFAULT_TICKS_PER_DAY)), 1)
	allowed_speeds = config.get("allowed_speeds", allowed_speeds)
	terrain_defs = config.get("terrains", {})
	planet_settings = config.get("planet", {})
	building_defs = config.get("buildings", {})
	start_settings = config.get("start", {})
	economy_settings = config.get("economy", {})
	name_syllables = config.get("customization", {}).get("name_syllables", [])
	objective_defs = config.get("objectives", [])
	townhall_levels = config.get("townhall", [])
	profession_defs = config.get("professions", {})
	event_defs = config.get("events", [])
	event_settings = config.get("event_settings", {})
	event_rng.seed = p_seed + 4242
	custom.planet_name = generate_name(world_seed, name_syllables)
	planet = PlanetState.new(int(planet_settings.get("frequency", 6)))
	planet.generate(world_seed, terrain_defs, planet_settings)
	economy.territory_scale = _territory_scale()
	economy.townhall_levels = townhall_levels
	economy.professions = profession_defs
	economy.setup(planet, building_defs, terrain_defs, economy_settings)
	economy.found_village(start_settings)


## Current in-game day, starting at 1.
func day() -> int:
	return tick / ticks_per_day + 1


## Position inside the current day, 0.0 (dawn) .. 1.0. Drives the day/night cycle.
func time_of_day() -> float:
	return float(tick % ticks_per_day) / float(ticks_per_day)


## Advances the world by exactly one fixed tick.
func step() -> void:
	var previous_day := day()
	tick += 1
	economy.update(1.0 / float(ticks_per_day))
	if day() != previous_day:
		economy.daily_update()
		_daily_extras()
		day_passed.emit(day())


func run_ticks(count: int) -> void:
	for i in count:
		step()


## Checks goals (rewards are given right away). Call after any player action.
func check_objectives() -> void:
	for id in Objectives.check(self, objective_defs):
		objective_completed.emit(id)


## Applies the player's choice for the pending event.
func resolve_event(choice_index: int) -> void:
	var ev := Events.find(event_defs, pending_event)
	pending_event = ""
	var choices: Array = ev.get("choices", [])
	if choice_index >= 0 and choice_index < choices.size():
		Events.apply(self, choices[choice_index].get("effects", {}))
	check_objectives()


func _daily_extras() -> void:
	check_objectives()
	if pending_event == "" and not event_defs.is_empty() and day() >= int(event_settings.get("first_day", 4)):
		if event_rng.randf() < float(event_settings.get("daily_chance", 0.12)):
			pending_event = Events.pick(self, event_defs, event_rng)
			if pending_event != "":
				event_started.emit(pending_event)


## Bigger planets have smaller cells: territories cover more cells.
func _territory_scale() -> int:
	var reference := float(planet_settings.get("territory_reference_frequency", 8))
	return maxi(1, roundi(float(planet.grid.frequency) / maxf(reference, 1.0)))


## Pleasant planet name made of 2-3 syllables, deterministic for a seed.
static func generate_name(name_seed: int, syllables: Array) -> String:
	var parts: Array = syllables if not syllables.is_empty() else ["ka", "lo", "mi", "ra", "ze", "no"]
	var rng := RandomNumberGenerator.new()
	rng.seed = name_seed + 97
	var result := ""
	for i in rng.randi_range(2, 3):
		result += str(parts[rng.randi() % parts.size()])
	return result.capitalize()


func set_speed(value: int) -> bool:
	if value in allowed_speeds:
		speed = value
		return true
	return false


## Simplified catch-up for time spent away from the game.
## `seconds` is real time; `tick_rate_hz` converts it to ticks;
## `efficiency` (0..1) makes offline time worth less than active play.
## Returns the number of ticks simulated.
func advance_offline(seconds: float, tick_rate_hz: float, cap_seconds: float, efficiency: float) -> int:
	var effective := clampf(seconds, 0.0, cap_seconds) * clampf(efficiency, 0.0, 1.0)
	var ticks := int(effective * tick_rate_hz)
	# Big steps (1/20 of a day) instead of every tick: same rules, much faster.
	var chunk := maxi(1, ticks_per_day / 20)
	var remaining := ticks
	while remaining > 0:
		var n := mini(chunk, remaining)
		var previous_day := day()
		tick += n
		economy.update(float(n) / float(ticks_per_day))
		for d in day() - previous_day:
			economy.daily_update()
			check_objectives()
		remaining -= n
	return ticks


func to_dict() -> Dictionary:
	return {
		"world_seed": world_seed,
		"tick": tick,
		"speed": speed,
		"rng_state": str(rng.state),  # stored as string: JSON numbers are doubles.
		"planet": planet.to_dict(),
		"economy": economy.to_dict(),
		"custom": custom,
		"completed_objectives": completed_objectives,
		"pending_event": pending_event,
		"tutorial_step": tutorial_step,
		"event_rng_state": str(event_rng.state),
	}


func from_dict(data: Dictionary) -> void:
	world_seed = int(data.get("world_seed", world_seed))
	tick = maxi(int(data.get("tick", 0)), 0)
	var saved_speed := int(data.get("speed", 1))
	speed = saved_speed if saved_speed in allowed_speeds else 1
	rng.seed = world_seed
	custom.planet_name = generate_name(world_seed, name_syllables)
	var saved_custom = data.get("custom")
	if typeof(saved_custom) == TYPE_DICTIONARY:
		for key in custom:
			if saved_custom.has(key) and str(saved_custom[key]) != "":
				custom[key] = saved_custom[key] if typeof(custom[key]) == TYPE_BOOL else str(saved_custom[key])
	completed_objectives = Array(data.get("completed_objectives", []))
	pending_event = str(data.get("pending_event", ""))
	if pending_event != "" and Events.find(event_defs, pending_event).is_empty():
		pending_event = ""
	tutorial_step = int(data.get("tutorial_step", 0))
	event_rng.seed = world_seed + 4242
	if data.has("event_rng_state"):
		event_rng.state = str(data["event_rng_state"]).to_int()
	if data.has("rng_state"):
		rng.state = str(data["rng_state"]).to_int()
	# Saves made before Phase 1 have no planet: generate it from the seed.
	var loaded := false
	if typeof(data.get("planet")) == TYPE_DICTIONARY:
		loaded = planet.from_dict(data["planet"])
	if not loaded:
		planet = PlanetState.new(int(planet_settings.get("frequency", 6)))
		planet.generate(world_seed, terrain_defs, planet_settings)
	economy = Economy.new()
	economy.territory_scale = _territory_scale()
	economy.townhall_levels = townhall_levels
	economy.professions = profession_defs
	economy.setup(planet, building_defs, terrain_defs, economy_settings)
	if typeof(data.get("economy")) == TYPE_DICTIONARY:
		economy.from_dict(data["economy"])
	else:
		# Saves made before Phase 2: found the village now.
		economy.found_village(start_settings)
```


### FICHIER : tests/run_tests.gd

```gdscript
## Headless test runner.
##   godot --headless --path . -s res://tests/run_tests.gd
## Runs every tests/unit/test_*.gd and exits with code 1 on any failure.
extends SceneTree

const UNIT_DIR := "res://tests/unit/"


func _initialize() -> void:
	var total := 0
	var failed := 0
	var files := DirAccess.get_files_at(UNIT_DIR)
	files.sort()
	for file_name in files:
		if not (file_name.begins_with("test_") and file_name.ends_with(".gd")):
			continue
		var script: GDScript = load(UNIT_DIR + file_name)
		if script == null or not script.can_instantiate():
			print("✗ %s: failed to load (parse error?)" % file_name)
			failed += 1
			continue
		for method in script.get_script_method_list():
			var name: String = method.name
			if not name.begins_with("test_"):
				continue
			total += 1
			var suite = script.new()  # Fresh instance per test: no shared state.
			suite._current = "%s::%s" % [file_name, name]
			suite.call(name)
			if suite.failures.is_empty():
				print("✓ %s" % suite._current)
			else:
				failed += 1
				for f in suite.failures:
					print("✗ %s" % f)
	print("\n%d tests, %d failed" % [total, failed])
	quit(1 if failed > 0 or total == 0 else 0)
```


### FICHIER : tests/test_case.gd

```gdscript
## Minimal assertion base class for headless tests (no third-party addon).
## Each test file extends this; every method starting with "test_" is run.
extends RefCounted

var failures: PackedStringArray = []
var _current := ""


func _fail(message: String) -> void:
	failures.append("%s: %s" % [_current, message])


func assert_true(value: bool, message: String = "expected true") -> void:
	if not value:
		_fail(message)


func assert_false(value: bool, message: String = "expected false") -> void:
	if value:
		_fail(message)


func assert_eq(actual, expected, message: String = "") -> void:
	if typeof(actual) != typeof(expected) or actual != expected:
		_fail("expected <%s> got <%s> %s" % [str(expected), str(actual), message])


func assert_almost_eq(actual: float, expected: float, tolerance: float = 1e-5, message: String = "") -> void:
	if absf(actual - expected) > tolerance:
		_fail("expected %f ± %f got %f %s" % [expected, tolerance, actual, message])
```


### FICHIER : tests/unit/test_customization.gd

```gdscript
extends "res://tests/test_case.gd"

const Simulation := preload("res://scripts/simulation/simulation.gd")


func _json(path: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(path))


func _config() -> Dictionary:
	var config := _json("res://data/game_config.json")
	config["terrains"] = _json("res://data/terrains.json").terrains
	var buildings := _json("res://data/buildings.json")
	config["buildings"] = buildings.buildings
	config["start"] = buildings.start
	config["customization"] = _json("res://data/customization.json")
	return config


func test_default_planet_has_1442_cells() -> void:
	var sim := Simulation.new(3, _config())
	assert_eq(sim.planet.cell_count(), 1442)


func test_planet_sizes_build_the_right_grid() -> void:
	for size in _json("res://data/customization.json").planet_sizes:
		var config := _config()
		config["planet"]["frequency"] = int(size.frequency)
		var sim := Simulation.new(5, config)
		var f := int(size.frequency)
		assert_eq(sim.planet.cell_count(), 10 * f * f + 2, str(size.id))
		assert_true(sim.economy.village_center >= 0, "village on %s planet" % size.id)


func test_planet_name_is_deterministic_and_nice() -> void:
	var syllables: Array = _json("res://data/customization.json").name_syllables
	var a := Simulation.generate_name(12, syllables)
	assert_eq(a, Simulation.generate_name(12, syllables))
	assert_true(a.length() >= 4 and a.length() <= 12, a)
	assert_eq(a.substr(0, 1), a.substr(0, 1).to_upper())


func test_customization_survives_save() -> void:
	var sim := Simulation.new(9, _config())
	sim.custom["planet_name"] = "Gaïa"
	sim.custom["palette"] = "mars"
	sim.custom["village_color"] = "3a7bc0"
	var loaded := Simulation.new(1, _config())
	loaded.from_dict(JSON.parse_string(JSON.stringify(sim.to_dict())))
	assert_eq(loaded.custom, sim.custom)


func test_old_save_gets_a_generated_name() -> void:
	var sim := Simulation.new(9, _config())
	var data := sim.to_dict()
	data.erase("custom")
	var loaded := Simulation.new(1, _config())
	loaded.from_dict(JSON.parse_string(JSON.stringify(data)))
	assert_true(str(loaded.custom.planet_name) != "")
	assert_eq(loaded.custom.palette, "classic")


func test_palettes_only_use_known_terrains() -> void:
	var terrains: Dictionary = _json("res://data/terrains.json").terrains
	var palettes: Dictionary = _json("res://data/customization.json").palettes
	for id in palettes:
		for terrain in palettes[id].colors:
			assert_true(terrains.has(terrain), "palette %s: unknown terrain %s" % [id, terrain])


func test_every_building_has_an_icon_and_texts() -> void:
	var fr := _json("res://data/locale/fr.json")
	var buildings: Dictionary = _json("res://data/buildings.json").buildings
	for id in buildings:
		assert_true(FileAccess.file_exists("res://assets/icons/ui/%s.svg" % id), "icon for " + id)
		for key in ["name_key", "desc_key", "short_key"]:
			assert_true(fr.has(buildings[id][key]), "%s.%s" % [id, key])


func test_every_option_has_a_label() -> void:
	var fr := _json("res://data/locale/fr.json")
	var options := _json("res://data/customization.json")
	for group in ["palettes", "skies"]:
		for id in options[group]:
			assert_true(fr.has(options[group][id].name_key), "%s.%s" % [group, id])
	for size in options.planet_sizes:
		assert_true(fr.has(size.name_key), str(size.id))
```


### FICHIER : tests/unit/test_economy.gd

```gdscript
extends "res://tests/test_case.gd"

const Simulation := preload("res://scripts/simulation/simulation.gd")
const Economy := preload("res://scripts/simulation/economy.gd")


func _config() -> Dictionary:
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/game_config.json"))
	config["terrains"] = JSON.parse_string(FileAccess.get_file_as_string("res://data/terrains.json")).terrains
	var buildings: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/buildings.json"))
	config["buildings"] = buildings.buildings
	config["start"] = buildings.start
	config["townhall"] = JSON.parse_string(FileAccess.get_file_as_string("res://data/townhall.json")).levels
	config["professions"] = JSON.parse_string(FileAccess.get_file_as_string("res://data/professions.json")).professions
	return config


func _sim(world_seed: int = 7) -> Simulation:
	return Simulation.new(world_seed, _config())


## First free cell in the territory where `id` can go if we ignore the cost.
func _spot(sim: Simulation, id: String) -> int:
	var eco := sim.economy
	for i in sim.planet.cell_count():
		var reason := eco.can_build(i, id)
		if reason == "" or reason == Economy.ERR_COST:
			return i
	return -1


func test_new_game_founds_a_village() -> void:
	for s in [1, 2, 3, 7, 42]:
		var sim := _sim(s)
		var eco := sim.economy
		assert_true(eco.village_center >= 0, "seed %d has no village" % s)
		assert_eq(sim.planet.buildings[eco.village_center], "townhall")
		assert_eq(eco.building_cells().size(), 1, "only the town hall for seed %d" % s)
		assert_eq(eco.population, 4)
		assert_eq(eco.housing(), 4)


func test_build_costs_resources() -> void:
	var sim := _sim()
	var eco := sim.economy
	var cell := _spot(sim, "hut")
	assert_true(cell >= 0, "no spot for a hut")
	var wood_before := eco.stock("wood")
	assert_true(eco.build(cell, "hut"))
	assert_almost_eq(eco.stock("wood"), wood_before - 10.0)
	assert_eq(eco.housing(), 4, "still a construction site")
	eco.complete_construction()
	assert_eq(eco.housing(), 8)
	assert_false(eco.build(cell, "hut"), "cell already occupied")


func test_cannot_build_without_resources() -> void:
	var sim := _sim()
	var eco := sim.economy
	eco.stocks["wood"] = 3.0
	var cell := _spot(sim, "hut")
	assert_eq(eco.can_build(cell, "hut"), Economy.ERR_COST)
	assert_false(eco.build(cell, "hut"))


func test_cannot_build_outside_territory() -> void:
	var sim := _sim()
	var eco := sim.economy
	eco.stocks["wood"] = 999.0
	var far := -1
	for i in sim.planet.cell_count():
		if not eco.in_territory(i) and sim.planet.terrain[i] == "plains":
			far = i
			break
	assert_true(far >= 0)
	assert_eq(eco.can_build(far, "hut"), Economy.ERR_TERRITORY)


func test_cannot_build_on_water() -> void:
	var sim := _sim()
	var ocean := sim.planet.terrain.find("ocean")
	assert_eq(sim.economy.can_build(ocean, "hut"), Economy.ERR_TERRAIN)


func test_people_eat_food() -> void:
	var sim := _sim()
	var eco := sim.economy
	var food := eco.stock("food")
	sim.run_ticks(sim.ticks_per_day / 2)  # Half a day, no producer yet.
	assert_almost_eq(eco.stock("food"), food - eco.population * 0.5, 0.05)


func test_gatherer_produces_food() -> void:
	var sim := _sim()
	var eco := sim.economy
	eco.stocks["wood"] = 100.0
	var cell := _spot(sim, "gatherer")
	assert_true(eco.build(cell, "gatherer"))
	eco.complete_construction()
	eco.trained["gatherer"] = 2
	eco.update(1.0)
	var rate: Dictionary = eco.building_rate(cell)
	assert_true(float(rate.get("food", 0.0)) > 2.0, "gatherer output %s" % str(rate))
	assert_eq(eco.workers_at(cell), 2)


func test_famine_kills_and_growth_fills_huts() -> void:
	var sim := _sim()
	var eco := sim.economy
	eco.stocks["food"] = 0.0
	eco.daily_update()
	assert_eq(eco.population, 3, "famine")
	eco.stocks["food"] = 100.0
	eco.daily_update()
	assert_eq(eco.population, 4, "birth up to housing")
	eco.daily_update()
	assert_eq(eco.population, 4, "no birth without housing")


func test_extraction_depletes_deposits() -> void:
	var sim := _sim()
	var eco := sim.economy
	eco.stocks["wood"] = 100.0
	var cell := _spot(sim, "woodcutter")
	assert_true(eco.build(cell, "woodcutter"))
	eco.complete_construction()
	eco.trained["woodcutter"] = 2
	var total_before := _wood_around(sim, cell)
	eco.update(2.0)
	var gained: float = eco.building_rate(cell).get("wood", 0.0) * 2.0
	assert_almost_eq(_wood_around(sim, cell), total_before - gained, 0.05)


func _wood_around(sim: Simulation, cell: int) -> float:
	var total := float(sim.planet.resources[cell].get("wood", 0.0))
	for nb in sim.planet.grid.neighbors[cell]:
		total += float(sim.planet.resources[nb].get("wood", 0.0))
	return total


func test_demolish_refunds_half() -> void:
	var sim := _sim()
	var eco := sim.economy
	var cell := _spot(sim, "hut")
	eco.build(cell, "hut")
	var wood := eco.stock("wood")
	assert_true(eco.demolish(cell))
	assert_almost_eq(eco.stock("wood"), wood + 5.0)
	assert_false(eco.demolish(eco.village_center), "village center stays")


func test_economy_survives_save() -> void:
	var sim := _sim(11)
	var eco := sim.economy
	var cell := _spot(sim, "hut")
	eco.build(cell, "hut")
	sim.run_ticks(sim.ticks_per_day * 3)
	var json := JSON.stringify(sim.to_dict())
	var loaded := Simulation.new(1, _config())
	loaded.from_dict(JSON.parse_string(json))
	assert_eq(loaded.planet.buildings, sim.planet.buildings)
	assert_eq(loaded.economy.population, eco.population)
	assert_almost_eq(loaded.economy.stock("food"), eco.stock("food"), 0.02)
	assert_eq(loaded.economy.village_center, eco.village_center)
	assert_eq(loaded.economy.housing(), eco.housing())


func test_phase1_save_gets_a_village() -> void:
	var sim := _sim(5)
	var old := sim.to_dict()
	old.erase("economy")
	old["planet"].erase("buildings")
	var loaded := Simulation.new(1, _config())
	loaded.from_dict(JSON.parse_string(JSON.stringify(old)))
	assert_true(loaded.economy.village_center >= 0)
	assert_eq(loaded.economy.population, 4)


func test_offline_progress_runs_the_economy() -> void:
	var sim := _sim()
	var food := sim.economy.stock("food")
	sim.advance_offline(3600.0, 10.0, 8 * 3600.0, 0.5)  # 18000 ticks = 30 days
	assert_true(sim.economy.stock("food") < food, "people ate while away")
```


### FICHIER : tests/unit/test_features.gd

```gdscript
extends "res://tests/test_case.gd"

const Simulation := preload("res://scripts/simulation/simulation.gd")
const Objectives := preload("res://scripts/simulation/objectives.gd")
const Events := preload("res://scripts/simulation/events.gd")
const GameStateScript := preload("res://scripts/core/game_state.gd")


func _json(path: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(path))


func _config() -> Dictionary:
	var config := _json("res://data/game_config.json")
	config["terrains"] = _json("res://data/terrains.json").terrains
	var buildings := _json("res://data/buildings.json")
	config["buildings"] = buildings.buildings
	config["start"] = buildings.start
	config["customization"] = _json("res://data/customization.json")
	config["objectives"] = _json("res://data/objectives.json").objectives
	config["events"] = _json("res://data/events.json").events
	return config


func _sim(world_seed: int = 3) -> Simulation:
	return Simulation.new(world_seed, _config())


func _goal(sim: Simulation, id: String) -> Dictionary:
	for obj in sim.objective_defs:
		if obj.id == id:
			return obj
	return {}


func test_objective_rewards_are_given_once() -> void:
	var sim := _sim()
	var eco := sim.economy
	var cell := -1
	for i in sim.planet.cell_count():
		if eco.can_build(i, "well") == "":
			cell = i
			break
	assert_true(cell >= 0, "no spot for a well")
	eco.build(cell, "well")
	var wood := eco.stock("wood")
	sim.check_objectives()
	assert_true("first_well" in sim.completed_objectives)
	assert_almost_eq(eco.stock("wood"), wood + 10.0)
	sim.check_objectives()
	assert_almost_eq(eco.stock("wood"), wood + 10.0, 0.001, "not twice")


func test_objective_progress() -> void:
	var sim := _sim()
	sim.economy.population = 7
	var p := Objectives.progress(sim, _goal(sim, "pop_10"))
	assert_eq(p, [7.0, 10.0])


func test_travelers_need_room() -> void:
	var sim := _sim()
	var eco := sim.economy
	eco.population = eco.housing() - 1  # Room for one only.
	sim.pending_event = "travelers"
	sim.resolve_event(0)
	assert_eq(eco.population, eco.housing())
	assert_eq(sim.pending_event, "")


func test_event_effects_change_stocks_and_mood() -> void:
	var sim := _sim()
	var eco := sim.economy
	var food := eco.stock("food")
	var happy := eco.happiness
	Events.apply(sim, {"food": -10, "happiness": 15})
	assert_almost_eq(eco.stock("food"), food - 10.0)
	assert_almost_eq(eco.happiness, minf(100.0, happy + 15.0))


func test_events_happen_and_respect_conditions() -> void:
	var sim := _sim()
	sim.economy.population = 1
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	for i in 50:
		var id := Events.pick(sim, sim.event_defs, rng)
		var ev := Events.find(sim.event_defs, id)
		assert_true(sim.economy.population >= int(ev.get("min_population", 0)), "%s needs more people" % id)


func test_pending_event_survives_save() -> void:
	var sim := _sim()
	sim.pending_event = "storm"
	sim.completed_objectives = ["first_well"]
	sim.tutorial_step = 4
	var loaded := _sim(1)
	loaded.from_dict(JSON.parse_string(JSON.stringify(sim.to_dict())))
	assert_eq(loaded.pending_event, "storm")
	assert_eq(loaded.completed_objectives, ["first_well"])
	assert_eq(loaded.tutorial_step, 4)


func test_hut_upgrades_to_longhouse() -> void:
	var sim := _sim()
	var eco := sim.economy
	eco.stocks["wood"] = 110.0
	eco.stocks["stone"] = 100.0
	var hut := -1
	for i in sim.planet.cell_count():
		if eco.can_build(i, "hut") == "":
			hut = i
			break
	assert_true(eco.build(hut, "hut"))
	var housing := eco.housing()
	assert_eq(eco.can_upgrade(hut), "")
	assert_true(eco.upgrade(hut))
	assert_eq(sim.planet.buildings[hut], "longhouse")
	assert_eq(eco.housing(), housing + 5)
	assert_almost_eq(eco.stock("wood"), 80.0)


func test_longhouse_is_not_in_build_menu() -> void:
	var sim := _sim()
	for i in sim.planet.cell_count():
		assert_true(sim.economy.can_build(i, "longhouse") != "")


func test_territory_grows_with_planet_size() -> void:
	var small_cfg := _config()
	small_cfg["planet"]["frequency"] = 8
	var big_cfg := _config()
	big_cfg["planet"]["frequency"] = 16
	var small := Simulation.new(5, small_cfg)
	var big := Simulation.new(5, big_cfg)
	assert_eq(small.economy.territory_scale, 1)
	assert_eq(big.economy.territory_scale, 2)


func test_ocean_option_changes_the_planet() -> void:
	var wet := _config()
	wet["planet"]["ocean_fraction"] = 0.7
	var dry := _config()
	dry["planet"]["ocean_fraction"] = 0.38
	var a := Simulation.new(9, wet).planet
	var b := Simulation.new(9, dry).planet
	var water_a := a.count_terrain("ocean") + a.count_terrain("shallow")
	var water_b := b.count_terrain("ocean") + b.count_terrain("shallow")
	assert_true(water_a > water_b + 200, "%d vs %d" % [water_a, water_b])


func test_seed_text_is_stable() -> void:
	assert_eq(GameStateScript.seed_from_text(""), -1)
	assert_eq(GameStateScript.seed_from_text("1234"), 1234)
	assert_eq(GameStateScript.seed_from_text("Gaïa"), GameStateScript.seed_from_text("gaïa"))
	assert_true(GameStateScript.seed_from_text("Gaïa") >= 0)


func test_tutorial_steps_are_valid() -> void:
	var fr := _json("res://data/locale/fr.json")
	var buildings: Dictionary = _json("res://data/buildings.json").buildings
	var known := ["next", "rotate", "zoom", "select", "needs", "speed", "goals", "village"]
	var professions: Dictionary = _json("res://data/professions.json").professions
	for step in _json("res://data/tutorial.json").steps:
		assert_true(fr.has(step.text_key), step.text_key)
		var condition := str(step.condition)
		if condition.begins_with("building:"):
			assert_true(buildings.has(condition.split(":")[1]), condition)
		elif condition.begins_with("trained:"):
			assert_true(professions.has(condition.split(":")[1]), condition)
		else:
			assert_true(condition in known, condition)


func test_objectives_and_events_have_texts() -> void:
	var fr := _json("res://data/locale/fr.json")
	var en := _json("res://data/locale/en.json")
	for obj in _json("res://data/objectives.json").objectives:
		assert_true(fr.has(obj.title_key) and en.has(obj.title_key), obj.title_key)
	for ev in _json("res://data/events.json").events:
		for key in [ev.title_key, ev.text_key]:
			assert_true(fr.has(key) and en.has(key), key)
		for choice in ev.choices:
			assert_true(fr.has(choice.label_key) and en.has(choice.label_key), choice.label_key)


func test_huge_planet_is_playable() -> void:
	var cfg := _config()
	cfg["planet"]["frequency"] = 20
	var sim := Simulation.new(2, cfg)
	assert_eq(sim.planet.cell_count(), 4002)
	assert_true(sim.economy.village_center >= 0)
	sim.run_ticks(sim.ticks_per_day)
	assert_eq(sim.day(), 2)


func test_tutorial_buildings_are_affordable_at_start() -> void:
	# The tutorial asks for a well, a gatherer and a hut with the starting stocks.
	var sim := _sim()
	var eco := sim.economy
	var total := {}
	for id in ["well", "gatherer", "hut"]:
		var cost: Dictionary = eco.defs[id].cost
		for res in cost:
			total[res] = float(total.get(res, 0.0)) + float(cost[res])
	for res in total:
		assert_true(eco.stock(res) >= total[res], "%s: need %d, have %d" % [res, total[res], eco.stock(res)])
```


### FICHIER : tests/unit/test_fixed_stepper.gd

```gdscript
extends "res://tests/test_case.gd"

const FixedStepper := preload("res://scripts/simulation/fixed_stepper.gd")


func test_paused_produces_no_ticks() -> void:
	var s := FixedStepper.new(10.0, 40)
	assert_eq(s.advance(1.0, 0), 0)


func test_accumulates_partial_frames() -> void:
	var s := FixedStepper.new(10.0, 40)
	assert_eq(s.advance(0.05, 1), 0)
	assert_eq(s.advance(0.05, 1), 1)
	assert_almost_eq(s.interpolation_alpha(), 0.0, 1e-4)


func test_speed_multiplies_ticks() -> void:
	var s := FixedStepper.new(10.0, 40)
	assert_eq(s.advance(1.0, 4), 40)


func test_frame_rate_independent() -> void:
	# 1 second at 60 FPS and at 30 FPS must give the same number of ticks.
	var a := FixedStepper.new(10.0, 40)
	var b := FixedStepper.new(10.0, 40)
	var ta := 0
	var tb := 0
	for i in 60:
		ta += a.advance(1.0 / 60.0, 1)
	for i in 30:
		tb += b.advance(1.0 / 30.0, 1)
	assert_true(absi(ta - tb) <= 1, "60fps=%d 30fps=%d" % [ta, tb])
	assert_true(ta >= 9 and ta <= 10)


func test_long_frame_is_capped() -> void:
	var s := FixedStepper.new(10.0, 40)
	assert_eq(s.advance(3600.0, 1), 40)
	assert_eq(s.advance(0.0, 1), 0, "excess time must be dropped")
```


### FICHIER : tests/unit/test_hex_grid.gd

```gdscript
extends "res://tests/test_case.gd"

const HexGrid := preload("res://scripts/simulation/hex_grid.gd")


func test_cell_count_matches_formula() -> void:
	for f in [1, 2, 6, 8]:
		var grid := HexGrid.new(f)
		assert_eq(grid.cell_count(), HexGrid.cell_count_for(f), "frequency %d" % f)
	assert_eq(HexGrid.cell_count_for(6), 362)


func test_exactly_twelve_pentagons() -> void:
	var grid := HexGrid.new(6)
	var pentagons := 0
	var hexagons := 0
	for i in grid.cell_count():
		match grid.neighbors[i].size():
			5: pentagons += 1
			6: hexagons += 1
	assert_eq(pentagons, 12)
	assert_eq(hexagons, grid.cell_count() - 12)


func test_neighbors_are_symmetric() -> void:
	var grid := HexGrid.new(6)
	for i in grid.cell_count():
		for nb in grid.neighbors[i]:
			assert_true(i in grid.neighbors[nb], "%d <-> %d" % [i, nb])


func test_corners_match_neighbors() -> void:
	var grid := HexGrid.new(6)
	for i in grid.cell_count():
		assert_eq(grid.corners[i].size(), grid.neighbors[i].size(), "cell %d" % i)


func test_centers_are_unit_vectors() -> void:
	var grid := HexGrid.new(6)
	for c in grid.centers:
		assert_almost_eq(c.length(), 1.0, 1e-4)


func test_find_cell_returns_own_cell() -> void:
	var grid := HexGrid.new(6)
	for i in grid.cell_count():
		assert_eq(grid.find_cell(grid.centers[i] * 1.05), i)


func test_corners_are_counter_clockwise() -> void:
	# Seen from outside, consecutive corners turn around the outward normal.
	var grid := HexGrid.new(6)
	for i in [0, 17, 100, 361]:
		var c: Vector3 = grid.centers[i]
		var cs: PackedVector3Array = grid.corners[i]
		for k in cs.size():
			var turn := (cs[k] - c).cross(cs[(k + 1) % cs.size()] - c).dot(c)
			assert_true(turn > 0.0, "cell %d corner %d" % [i, k])
```


### FICHIER : tests/unit/test_needs.gd

```gdscript
extends "res://tests/test_case.gd"

const Simulation := preload("res://scripts/simulation/simulation.gd")
const Economy := preload("res://scripts/simulation/economy.gd")


func _json(path: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(path))


func _sim(world_seed: int = 7) -> Simulation:
	var config := _json("res://data/game_config.json")
	config["terrains"] = _json("res://data/terrains.json").terrains
	var buildings := _json("res://data/buildings.json")
	config["buildings"] = buildings.buildings
	config["start"] = buildings.start
	var sim := Simulation.new(world_seed, config)
	sim.economy.stocks["wood"] = 500.0
	sim.economy.stocks["stone"] = 500.0
	sim.economy.population = 30  # Enough workers for every test.
	for p in ["water_carrier", "gatherer", "woodcutter", "stonecutter", "farmer", "miller", "baker", "artisan", "healer"]:
		sim.economy.trained[p] = 3
	return sim


## Places a building on the first free cell that accepts it (ignores territory).
func _place(sim: Simulation, id: String) -> int:
	var eco := sim.economy
	for i in sim.planet.cell_count():
		if sim.planet.buildings[i] == "" and sim.planet.terrain[i] in eco.defs[id].terrains:
			sim.planet.buildings[i] = id
			eco._rebuild_caches()
			return i
	return -1


func test_new_village_has_water() -> void:
	var sim := _sim()
	assert_true(sim.economy.stock("water") > 0.0)


func test_people_drink_water() -> void:
	var sim := _sim()
	var eco := sim.economy
	var water := eco.stock("water")
	eco.update(0.5)
	assert_almost_eq(eco.stock("water"), water - eco.population * 0.5, 0.01)


func test_well_produces_water() -> void:
	var sim := _sim()
	var cell := _place(sim, "well")
	sim.economy.update(1.0)
	assert_true(float(sim.economy.building_rate(cell).get("water", 0.0)) >= 4.0)


func test_well_is_better_near_water() -> void:
	var sim := _sim()
	var eco := sim.economy
	var near := -1
	var far := -1
	for i in sim.planet.cell_count():
		if sim.planet.buildings[i] != "" or not (sim.planet.terrain[i] in eco.defs.well.terrains):
			continue
		if near < 0 and eco.near_water(i):
			near = i
		elif far < 0 and not eco.near_water(i):
			far = i
	sim.planet.buildings[near] = "well"
	sim.planet.buildings[far] = "well"
	eco._rebuild_caches()
	eco.update(1.0)
	assert_almost_eq(float(eco.building_rate(near).water), float(eco.building_rate(far).water) * 1.5, 0.01)


func test_bread_chain_turns_grain_into_food() -> void:
	var sim := _sim()
	var eco := sim.economy
	var mill := _place(sim, "mill")
	var bakery := _place(sim, "bakery")
	eco.stocks["grain"] = 100.0
	eco.update(0.5)
	assert_true(eco.stock("flour") > 0.0 or float(eco.building_rate(bakery).get("food", 0.0)) > 0.0, "flour made")
	assert_true(eco.stock("grain") < 100.0, "grain used")
	eco.update(0.5)
	assert_true(float(eco.building_rate(bakery).get("food", 0.0)) > 10.0, "bread baked: %s" % str(eco.building_rate(bakery)))
	assert_true(float(eco.building_inputs(mill).get("grain", 0.0)) > 0.0)


func test_converter_waits_without_input() -> void:
	var sim := _sim()
	var eco := sim.economy
	var mill := _place(sim, "mill")
	eco.stocks["grain"] = 0.0
	eco.update(1.0)
	assert_true(eco.is_waiting(mill))
	assert_almost_eq(eco.stock("flour"), 0.0)


func test_tools_boost_production() -> void:
	var sim := _sim()
	var eco := sim.economy
	var cell := _place(sim, "gatherer")
	eco.stocks["tools"] = 0.0
	eco.update(1.0)
	var without := float(eco.building_rate(cell).food)
	eco.stocks["tools"] = 10.0
	eco.update(1.0)
	var with_tools := float(eco.building_rate(cell).food)
	assert_almost_eq(with_tools, without * 1.25, 0.01)
	assert_true(eco.stock("tools") < 10.0, "tools wear out")


func test_happiness_sets_productivity() -> void:
	var sim := _sim()
	var eco := sim.economy
	eco.happiness = 0.0
	assert_almost_eq(eco.productivity(), 0.6)
	eco.happiness = 100.0
	assert_almost_eq(eco.productivity(), 1.2)


func test_leisure_raises_happiness() -> void:
	var sim := _sim()
	var eco := sim.economy
	var before := Economy.target_of(eco.happiness_factors())
	_place(sim, "stone_circle")
	assert_almost_eq(Economy.target_of(eco.happiness_factors()), before + 10.0, 0.01)


func test_thirst_hurts_health_and_kills() -> void:
	var sim := _sim()
	var eco := sim.economy
	eco.population = 4
	eco.stocks["food"] = 100.0
	eco.stocks["water"] = 0.0
	var health := eco.health
	eco.daily_update()
	assert_true(eco.health < health, "health drops without water")
	assert_eq(eco.population, 3)


func test_healer_improves_health() -> void:
	var sim := _sim()
	var eco := sim.economy
	var before := Economy.target_of(eco.health_factors())
	_place(sim, "healer")
	eco.update(0.01)
	assert_true(Economy.target_of(eco.health_factors()) > before)


func test_no_births_when_unhappy() -> void:
	var sim := _sim()
	var eco := sim.economy
	eco.population = 2
	eco.stocks["food"] = 100.0
	eco.stocks["water"] = 100.0
	eco.happiness = 25.0
	eco.daily_update()
	assert_true(eco.population <= 2)


func test_wellbeing_survives_save() -> void:
	var sim := _sim()
	sim.economy.happiness = 73.5
	sim.economy.health = 41.25
	sim.economy.stocks["flour"] = 12.0
	var loaded := Simulation.new(1, {"terrains": sim.terrain_defs, "buildings": sim.building_defs, "start": sim.start_settings, "economy": sim.economy_settings, "planet": sim.planet_settings})
	loaded.from_dict(JSON.parse_string(JSON.stringify(sim.to_dict())))
	assert_almost_eq(loaded.economy.happiness, 73.5, 0.01)
	assert_almost_eq(loaded.economy.health, 41.25, 0.01)
	assert_almost_eq(loaded.economy.stock("flour"), 12.0, 0.01)


func test_phase2_save_gets_water() -> void:
	var sim := _sim()
	var data := sim.to_dict()
	data.economy.stocks.erase("water")
	data.economy.erase("happiness")
	var loaded := Simulation.new(1, {"terrains": sim.terrain_defs, "buildings": sim.building_defs, "start": sim.start_settings, "economy": sim.economy_settings, "planet": sim.planet_settings})
	loaded.from_dict(JSON.parse_string(JSON.stringify(data)))
	assert_almost_eq(loaded.economy.stock("water"), 40.0)
	assert_true(loaded.economy.happiness > 0.0)


func test_every_building_has_a_known_category() -> void:
	var file := _json("res://data/buildings.json")
	var ids := []
	for cat in file.categories:
		ids.append(cat.id)
	for id in file.buildings:
		assert_true(file.buildings[id].get("category", "") in ids, "category of " + id)
```


### FICHIER : tests/unit/test_planet.gd

```gdscript
extends "res://tests/test_case.gd"

const PlanetState := preload("res://scripts/simulation/planet_state.gd")
const Simulation := preload("res://scripts/simulation/simulation.gd")


func _terrains() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://data/terrains.json")).terrains


func _settings() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://data/game_config.json")).planet


func _planet(world_seed: int) -> PlanetState:
	var p := PlanetState.new(int(_settings().frequency))
	p.generate(world_seed, _terrains(), _settings())
	return p


func test_same_seed_same_planet() -> void:
	var a := _planet(1234)
	var b := _planet(1234)
	assert_eq(a.terrain, b.terrain)
	assert_eq(a.fertility, b.fertility)
	assert_eq(a.resources, b.resources)


func test_different_seeds_differ() -> void:
	assert_true(_planet(1).terrain != _planet(2).terrain)


func test_every_terrain_is_defined() -> void:
	var defs := _terrains()
	var p := _planet(77)
	for t in p.terrain:
		assert_true(defs.has(t), "unknown terrain " + t)


func test_ocean_share_is_reasonable() -> void:
	for s in [1, 2, 3, 4, 5]:
		var p := _planet(s)
		var water := p.count_terrain("ocean") + p.count_terrain("shallow")
		var share := float(water) / p.cell_count()
		assert_true(share > 0.35 and share < 0.65, "seed %d water share %f" % [s, share])


func test_varied_land() -> void:
	# Every planet should offer the basics of the stone age.
	for s in [10, 20, 30]:
		var p := _planet(s)
		assert_true(p.count_terrain("plains") > 0, "seed %d has no plains" % s)
		assert_true(p.count_terrain("forest") + p.count_terrain("hills") + p.count_terrain("mountain") > 0)


func test_poles_are_icy() -> void:
	var p := _planet(5)
	var pole := p.grid.find_cell(Vector3.UP)
	assert_eq(p.terrain[pole], "ice")


func test_forests_have_wood() -> void:
	var p := _planet(9)
	for i in p.cell_count():
		if p.terrain[i] == "forest":
			assert_true(p.resources[i].has("wood"), "forest %d without wood" % i)


func test_planet_survives_save_roundtrip() -> void:
	var config := {"terrains": _terrains(), "planet": _settings()}
	var a := Simulation.new(4242, config)
	a.planet.resources[3]["wood"] = 1  # A change that regeneration would not reproduce.
	var json := JSON.stringify(a.to_dict())
	var b := Simulation.new(1, config)
	b.from_dict(JSON.parse_string(json))
	assert_eq(b.planet.terrain, a.planet.terrain)
	assert_eq(int(b.planet.resources[3]["wood"]), 1)


func test_old_save_without_planet_is_generated() -> void:
	var config := {"terrains": _terrains(), "planet": _settings()}
	var sim := Simulation.new(1, config)
	sim.from_dict({"world_seed": 99, "tick": 5})
	var f := int(_settings().frequency)
	assert_eq(sim.planet.cell_count(), 10 * f * f + 2)
	assert_eq(sim.planet.terrain, _planet(99).terrain)
```


### FICHIER : tests/unit/test_save_manager.gd

```gdscript
extends "res://tests/test_case.gd"

const SaveManager := preload("res://scripts/core/save_manager.gd")


func test_current_version_loads_unchanged() -> void:
	var env := SaveManager.build_envelope({"tick": 10, "world_seed": 3}, 1000.0)
	var result := SaveManager.parse_and_migrate(JSON.stringify(env))
	assert_eq(result.status, SaveManager.LoadStatus.OK)
	assert_eq(int(result.envelope.version), SaveManager.SAVE_VERSION)
	assert_eq(int(result.envelope.game.tick), 10)


func test_migrates_v0_prototype_save() -> void:
	var result := SaveManager.parse_and_migrate('{"ticks": 500, "seed": 9}')
	assert_eq(result.status, SaveManager.LoadStatus.OK)
	assert_eq(int(result.envelope.version), SaveManager.SAVE_VERSION)
	assert_eq(int(result.envelope.game.tick), 500)
	assert_eq(int(result.envelope.game.world_seed), 9)


func test_corrupted_save_is_detected() -> void:
	var result := SaveManager.parse_and_migrate("{not json")
	assert_eq(result.status, SaveManager.LoadStatus.CORRUPTED)


func test_newer_save_is_not_migrated() -> void:
	var result := SaveManager.parse_and_migrate('{"version": 999, "game": {}}')
	assert_eq(result.status, SaveManager.LoadStatus.TOO_NEW)


func test_file_roundtrip() -> void:
	var path := "user://test_save.json"
	assert_eq(SaveManager.save_to_file({"tick": 42}, path), OK)
	var result := SaveManager.load_from_file(path)
	assert_eq(result.status, SaveManager.LoadStatus.OK)
	assert_eq(int(result.envelope.game.tick), 42)
	DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(path + ".bak")


func test_game_data_files_are_valid_json() -> void:
	for path in ["res://data/game_config.json", "res://data/locale/fr.json", "res://data/locale/en.json"]:
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
		assert_eq(typeof(parsed), TYPE_DICTIONARY, path)


func test_locales_have_same_keys() -> void:
	var fr: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/locale/fr.json"))
	var en: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/locale/en.json"))
	for key in fr:
		assert_true(en.has(key), "EN missing key " + key)
	for key in en:
		assert_true(fr.has(key), "FR missing key " + key)
```


### FICHIER : tests/unit/test_simulation.gd

```gdscript
extends "res://tests/test_case.gd"

const Simulation := preload("res://scripts/simulation/simulation.gd")

const CONFIG := {"ticks_per_day": 100, "allowed_speeds": [0, 1, 2, 4]}


func test_starts_on_day_one() -> void:
	var sim := Simulation.new(42, CONFIG)
	assert_eq(sim.day(), 1)
	assert_almost_eq(sim.time_of_day(), 0.0)


func test_days_advance_with_ticks() -> void:
	var sim := Simulation.new(42, CONFIG)
	sim.run_ticks(250)
	assert_eq(sim.day(), 3)
	assert_almost_eq(sim.time_of_day(), 0.5)


func test_day_passed_signal() -> void:
	var sim := Simulation.new(42, CONFIG)
	var days: Array = []
	sim.day_passed.connect(func(d): days.append(d))
	sim.run_ticks(300)
	assert_eq(days, [2, 3, 4])


func test_only_allowed_speeds() -> void:
	var sim := Simulation.new(42, CONFIG)
	assert_true(sim.set_speed(4))
	assert_false(sim.set_speed(3))
	assert_eq(sim.speed, 4)


func test_save_roundtrip_is_deterministic() -> void:
	var a := Simulation.new(1234, CONFIG)
	a.run_ticks(77)
	a.rng.randi()  # Advance the RNG so its state matters.
	var json := JSON.stringify(a.to_dict())
	var b := Simulation.new(0, CONFIG)
	b.from_dict(JSON.parse_string(json))
	assert_eq(b.tick, 77)
	assert_eq(b.world_seed, 1234)
	assert_eq(b.rng.randi(), a.rng.randi(), "RNG must continue identically")


func test_offline_progress_is_capped() -> void:
	var sim := Simulation.new(1, CONFIG)
	# 100 hours away, cap 8 h, efficiency 0.5, 10 ticks/s -> 8*3600*0.5*10 ticks.
	var ticks := sim.advance_offline(100 * 3600.0, 10.0, 8 * 3600.0, 0.5)
	assert_eq(ticks, 144000)
	assert_eq(sim.tick, 144000)


func test_invalid_saved_speed_falls_back() -> void:
	var sim := Simulation.new(1, CONFIG)
	sim.from_dict({"world_seed": 1, "tick": 5, "speed": 99})
	assert_eq(sim.speed, 1)
```


### FICHIER : tests/unit/test_townhall.gd

```gdscript
extends "res://tests/test_case.gd"

const Simulation := preload("res://scripts/simulation/simulation.gd")
const Economy := preload("res://scripts/simulation/economy.gd")


func _json(path: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(path))


func _config() -> Dictionary:
	var config := _json("res://data/game_config.json")
	config["terrains"] = _json("res://data/terrains.json").terrains
	var buildings := _json("res://data/buildings.json")
	config["buildings"] = buildings.buildings
	config["start"] = buildings.start
	config["townhall"] = _json("res://data/townhall.json").levels
	config["professions"] = _json("res://data/professions.json").professions
	config["objectives"] = _json("res://data/objectives.json").objectives
	return config


func _sim(world_seed: int = 7) -> Simulation:
	return Simulation.new(world_seed, _config())


func _spot(sim: Simulation, id: String) -> int:
	for i in sim.planet.cell_count():
		if sim.economy.can_build(i, id) == "":
			return i
	return -1


func _rich(sim: Simulation) -> void:
	for res in ["food", "wood", "stone", "tools", "water"]:
		sim.economy.stocks[res] = 1000.0


func test_village_starts_with_the_town_hall_only() -> void:
	var sim := _sim()
	var eco := sim.economy
	assert_eq(eco.townhall_level, 1)
	assert_eq(sim.planet.buildings[eco.village_center], "townhall")
	assert_eq(eco.housing(), 4)
	assert_eq(eco.trained_total(), 0)
	assert_eq(eco.idle_villagers(), 4)


func test_buildings_are_locked_by_level() -> void:
	var sim := _sim()
	_rich(sim)
	var eco := sim.economy
	assert_eq(eco.building_limit("mill"), 0)
	var land := sim.planet.terrain.find("plains")
	assert_eq(eco.can_build(land, "mill"), Economy.ERR_LOCKED)
	assert_eq(eco.unlock_level("mill"), 3)
	assert_true(eco.building_limit("hut") > 0)


func test_building_limit_per_level() -> void:
	var sim := _sim()
	_rich(sim)
	var eco := sim.economy
	var limit := eco.building_limit("well")
	for i in limit:
		var cell := _spot(sim, "well")
		assert_true(eco.build(cell, "well"), "well %d" % i)
		eco.complete_construction()
	var any := -1
	for i in sim.planet.cell_count():
		if sim.planet.buildings[i] == "" and eco.in_territory(i) and sim.planet.terrain[i] == "plains":
			any = i
			break
	assert_eq(eco.can_build(any, "well"), Economy.ERR_LIMIT)


func test_construction_takes_time_and_builders() -> void:
	var sim := _sim()
	_rich(sim)
	var eco := sim.economy
	var cell := _spot(sim, "hut")
	assert_true(eco.build(cell, "hut"))
	assert_false(eco.is_active(cell))
	assert_eq(eco.housing(), 4, "a site gives no housing")
	assert_eq(eco.free_builders(), 0)
	assert_eq(eco.can_build(_spot_any(sim, "hut"), "hut"), Economy.ERR_BUILDERS)
	sim.run_ticks(int(sim.ticks_per_day * 0.35))
	assert_true(eco.is_active(cell), "hut built after 0.3 day")
	assert_eq(eco.housing(), 8)
	assert_eq(eco.free_builders(), 1)


func _spot_any(sim: Simulation, id: String) -> int:
	for i in sim.planet.cell_count():
		if sim.planet.buildings[i] == "" and sim.economy.in_territory(i) and sim.planet.terrain[i] in sim.economy.defs[id].terrains:
			return i
	return -1


func test_workers_must_be_trained() -> void:
	var sim := _sim()
	_rich(sim)
	var eco := sim.economy
	var cell := _spot(sim, "gatherer")
	eco.build(cell, "gatherer")
	eco.complete_construction()
	eco.update(0.1)
	assert_eq(eco.workers_at(cell), 0, "untrained villagers can't work")
	assert_true(eco.train("gatherer"))
	assert_eq(eco.idle_villagers(), 3)
	sim.run_ticks(int(sim.ticks_per_day * 0.25))
	assert_eq(eco.trained_count("gatherer"), 1)
	eco.update(0.1)
	assert_eq(eco.workers_at(cell), 1)


func test_training_costs_food_and_respects_slots() -> void:
	var sim := _sim()
	var eco := sim.economy
	var food := eco.stock("food")
	assert_eq(eco.can_train("gatherer"), "")
	eco.train("gatherer")
	assert_almost_eq(eco.stock("food"), food - 4.0)
	assert_eq(eco.can_train("gatherer"), Economy.ERR_SLOTS, "1 training at a time at level 1")
	assert_eq(eco.can_train("miller"), Economy.ERR_LOCKED)


func test_no_training_without_idle_villagers() -> void:
	var sim := _sim()
	var eco := sim.economy
	eco.trained["gatherer"] = 4
	assert_eq(eco.can_train("woodcutter"), Economy.ERR_NO_VILLAGER)


func test_townhall_upgrade_needs_population_and_time() -> void:
	var sim := _sim()
	_rich(sim)
	var eco := sim.economy
	assert_eq(eco.can_upgrade_townhall(), Economy.ERR_REQUIREMENT)
	eco.population = 6
	assert_eq(eco.can_upgrade_townhall(), "")
	assert_true(eco.upgrade_townhall())
	assert_eq(eco.townhall_level, 1, "works take time")
	assert_eq(eco.can_upgrade_townhall(), Economy.ERR_BUSY)
	var levels := []
	eco.level_up.connect(func(l): levels.append(l))
	eco.update(1.01)
	assert_eq(eco.townhall_level, 2)
	assert_eq(levels, [2])
	assert_true(eco.building_limit("field") > 0, "fields unlocked at level 2")


func test_level_up_grows_territory_and_housing() -> void:
	var sim := _sim()
	_rich(sim)
	var eco := sim.economy
	var area := _territory_size(sim)
	var housing := eco.housing()
	eco.population = 6
	eco.upgrade_townhall()
	eco.update(2.0)
	assert_true(_territory_size(sim) > area, "territory grows")
	assert_true(eco.housing() > housing, "town hall houses more")


func _territory_size(sim: Simulation) -> int:
	var n := 0
	for i in sim.planet.cell_count():
		if sim.economy.in_territory(i):
			n += 1
	return n


func test_perks_boost_production() -> void:
	var sim := _sim()
	_rich(sim)
	var eco := sim.economy
	var cell := _spot(sim, "gatherer")
	eco.build(cell, "gatherer")
	eco.complete_construction()
	eco.trained["gatherer"] = 2
	eco.update(0.5)
	var before := float(eco.building_rate(cell).food)
	eco.townhall_level = 2  # "Cueillette experte": +10 % food
	eco.update(0.5)
	assert_almost_eq(float(eco.building_rate(cell).food), before * 1.1, 0.01)


func test_people_leaving_lose_their_job() -> void:
	var sim := _sim()
	var eco := sim.economy
	eco.trained = {"gatherer": 2, "woodcutter": 2}
	eco.stocks["food"] = 0.0
	eco.daily_update()  # Famine: one person dies.
	assert_eq(eco.population, 3)
	assert_eq(eco.trained_total(), 3)


func test_progress_survives_save() -> void:
	var sim := _sim()
	_rich(sim)
	var eco := sim.economy
	var cell := _spot(sim, "hut")
	eco.build(cell, "hut")
	eco.train("gatherer")
	eco.trained["water_carrier"] = 1
	eco.population = 6
	var loaded := _sim(1)
	loaded.from_dict(JSON.parse_string(JSON.stringify(sim.to_dict())))
	var e2 := loaded.economy
	assert_false(e2.is_active(cell), "still a construction site")
	assert_almost_eq(e2.construction_progress(cell), eco.construction_progress(cell), 0.01)
	assert_eq(e2.training.size(), 1)
	assert_eq(e2.trained_count("water_carrier"), 1)
	assert_eq(e2.townhall_level, 1)


func test_old_village_becomes_a_town_hall() -> void:
	var sim := _sim()
	var eco := sim.economy
	# Build a save shaped like Phase 3: campfire center, working gatherer, no town hall data.
	sim.planet.buildings[eco.village_center] = "campfire"
	var spot := -1
	for i in sim.planet.cell_count():
		if sim.planet.buildings[i] == "" and sim.planet.terrain[i] == "plains":
			spot = i
			break
	sim.planet.buildings[spot] = "gatherer"
	var data := sim.to_dict()
	for key in ["townhall_level", "townhall_upgrade_left", "trained", "training", "construction"]:
		data.economy.erase(key)
	var loaded := _sim(1)
	loaded.from_dict(JSON.parse_string(JSON.stringify(data)))
	var e2 := loaded.economy
	assert_eq(loaded.planet.buildings[e2.village_center], "townhall")
	assert_eq(e2.townhall_level, 1)
	assert_eq(e2.trained_count("gatherer"), 2, "existing workers are trained")
	e2.update(0.1)
	assert_eq(e2.workers_at(spot), 2)


func test_outposts_expand_territory() -> void:
	var sim := _sim()
	_rich(sim)
	var eco := sim.economy
	eco.townhall_level = 3
	eco._rebuild_caches()
	var area := _territory_size(sim)
	var edge := -1
	for i in sim.planet.cell_count():
		if eco.can_build(i, "outpost") == "":
			var outside := 0
			for nb in sim.planet.grid.neighbors[i]:
				if not eco.in_territory(nb):
					outside += 1
			if outside >= 2:
				edge = i
				break
	assert_true(edge >= 0, "an edge cell for an outpost")
	eco.build(edge, "outpost")
	eco.complete_construction()
	assert_true(_territory_size(sim) > area)


func test_every_level_is_reachable() -> void:
	# Each level's upgrade only costs resources that earlier levels can produce.
	var levels: Array = _json("res://data/townhall.json").levels
	var producers := {"food": ["gatherer", "field", "bakery"], "wood": ["woodcutter"], "stone": ["quarry"], "tools": ["workshop"]}
	for i in range(1, levels.size()):
		var available: Dictionary = levels[i - 1].buildings
		for res in levels[i].get("cost", {}):
			var ok := false
			for b in producers.get(res, []):
				if int(available.get(b, 0)) > 0:
					ok = true
			assert_true(ok, "level %d needs %s but nothing produces it" % [i + 1, res])


func test_professions_have_texts_and_buildings() -> void:
	var fr := _json("res://data/locale/fr.json")
	var professions: Dictionary = _json("res://data/professions.json").professions
	var buildings: Dictionary = _json("res://data/buildings.json").buildings
	for id in professions:
		assert_true(fr.has(professions[id].name_key), id)
	for id in buildings:
		var p := str(buildings[id].get("profession", ""))
		if p != "":
			assert_true(professions.has(p), "%s needs unknown profession %s" % [id, p])
	for level in _json("res://data/townhall.json").levels:
		for perk in level.get("perks", []):
			assert_true(fr.has(perk.name_key), perk.name_key)
```
