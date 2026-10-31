#########################################################
###                 Encounter list UI                 ###
### Based on the original resource by raZ and friends ###
#########################################################

#-------------------------------------------------------------------------------
# Configuration
#-------------------------------------------------------------------------------

WINDOWSKIN = "base.png"

USER_DEFINED_NAMES = {
  :Land           => "Grass",
  :LandDay        => "Grass (day)",
  :LandNight      => "Grass (night)",
  :LandMorning    => "Grass (morning)",
  :LandAfternoon  => "Grass (afternoon)",
  :LandEvening    => "Grass (evening)",
  :PokeRadar      => "Poké Radar",
  :Cave           => "Cave",
  :CaveDay        => "Cave (day)",
  :CaveNight      => "Cave (night)",
  :CaveMorning    => "Cave (morning)",
  :CaveAfternoon  => "Cave (afternoon)",
  :CaveEvening    => "Cave (evening)",
  :Water          => "Surfing",
  :WaterDay       => "Surfing (day)",
  :WaterNight     => "Surfing (night)",
  :WaterMorning   => "Surfing (morning)",
  :WaterAfternoon => "Surfing (afternoon)",
  :WaterEvening   => "Surfing (evening)",
  :OldRod         => "Fishing (Old Rod)",
  :GoodRod        => "Fishing (Good Rod)",
  :SuperRod       => "Fishing (Super Rod)",
  :RockSmash      => "Rock Smash",
  :HeadbuttLow    => "Headbutt (rare)",
  :HeadbuttHigh   => "Headbutt (common)",
  :BugContest     => "Bug Contest"
}

# Uncomment to use the default encounter type names.
# USER_DEFINED_NAMES = nil

#-------------------------------------------------------------------------------
# Encounter rarity settings
#-------------------------------------------------------------------------------

ENCOUNTER_RARITIES = [
  {
    :name  => _INTL("Common"),
    :min   => 10,
    :max   => 100,
    :rank  => 0,
    :color => Color.new(190, 190, 190)
  },
  {
    :name  => _INTL("Uncommon"),
    :min   => 4,
    :max   => 10,
    :rank  => 1,
    :color => Color.new(19, 209, 2)
  },
  {
    :name  => _INTL("Rare"),
    :min   => 0,
    :max   => 4,
    :rank  => 2,
    :color => Color.new(2, 203, 230)
  }
]

#-------------------------------------------------------------------------------
# Background settings
#-------------------------------------------------------------------------------

# Backgrounds used for fishing and surfing.
# Files must exist in Graphics/Battlebacks.
FISHING_ENCOUNTER_BACKGROUND = "lake"
SURFING_ENCOUNTER_BACKGROUND = "sea"

# Existing fallback background.
ENCOUNTER_DEFAULT_BACKGROUND = "Graphics/UI/EncounterUI/bg"

#-------------------------------------------------------------------------------
# Text style
#-------------------------------------------------------------------------------

ENCOUNTER_TEXT_BASE   = Color.new(248, 248, 248)
ENCOUNTER_TEXT_SHADOW = Color.new(40, 40, 40)

#-------------------------------------------------------------------------------
# Method that returns whether a specific form has been seen (any gender)
#-------------------------------------------------------------------------------

def seen_form_any_gender?(species, form)
  return (
    $player.pokedex.seen_form?(species, 0, form) ||
    $player.pokedex.seen_form?(species, 1, form)
  )
end

#===============================================================================
# Encounter List Scene
#===============================================================================

