#===============================================================================
# Pokedex Evolution Page
#===============================================================================
# Adding the page
#===============================================================================
UIHandlers.add(:pokedex, :page_evolution, {
  "name"      => "EVOLUTION",
  "suffix"    => "evolution",
  "order"     => 40,
  "onlyOwned" => true,
  "layout"    => proc { |pkmn, scene| scene.drawPageEvolution }
})

#===============================================================================
# Page Script
#===============================================================================
class PokemonPokedexInfo_Scene

  alias org_pbStartScene pbStartScene
  def pbStartScene(*args)
    org_pbStartScene(*args)

    10.times do |i|
      # Pokémon evolution icon
      @sprites["evoicon#{i}"] = PokemonSpeciesIconSprite.new(nil, @viewport)
	  @sprites["evoicon#{i}"].setOffset(PictureOrigin::CENTER)
	  @sprites["evoicon#{i}"].zoom_x = 1.5
	  @sprites["evoicon#{i}"].zoom_y = 1.5
	  @sprites["evoicon#{i}"].x = 0
	  @sprites["evoicon#{i}"].y = 158
	  @sprites["evoicon#{i}"].visible = false

      # Item icon used by the evolution condition
      @sprites["evoitem#{i}"] = ItemIconSprite.new(0, 0, nil, @viewport)
      @sprites["evoitem#{i}"].setOffset(PictureOrigin::CENTER)
      @sprites["evoitem#{i}"].visible = false
      @sprites["evoitem#{i}"].blankzero = true
    end

    pbUpdateDummyPokemon
  end

  alias org_pbUpdateDummyPokemon pbUpdateDummyPokemon
  def pbUpdateDummyPokemon
    org_pbUpdateDummyPokemon

    stage_1 = GameData::Species.get(@species).get_baby_species
    stage_2 = GameData::Species.get(stage_1).get_evolutions.map { |poke| poke.push(stage_1) }
    stage_3 = []

    stage_2.each do |pkmn|
      stage_3.concat(
        GameData::Species.get(pkmn[0]).get_evolutions.map { |poke| poke.push(pkmn[0]) }
      )
    end

    @evolutions = [[[stage_1]]]
    @evolutions.push(stage_2.uniq { |pkmn| pkmn[0] }) if !stage_2.empty?
    @evolutions.push(stage_3.uniq { |pkmn| pkmn[0] }) if !stage_3.empty?

    10.times do |i|
      @sprites["evoicon#{i}"]&.species = nil
      @sprites["evoitem#{i}"]&.item = nil
      @sprites["evoitem#{i}"].visible = false if @sprites["evoitem#{i}"]
    end

    index = 0

    @evolutions.length.times do |i|
      @evolutions[i].length.times do |v|
        specie = @evolutions[i][v][0]

        gender, form, shiny = $player.pokedex.last_form_seen(specie)

        @sprites["evoicon#{index}"]&.pbSetParams(
          specie,
          gender,
          form,
          shiny
        )

        @sprites["evoicon#{index}"]&.x =
          ((Graphics.width + 100) / (@evolutions[i].length + 1)) * (v + 1) - 50

        vertical_spacing = 1.25
		center_y = Graphics.height / 2
		base_spacing = Graphics.height / (@evolutions.length + 1)

		@sprites["evoicon#{index}"]&.y =
		  center_y + ((i - (@evolutions.length - 1) / 2.0) * base_spacing * vertical_spacing) + 20

        index += 1
      end
    end

    #=============================================================================
    # Special Eevee evolution layout
    #=============================================================================
    index = 0

    if @evolutions[0][0][0].to_sym == :EEVEE
      @evolutions.length.times do |i|
        @evolutions[i].length.times do |v|
          @sprites["evoicon#{index}"]&.x =
            [256, 103, 409, 103, 256, 409, 103, 256, 409][index]

          @sprites["evoicon#{index}"]&.y =
            [115, 115, 115, 224, 224, 224, 333, 333, 333][index]

          index += 1
        end
      end
    end
  end

  alias org_drawPage drawPage
  def drawPage(page)
    10.times do |i|
      @sprites["evoicon#{i}"].visible = false if @sprites["evoicon#{i}"]
      @sprites["evoitem#{i}"].visible = false if @sprites["evoitem#{i}"]
    end

    pbSetSystemFont(@sprites["overlay"].bitmap)
    org_drawPage(page)
  end

  #=============================================================================
  # Evolution page
  #=============================================================================
  def drawPageEvolution
    10.times do |i|
      @sprites["evoicon#{i}"].visible =
        true if !@sprites["evoicon#{i}"].species.nil?
    end

    overlay = @sprites["overlay"].bitmap

    pbSetNarrowFont(overlay)

    base   = Color.new(248, 248, 248)
    shadow = Color.new(0, 0, 0)

    textpos = []

    index = 0

    @evolutions.length.times do |i|
      @evolutions[i].length.times do |v|

        #-----------------------------------------------------------------------
        # Skip baby Pokémon
        #-----------------------------------------------------------------------
        if GameData::Species.get(@evolutions[i][v][0]).get_baby_species ==
           @evolutions[i][v][0]
          index += 1
          next
        end

        #-----------------------------------------------------------------------
        # Evolution condition
        #-----------------------------------------------------------------------
        evo_txt = nil
        item_id = nil

        case @evolutions[i][v][1]

        when :Level, :Silcoon, :Cascoon
          evo_txt = [_INTL("Lv. #{@evolutions[i][v][2]}")]

        when :LevelMale
          evo_txt = [_INTL("Lv. #{@evolutions[i][v][2]}"), _INTL("(Male)")]

        when :LevelFemale
          evo_txt = [_INTL("Lv. #{@evolutions[i][v][2]}"), _INTL("(Female)")]

        when :LevelDay
          evo_txt = [_INTL("Lv. #{@evolutions[i][v][2]}"), _INTL("(during the day)")]

        when :LevelNight
          evo_txt = [_INTL("Lv. #{@evolutions[i][v][2]}"), _INTL("(at night)")]

        when :LevelMorning
          evo_txt = [_INTL("Lv. #{@evolutions[i][v][2]}"), _INTL("(during the morning)")]

        when :LevelAfternoon
          evo_txt = [_INTL("Lv. #{@evolutions[i][v][2]}"), _INTL("(during the afternoon)")]

        when :LevelNoWeather
          evo_txt = [_INTL("Lv. #{@evolutions[i][v][2]}"), _INTL("(during the evening)")]

        when :LevelSun
          evo_txt = [_INTL("Lv. #{@evolutions[i][v][2]}"), _INTL("(during sun)")]

        when :LevelRain
          evo_txt = [_INTL("Lv. #{@evolutions[i][v][2]}"), _INTL("(during rain)")]

        when :LevelSnow
          evo_txt = [_INTL("Lv. #{@evolutions[i][v][2]}"), _INTL("(during snow)")]

        when :LevelSandstorm
          evo_txt = [_INTL("Lv. #{@evolutions[i][v][2]}"), _INTL("(during sandstorm)")]

        when :LevelCycling
          evo_txt = [_INTL("Lv. #{@evolutions[i][v][2]}"), _INTL("(while cycling)")]

        when :LevelSurfing
          evo_txt = [_INTL("Lv. #{@evolutions[i][v][2]}"), _INTL("(while surfing)")]

        when :LevelDiving
          evo_txt = [_INTL("Lv. #{@evolutions[i][v][2]}"), _INTL("(while diving)")]

        when :LevelDarkness
          evo_txt = [_INTL("Lv. #{@evolutions[i][v][2]}"), "(on dark places)"]

        when :LevelDarkInParty
          evo_txt = [_INTL("Lv. #{@evolutions[i][v][2]}"),
                     _INTL("(with a Dark-type in the party)")]

        when :AttackGreater
          evo_txt = [_INTL("Lv. #{@evolutions[i][v][2]}"), _INTL("(Atk > Def)")]

        when :AtkDefEqual
          evo_txt = [_INTL("Lv. #{@evolutions[i][v][2]}"), _INTL("(Atk = Def)")]

        when :DefenseGreater
          evo_txt = [_INTL("Lv. #{@evolutions[i][v][2]}"), _INTL("(Atk < Def)")]

        when :Ninjask
          evo_txt = [_INTL("Lv. #{@evolutions[i][v][2]}")]

        when :Shedinja
          evo_txt = [_INTL("Pokeball in bag"), _INTL("and space in party")]

        when :Happiness
          evo_txt = [_INTL("Lv. up"), _INTL("with high friendship")]

        when :HappinessMale
          evo_txt = [_INTL("High friendship"), _INTL("(Male)")]

        when :HappinessFemale
          evo_txt = [_INTL("High friendship"), _INTL("(Female)")]

        when :HappinessDay
          evo_txt = [_INTL("High friendship"), _INTL("(during the day)")]

        when :HappinessNight
          evo_txt = [_INTL("High friendship"), _INTL("(at night)")]

        when :HappinessMove
          evo_txt = [
            _INTL("High friendship"),
            _INTL("knowing #{GameData::Move.get(@evolutions[i][v][2]).name}")
          ]

        when :HappinessMoveType
          evo_txt = [
            _INTL("High friendship"),
            _INTL("knowing #{GameData::Type.get(@evolutions[i][v][2]).name}-type move")
          ]

        when :HappinessHoldItem
          item_id = @evolutions[i][v][2]
          evo_txt = [
            _INTL("High friendship"),
            _INTL("holding #{GameData::Item.get(item_id).name}")
          ]

        when :MaxHappiness
          evo_txt = [_INTL("Lv. up"), _INTL("with max friendship")]

        when :Beauty
          evo_txt = [_INTL("Lv. up"), _INTL("with high beauty")]

        when :HoldItem
          item_id = @evolutions[i][v][2]
          evo_txt = [
            _INTL("Lv. up"),
            _INTL("holding #{GameData::Item.get(item_id).name}")
          ]

        when :HoldItemMale
          item_id = @evolutions[i][v][2]
          evo_txt = [
            _INTL("Lv. up holding"),
            _INTL("#{GameData::Item.get(item_id).name} (Male)")
          ]

        when :HoldItemFemale
          item_id = @evolutions[i][v][2]
          evo_txt = [
            _INTL("Lv. up holding"),
            _INTL("#{GameData::Item.get(item_id).name} (Female)")
          ]

        when :DayHoldItem
          item_id = @evolutions[i][v][2]
          evo_txt = [
            _INTL("Lv. up holding"),
            _INTL("#{GameData::Item.get(item_id).name} (during the day)")
          ]

        when :NightHoldItem
          item_id = @evolutions[i][v][2]
          evo_txt = [
            _INTL("Lv. up holding"),
            _INTL("#{GameData::Item.get(item_id).name} (at night)")
          ]

        when :HasMove
          evo_txt = [
            _INTL("Lv. up"),
            _INTL("knowing #{GameData::Move.get(@evolutions[i][v][2]).name}")
          ]

        when :HasMoveType
          evo_txt = [
            _INTL("Lv. up"),
            _INTL("knowing #{GameData::Type.get(@evolutions[i][v][2]).name}-type move")
          ]

        when :HasInParty
          evo_txt = [
            _INTL("Lv. up"),
            _INTL("with #{GameData::Species.get(@evolutions[i][v][2]).name} in party")
          ]

        when :Location
          evo_txt = [_INTL("Lv. up"), _INTL("near #{@evolutions[i][v][2]}")]

        when :LocationFlag
          evo_txt = [_INTL("Lv. up"), _INTL("near #{@evolutions[i][v][2]}")]

        when :Item
          item_id = @evolutions[i][v][2]
          evo_txt = [_INTL("#{GameData::Item.get(item_id).name}")]

        when :ItemMale
          item_id = @evolutions[i][v][2]
          evo_txt = [
            _INTL("#{GameData::Item.get(item_id).name}"),
            _INTL("(Male)")
          ]

        when :ItemFemale
          item_id = @evolutions[i][v][2]
          evo_txt = [
            _INTL("#{GameData::Item.get(item_id).name}"),
            _INTL("(Female)")
          ]

        when :ItemDay
          item_id = @evolutions[i][v][2]
          evo_txt = [
            _INTL("#{GameData::Item.get(item_id).name}"),
            _INTL("(during the day)")
          ]

        when :ItemNight
          item_id = @evolutions[i][v][2]
          evo_txt = [
            _INTL("#{GameData::Item.get(item_id).name}"),
            _INTL("(at night)")
          ]

        when :ItemHappiness
          item_id = @evolutions[i][v][2]
          evo_txt = [
            _INTL("#{GameData::Item.get(item_id).name}"),
            _INTL("with high friendship")
          ]

        when :Trade
          evo_txt = [_INTL("Trade")]

        when :TradeMale
          evo_txt = [_INTL("Trade"), _INTL("(Male)")]

        when :TradeFemale
          evo_txt = [_INTL("Trade"), _INTL("(Female)")]

        when :TradeDay
          evo_txt = [_INTL("Trade"), _INTL("(during the day)")]

        when :TradeNight
          evo_txt = [_INTL("Trade"), _INTL("(at night)")]

        when :TradeItem
          item_id = @evolutions[i][v][2]
          evo_txt = [
            _INTL("Trade"),
            _INTL("holding #{GameData::Item.get(item_id).name}")
          ]

        when :TradeSpecies
          evo_txt = [
            _INTL("Trade"),
            _INTL("for #{GameData::Species.get(@evolutions[i][v][2]).name}")
          ]

        when :BattleDealCriticalHit
          evo_txt = [_INTL("After dealing critical hit in battle")]

        when :Event
          evo_txt = [_INTL("Special Event")]

        when :EventAfterDamageTaken
          evo_txt = [
            _INTL("Special Event"),
            _INTL("after taking damage")
          ]

        else
          evo_txt = [_INTL("???")]
        end

        #-----------------------------------------------------------------------
        # Merge short two-line descriptions
        #-----------------------------------------------------------------------
        if @evolutions[i].length < 2 && evo_txt.length > 1
          evo_txt = [evo_txt[0] + " " + evo_txt[1]]
        end

        if evo_txt[1] &&
           (evo_txt[0].length + evo_txt[1].length <= 16)
          evo_txt = [evo_txt[0] + " " + evo_txt[1]]
        end

        #-----------------------------------------------------------------------
        # Position
        #
        # Text is now ABOVE the Pokémon sprite.
        # For item evolutions, the item icon is placed before the text.
        # The complete icon + text group is centered on the Pokémon.
        #-----------------------------------------------------------------------
        sprite_x = @sprites["evoicon#{index}"].x
        sprite_y = @sprites["evoicon#{index}"].y

        # Base Y position for the first line of text.
        #
        # One line:
        #       [ITEM] Text
        #       [POKEMON]
        #
        # Two lines:
        #       [ITEM] Text
        #       second line
        #       [POKEMON]
        #
		
        #=============================================================================
        # Text position
        #=============================================================================

        # Special Eevee layout:
        # Each evolution has its own position, so the text stays above its sprite.
        if @evolutions[0][0][0].to_sym == :EEVEE
          if evo_txt.length == 1
          text_y = sprite_y - 58
          else
          text_y = sprite_y - 84
          end

        # First evolution stage:
        # Text goes above the Pokémon.
        elsif i == 0
          if evo_txt.length == 1
          text_y = sprite_y - 78
          else
          text_y = sprite_y - 104
          end

        # Other stages:
        # Find the Pokémon from the previous stage that is horizontally
        # closest to the current Pokémon, then center the text between them.
        else
          # Find all Pokémon from the immediately previous evolution stage.
          # The closest one horizontally is used to position the text.
          previous_stage_indices = []

          previous_index = 0

          i.times do |previous_stage|
          if previous_stage == i - 1
            @evolutions[previous_stage].length.times do |v|
            previous_stage_indices << previous_index + v
            end
          end

          previous_index += @evolutions[previous_stage].length
          end

          previous_sprites = previous_stage_indices.map do |previous_index|
          @sprites["evoicon#{previous_index}"]
          end.compact.select { |sprite| !sprite.species.nil? }

          if !previous_sprites.empty?
          # Use the previous-stage Pokémon that is closest horizontally
          # to the current Pokémon.
          previous_sprite = previous_sprites.min_by do |sprite|
            (sprite.x - sprite_x).abs
          end

          gap_center = (previous_sprite.y + sprite_y) / 2

          if evo_txt.length == 1
            text_y = gap_center - 12
          else
            text_y = gap_center - 24
          end
          else
          # Fallback
          if evo_txt.length == 1
            text_y = sprite_y - 78
          else
            text_y = sprite_y - 104
          end
          end
        end

        #-----------------------------------------------------------------------
        # Item icon
        #-----------------------------------------------------------------------
        if item_id
          item = GameData::Item.try_get(item_id)

          if item
            item_sprite = @sprites["evoitem#{index}"]

            item_sprite.item = item.id
            item_sprite.visible = true

            # Measure the first line of text.
            text_width = overlay.text_size(evo_txt[0]).width

            # Item icon size.
            item_width = 32

            # Space between item and text.
            gap = 8

            # Total width of icon + text.
            total_width = item_width + gap + text_width

            # Start position of the complete centered group.
            group_left = sprite_x - (total_width / 2)

            # Center the item icon vertically on the text.
            item_sprite.x = group_left + (item_width / 2)
            item_sprite.y = text_y + 8

            # Text starts immediately after the item.
            text_x = group_left + item_width + gap

            textpos.push([
              evo_txt[0],
              text_x,
              text_y,
              :left,
              base,
              shadow,
              :outline
            ])
          else
            # Fallback if the item doesn't exist.
            textpos.push([
              evo_txt[0],
              sprite_x,
              text_y,
              :center,
              base,
              shadow,
              :outline
            ])
          end
        else
          # No item: simply center the text above the Pokémon.
          textpos.push([
            evo_txt[0],
            sprite_x,
            text_y,
            :center,
            base,
            shadow,
            :outline
          ])
        end

        #-----------------------------------------------------------------------
        # Second line
        #-----------------------------------------------------------------------
        if evo_txt.length > 1
          textpos.push([
            evo_txt[1],
            sprite_x,
            text_y + 24,
            :center,
            base,
            shadow,
            :outline
          ])
        end

        index += 1
      end
    end

    # Draw all text
    pbDrawTextPositions(overlay, textpos)
  end
end