def pbGenerateOverworldEncounters
  return if $scene.is_a?(Scene_Intro) || $scene.is_a?(Scene_DebugIntro)
  return if !$PokemonEncounters
  return if $player.able_pokemon_count == 0
  return if $PokemonGlobal.surfing
  if VoltseonsOverworldEncounters.current_encounters < VoltseonsOverworldEncounters.get_max
    tile = get_grass_tile
    return if tile == []
    
    enc_type = $PokemonEncounters.encounter_type
    enc_type = $PokemonEncounters.find_valid_encounter_type_for_time(:Land, pbGetTimeNow) if enc_type.nil?
    return if enc_type.nil?

    pkmn = $PokemonEncounters.choose_wild_pokemon_for_map($game_map.map_id, enc_type)
    pkmn = Pokemon.new(pkmn[0],pkmn[1])

    echoln "Spawning #{pkmn.name}" if VoltseonsOverworldEncounters::LOG_SPAWNS

    pkmn.level = (pkmn.level + rand(-2..2)).clamp(2,GameData::GrowthRate.max_level)
    pkmn.calc_stats
    pkmn.reset_moves
    pkmn.shiny = rand(VoltseonsOverworldEncounters::SHINY_RATE) == 1

    # create event
    r_event = Rf.create_event do |e|
      e.name = "OverworldPkmn"
      e.x = tile[0]
      e.y = tile[1]
      e.pages[0].step_anime = true
      e.pages[0].trigger = 0
      e.pages[0].list.clear
      e.pages[0].move_speed = 2
      e.pages[0].move_frequency = 2
      Compiler.push_script(e.pages[0].list, "pbInteractOverworldEncounter")
      Compiler.push_end(e.pages[0].list)
    end
    event = r_event[:event]
    event.setVariable([pkmn, r_event])
    spriteset = $scene.spriteset($game_map.map_id)
    dist = (((event.x - $game_player.x).abs + (event.y - $game_player.y).abs) / 4).floor
    if pkmn.shiny?
      pbSEPlay(VoltseonsOverworldEncounters::SHINY_SOUND, [75, 65, 55, 40, 27, 22, 15][dist], 100) if dist <= 6 && dist >= 0
      spriteset&.addUserAnimation(VoltseonsOverworldEncounters::SHINY_ANIMATION, event.x, event.y, true, 1)
    end
    pbChangeEventSprite(event,pkmn)
    event.direction = rand(1..4) * 2
    event.through = false
    spriteset&.addUserAnimation(VoltseonsOverworldEncounters::SPAWN_ANIMATION, event.x, event.y, true, 1)
    GameData::Species.play_cry_from_pokemon(pkmn, [75, 65, 55, 40, 27, 22, 15][dist]) if dist <= 6 && dist >= 0 && rand(20) == 1
    VoltseonsOverworldEncounters.current_encounters += 1
  end
end

EventHandlers.add(:on_enter_map, :clear_previous_overworld_encounters,
  proc { |old_map_id|
    #echoln ">> Entered at Proc Clear Previous Overworld Encounter"

    #echoln "*before* next if $game_map.map_id < 2"
    next if $game_map.map_id < 2

    #echoln "*before* next if old_map_id.nil? || old_map_id < 2"
    next if old_map_id.nil? || old_map_id < 2

    #echoln "*before* next unless $MapFactory"
    next unless $map_factory # < Changed from $MapFactory to $map_factory
    
    # Add Old Map to Variable
    #echoln "*before* map = $MapFactory.getMapNoAdd(old_map_id)"
    map = $map_factory.getMapNoAdd(old_map_id) # < Changed from $MapFactory to $map_factory
    
    #echoln "> Destroying Spawns from #{map.name} <" # <<< THOSE

    map.events.each_value do |event|
      next unless event.name[/OverworldPkmn/i]
      pbDestroyOverworldEncounter(event, true, false)
    end
    VoltseonsOverworldEncounters.current_encounters = 0

    #echoln "## Entered at #{$game_map.name} ##" # <<< THOSE
    
    pbGenerateOverworldEncounters
  }
)

EventHandlers.add(:on_new_spriteset_map, :fix_exisitng_overworld_encounters,
  proc {
    next if $game_map.map_id < 2
    next if !$PokemonEncounters
    $game_map.events.each_value do |event|
      next unless event.name[/OverworldPkmn/i]
      next if event.variable.nil?
      pkmn = event.variable[0]
      next if pkmn.nil?
      pbChangeEventSprite(event,pkmn)
    end
  }
)

EventHandlers.add(:on_frame_update, :move_overworld_encounters,
  proc {
    next if $game_map.map_id < 2
    next if VoltseonsOverworldEncounters::DISABLE_SETTINGS && $PokemonSystem.owpkmnenabled==1
    next if $game_temp.in_menu
    next if !$PokemonEncounters
    $game_temp.frames_updated += 1
    next if $game_temp.frames_updated < 600 # <<< Updated Frame Rate
    $game_temp.frames_updated = 0
    $game_map.events.each_value do |event|
      next unless event.name[/OverworldPkmn/i]
      next if event.variable.nil?
      pbPokemonIdle(event)
    end
    pbGenerateOverworldEncounters
  }
)

EventHandlers.add(:on_step_taken, :despawn_on_trainer,
  proc { |event|
    next if $game_map.map_id < 2
    next if !$scene.is_a?(Scene_Map)
    next if VoltseonsOverworldEncounters::DISABLE_SETTINGS && $PokemonSystem.owpkmnenabled==1
    next if $game_temp.in_menu
    next if !$PokemonEncounters
    $game_map.events.each_value do |event|
      next unless event.name[/OverworldPkmn/i]
      next if event.variable.nil?
      pbDestroyOverworldEncounter(event) if pbTrainersSeePkmn(event)
    end
  }
)