class EncounterList_Scene

  #---------------------------------------------------------------------------
  # Constructor
  #---------------------------------------------------------------------------

  def initialize
    @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
    @viewport.z = 99999
    @sprites = {}

    mapid = $game_map.map_id
    @encounter_data = GameData::Encounter.get(
      mapid, $PokemonGlobal.encounter_version
    )

    if @encounter_data
      @encounter_tables = Marshal.load(
        Marshal.dump(@encounter_data.types)
      )
      @max_enc, @eLength = getMaxEncounters(@encounter_tables)
    else
      @max_enc, @eLength = [1, 1]
    end

    @index = 0
  end

  #---------------------------------------------------------------------------
  # Returns the maximum number of unique encounters in a table
  #---------------------------------------------------------------------------

  def getMaxEncounters(data)
    return [1, 1] if !data || data.empty?

    max_enc = 1

    data.each_value do |arr|
      unique_species = arr.map { |entry| entry[1] }.uniq
      max_enc = [max_enc, unique_species.length].max
    end

    return max_enc, data.keys.length
  end

  #---------------------------------------------------------------------------
  # Adds text to a text list
  #---------------------------------------------------------------------------

  def addEncounterText(textpos, text, x, y, align = :left,
                       base = ENCOUNTER_TEXT_BASE,
                       shadow = ENCOUNTER_TEXT_SHADOW,
                       outline = true)
    entry = [text, x, y, align, base, shadow]
    entry.push(:outline) if outline
    textpos.push(entry)
  end

  #---------------------------------------------------------------------------
  # Draws regular text using the system font
  #---------------------------------------------------------------------------

  def drawEncounterText(textpos)
    overlay = @sprites["overlay"].bitmap
    overlay.clear
    pbSetSystemFont(overlay)
    pbDrawTextPositions(overlay, textpos)
  end

  #---------------------------------------------------------------------------
  # Draws percentages using the standard system font size
  #---------------------------------------------------------------------------

  def drawEncounterChanceText(textpos)
    overlay = @sprites["chance_overlay"].bitmap
    overlay.clear
    pbSetSystemFont(overlay)
    pbDrawTextPositions(overlay, textpos)
  end

  #---------------------------------------------------------------------------
  # Returns the background to use for the current encounter type
  #---------------------------------------------------------------------------

  def getEncounterBackground(currKey)
    # Surfing.
    if [:Water, :WaterDay, :WaterNight, :WaterMorning,
        :WaterAfternoon, :WaterEvening].include?(currKey)
      return "Graphics/Battlebacks/#{SURFING_ENCOUNTER_BACKGROUND}_bg"
    end

    # Fishing.
    if [:OldRod, :GoodRod, :SuperRod].include?(currKey)
      return "Graphics/Battlebacks/#{FISHING_ENCOUNTER_BACKGROUND}_bg"
    end

    # Encounter types that use the current map's battleback.
    dynamic_types = [
      :Land, :LandDay, :LandNight, :LandMorning,
      :LandAfternoon, :LandEvening,
      :Cave, :CaveDay, :CaveNight, :CaveMorning,
      :CaveAfternoon, :CaveEvening,
      :PokeRadar,
      :BugContest,
      :HeadbuttLow, :HeadbuttHigh,
      :RockSmash
    ]

    if dynamic_types.include?(currKey)
      metadata = GameData::MapMetadata.try_get($game_map.map_id)

      if metadata && metadata.battle_background &&
         !metadata.battle_background.empty?
        background = metadata.battle_background
        path = "Graphics/Battlebacks/#{background}_bg"

        # Use the map's battleback only if its image exists.
        return path if pbResolveBitmap(path)
      end
    end

    # Keep the original UI background for unsupported types or
    # when the map does not define a usable battleback.
    return ENCOUNTER_DEFAULT_BACKGROUND
  end

  #---------------------------------------------------------------------------
  # Updates the background image
  #---------------------------------------------------------------------------

  def updateEncounterBackground(currKey)
    background_path = getEncounterBackground(currKey)

    # If the requested image is missing, use the original UI background.
    if !pbResolveBitmap(background_path)
      background_path = ENCOUNTER_DEFAULT_BACKGROUND
    end

    background = @sprites["bg"]
    background.setBitmap(background_path)

    # Stretch the background to fill the screen.
    if background.bitmap && background.bitmap.width > 0 &&
       background.bitmap.height > 0
      background.zoom_x =
        Graphics.width.to_f / background.bitmap.width
      background.zoom_y =
        Graphics.height.to_f / background.bitmap.height
      background.x = 0
      background.y = 0
      background.ox = 0
      background.oy = 0
    end
  end

  #---------------------------------------------------------------------------
  # Start scene
  #---------------------------------------------------------------------------

  def pbStartScene
    if !File.file?("Graphics/UI/EncounterUI/" + WINDOWSKIN)
      raise _INTL(
        "You are missing the graphic for this UI. Make sure the image is in your Graphics/UI folder and that it is named appropriately."
      )
    end

    # Background sprite, updated according to the encounter type.
    @sprites["bg"] = IconSprite.new(0, 0, @viewport)
    @sprites["bg"].setBitmap(ENCOUNTER_DEFAULT_BACKGROUND)
    @sprites["bg"].z = -1

    # Main window.
    @sprites["base"] = IconSprite.new(0, 0, @viewport)
    @sprites["base"].setBitmap(
      "Graphics/UI/EncounterUI/" + WINDOWSKIN
    )
    @sprites["base"].ox = @sprites["base"].bitmap.width / 2
    @sprites["base"].oy = @sprites["base"].bitmap.height / 2
    @sprites["base"].x = Graphics.width / 2
    @sprites["base"].y = Graphics.height / 2
    @sprites["base"].opacity = 255

    @h = (Graphics.height - @sprites["base"].bitmap.height) / 2
    @w = (Graphics.width - @sprites["base"].bitmap.width) / 2

    # Main text overlay.
    @sprites["overlay"] = BitmapSprite.new(
      Graphics.width, Graphics.height, @viewport
    )
    @sprites["overlay"].visible = true

    # Separate overlay for percentage labels.
    @sprites["chance_overlay"] = BitmapSprite.new(
      Graphics.width, Graphics.height, @viewport
    )
    @sprites["chance_overlay"].visible = true

    # Pokémon icons.
    @max_enc.times do |i|
      @sprites["icon_#{i}"] = PokemonSpeciesIconSprite.new(nil, @viewport)
      @sprites["icon_#{i}"].visible = false
    end

    @sprites["rightarrow"] = AnimatedSprite.new(
      "Graphics/UI/right_arrow", 8, 40, 28, 2, @viewport
    )
    @sprites["rightarrow"].x =
      Graphics.width - @sprites["rightarrow"].bitmap.width
    @sprites["rightarrow"].y =
      Graphics.height / 2 - @sprites["rightarrow"].bitmap.height / 16
    @sprites["rightarrow"].visible = false
    @sprites["rightarrow"].play

    @sprites["leftarrow"] = AnimatedSprite.new(
      "Graphics/UI/left_arrow", 8, 40, 28, 2, @viewport
    )
    @sprites["leftarrow"].x = 0
    @sprites["leftarrow"].y =
      Graphics.height / 2 - @sprites["rightarrow"].bitmap.height / 16
    @sprites["leftarrow"].visible = false
    @sprites["leftarrow"].play

    @encounter_data ? drawPresent : drawAbsent

    pbFadeInAndShow(@sprites) { pbUpdate }
  end

  #---------------------------------------------------------------------------
  # Main UI loop
  #---------------------------------------------------------------------------

  def pbEncounter
    loop do
      Graphics.update
      Input.update
      pbUpdate

      if Input.trigger?(Input::RIGHT) && @eLength > 1 && @index < @eLength - 1
        pbPlayCursorSE
        hideSprites
        @index += 1
        drawPresent

      elsif Input.trigger?(Input::LEFT) && @eLength > 1 && @index != 0
        pbPlayCursorSE
        hideSprites
        @index -= 1
        drawPresent

      elsif Input.trigger?(Input::USE) || Input.trigger?(Input::BACK)
        pbPlayCloseMenuSE
        break
      end
    end
  end

  #---------------------------------------------------------------------------
  # Returns the rarity information associated with a probability
  #---------------------------------------------------------------------------

  def getEncounterRarity(chance)
    ENCOUNTER_RARITIES.each do |rarity|
      if chance >= rarity[:min] && chance <= rarity[:max]
        return rarity
      end
    end

    # Values below 1% are assigned to Rare as a fallback.
    return ENCOUNTER_RARITIES[2] if chance < 1
    return ENCOUNTER_RARITIES[0]
  end

  #---------------------------------------------------------------------------
  # Returns encounters with duplicate species combined
  #---------------------------------------------------------------------------

  def getEncData
    currKey = @encounter_tables.keys[@index]
    return [[], currKey] if !currKey

    totals = {}

    @encounter_tables[currKey].each do |entry|
      chance  = entry[0].to_f
      species = entry[1]
      next if !species

      totals[species] = 0.0 if !totals[species]
      totals[species] += chance
    end

    # Normalize each encounter against the sum of all weights in this table.
    total_chance = @encounter_tables[currKey].inject(0.0) do |sum, entry|
      sum + entry[0].to_f
    end
    return [[], currKey] if total_chance <= 0

    encounters = []

    totals.each do |species, weight|
      species_data = GameData::Species.try_get(species)
      next if !species_data

      chance = weight.to_f * 100.0 / total_chance
      encounters.push({
        :species => species,
        :chance  => chance,
        :rarity  => getEncounterRarity(chance),
        :dexnum  => species_data.id
      })
    end

    # Sort by rarity first, then by chance from highest to lowest,
    # then by Pokédex number if the chances are equal.
    encounters.sort_by! do |entry|
      [
        entry[:rarity][:rank],
        -entry[:chance],
        entry[:dexnum]
      ]
    end

    return encounters, currKey
  end

  #---------------------------------------------------------------------------
  # Draw text and icons when the map has encounters
  #---------------------------------------------------------------------------

  def drawPresent
    @sprites["rightarrow"].visible = (@index < @eLength - 1)
    @sprites["leftarrow"].visible = (@index > 0)

    hideSprites

    encounters, currKey = getEncData

    # Update the background for the currently selected encounter type.
    updateEncounterBackground(currKey)

    textpos = []
    chance_textpos = []

    # Header.
    name = if USER_DEFINED_NAMES && USER_DEFINED_NAMES[currKey]
             USER_DEFINED_NAMES[currKey]
           else
             GameData::EncounterType.get(currKey).real_name
           end

    addEncounterText(
      textpos,
      _INTL("{1} : {2}", $game_map.name, name),
      @w + 256,
      @h + 7,
      :center
    )

    # Group Pokémon by rarity.
    grouped_encounters = {}
    ENCOUNTER_RARITIES.each do |rarity|
      grouped_encounters[rarity[:rank]] = []
    end

    encounters.each do |encounter|
      grouped_encounters[encounter[:rarity][:rank]] << encounter
    end

    # Layout settings for the 512 x 384 window.
    icons_per_row = 6
    column_width = 80
    icon_start_x = @w + 25

    # Vertical spacing adapted to three rarity groups.
    row_height = 110
    rarity_gap = 8
    icon_y_offset = 18
    chance_y_offset = 66
    start_y = @h + 37

    icon_index = 0
    row_index = 0
    rarity_sections = 0

    ENCOUNTER_RARITIES.each do |rarity|
      group = grouped_encounters[rarity[:rank]]
      next if group.empty?

      # Add a small, consistent gap between non-empty rarity sections.
      rarity_y = start_y + row_index * row_height + rarity_gap * rarity_sections

      addEncounterText(
        textpos,
        _INTL(rarity[:name]),
        @w + 28,
        rarity_y,
        :left,
        rarity[:color]
      )

      group.each_with_index do |encounter, group_index|
        break if icon_index >= @max_enc

        extra_row = group_index / icons_per_row
        column = group_index % icons_per_row

        species = encounter[:species]
        chance  = encounter[:chance]
        species_data = GameData::Species.get(species)

        icon = @sprites["icon_#{icon_index}"]
        icon.x = icon_start_x + column_width * column
        icon.y = start_y + (row_index + extra_row) * row_height +
                 icon_y_offset + rarity_gap * rarity_sections
        icon.pbSetParams(species, 0, species_data.form, false)

        if !$player.pokedex.owned?(species)
          icon.tone = Tone.new(0, 0, 0, 255)
        else
          icon.tone = Tone.new(0, 0, 0, 0)
        end

        icon.visible = true

        chance_text = sprintf("%.1f%%", chance)

        # Center the percentage beneath the Pokémon icon.
        addEncounterText(
          chance_textpos,
          chance_text,
          icon.x + 32,
          icon.y + chance_y_offset,
          :center,
          ENCOUNTER_TEXT_BASE,
          ENCOUNTER_TEXT_SHADOW,
          false
        )

        icon_index += 1
      end

      # Reserve enough vertical space for all rows in this rarity group.
      rows_used = [(group.length.to_f / icons_per_row).ceil, 1].max
      row_index += rows_used
      rarity_sections += 1
    end

    drawEncounterText(textpos)
    drawEncounterChanceText(chance_textpos)
  end

  #---------------------------------------------------------------------------
  # Draw text when the map has no encounters
  #---------------------------------------------------------------------------

  def drawAbsent
    textpos = []

    addEncounterText(
      textpos,
      _INTL("{1}", $game_map.name),
      @w + 256,
      @h + 8,
      :center
    )

    addEncounterText(
      textpos,
      _INTL("This area has no encounters!"),
      @w + 20,
      @h + 36
    )

    drawEncounterText(textpos)
  end

  #---------------------------------------------------------------------------
  # Update
  #---------------------------------------------------------------------------

  def pbUpdate
    pbUpdateSpriteHash(@sprites)
  end

  #---------------------------------------------------------------------------
  # Hide Pokémon icons and clear text overlays
  #---------------------------------------------------------------------------

  def hideSprites
    @max_enc.times do |i|
      @sprites["icon_#{i}"].visible = false if @sprites["icon_#{i}"]
    end

    @sprites["overlay"].bitmap.clear if @sprites["overlay"]
    @sprites["chance_overlay"].bitmap.clear if @sprites["chance_overlay"]
  end

  #---------------------------------------------------------------------------
  # End scene
  #---------------------------------------------------------------------------

  def pbEndScene
    pbFadeOutAndHide(@sprites) { pbUpdate }
    pbDisposeSpriteHash(@sprites)
    @viewport.dispose
  end
end

#===============================================================================
# Encounter List Screen
#===============================================================================

class EncounterList_Screen
  def initialize(scene)
    @scene = scene
  end

  def pbStartScreen
    @scene.pbStartScene
    @scene.pbEncounter
    @scene.pbEndScene
  end
end

#===============================================================================
# Utility method
#===============================================================================

def pbViewEncounters
  scene = EncounterList_Scene.new
  screen = EncounterList_Screen.new(scene)
  screen.pbStartScreen
end