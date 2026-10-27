extends Node3D
## Entry point: builds the world, the UI and the story director, then shows
## the title screen. Everything is assembled in code from small reusable
## pieces (see scripts/world, scripts/ui, scripts/story).

var world: World
var ui: UIRoot
var story: StoryDirector


func _ready() -> void:
	randomize()
	Loc.set_language(Loc.language)
	world = World.new()
	world.name = "World"
	add_child(world)
	world.setup(UIKit.font(800))
	ui = UIRoot.new()
	ui.name = "UIRoot"
	add_child(ui)
	ui.build(world, world.defs)
	story = StoryDirector.new()
	story.name = "Story"
	add_child(story)
	story.setup(world, ui)
	story.show_title()
