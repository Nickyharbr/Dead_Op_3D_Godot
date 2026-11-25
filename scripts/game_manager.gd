extends Node

var active_zombies: int = 0
var total_kills: int = 0
var lives: int = 3
var player_down: bool = false
var score: int = 0

func add_score(amount: int):
	score += amount
	
