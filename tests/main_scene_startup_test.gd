extends SceneTree
## Start the real main scene headlessly, then shut down its streaming audio
## and nodes cleanly. Unlike --quit-after, this gives the audio driver frames
## to release its MP3 playback resources before the engine exits.

const MainScene = preload("res://scenes/main.tscn")
var failures: int = 0

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var game: Control = MainScene.instantiate() as Control
    if game == null:
        push_error("FAIL: main scene could not instantiate")
        quit(1)
        return
    root.add_child(game)
    for _frame in range(10):
        await process_frame
    if str(game.get("screen")) != "home":
        failures += 1
        push_error("FAIL: startup did not open Main Menu")
    var music: AudioStreamPlayer = game.get_node_or_null("BackgroundMusic") as AudioStreamPlayer
    if music == null or music.stream == null:
        failures += 1
        push_error("FAIL: main menu background music was not initialized")
    # Exercise the real _exit_tree() cleanup and wait for audio shutdown.
    game.queue_free()
    for _frame in range(8):
        await process_frame
    game = null
    if failures == 0:
        print("PASS: main scene starts and releases its audio on exit")
    quit(1 if failures > 0 else 0)
