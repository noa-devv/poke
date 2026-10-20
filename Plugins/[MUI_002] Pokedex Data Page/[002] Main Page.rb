#===============================================================================
# Main Data Page display
#===============================================================================
class PokemonPokedexInfo_Scene
  #-----------------------------------------------------------------------------
  # Controls for navigating the Data page.
  # The only selectable buttons on this page are Abilities, Moves and Items.
  #-----------------------------------------------------------------------------
  def pbDataPageMenu
    pbPlayDecisionSE
    @data_page_menu_active = true
    @cursor = :ability
    # Redraw immediately so the default Abilities selection is visible on entry.
    drawPage(@page)
    species_data = GameData::Species.get_species_form(@species, @form)
    species_id = species_data.id
    buttons = [:ability, :moves, :item]
    loop do
      Graphics.update
      Input.update
      pbUpdate
      if Input.trigger?(Input::BACK)
        pbPlayCancelSE
        @sprites["data_overlay"].bitmap.clear
        @sprites["datapokemon"].visible = false
        @data_page_menu_active = false
        break
      elsif Input.trigger?(Input::USE)
        case @cursor
        when :moves
          next if !$player.owned?(species_id)
          pbChooseMove(species_data, nil)
        when :item, :ability
          next if !$player.owned?(species_id)
          pbChooseDataList
        end
        break if @forceRefresh
      elsif Input.repeat?(Input::UP)
        idx = buttons.index(@cursor) || 0
        idx = (idx - 1) % buttons.length
        @cursor = buttons[idx]
        pbPlayCursorSE
        drawPage(@page)
      elsif Input.repeat?(Input::DOWN)
        idx = buttons.index(@cursor) || 0
        idx = (idx + 1) % buttons.length
        @cursor = buttons[idx]
        pbPlayCursorSE
        drawPage(@page)
      end
    end
    @forceRefresh = false
    @sprites["datapokemon"].visible = false
    drawPage(@page)
  end

  #-----------------------------------------------------------------------------
  # Utility for generating the ability and held item lists for the viewed species.
  #-----------------------------------------------------------------------------
  def pbGenerateDataLists(species)
    @data_hash = {
      :species => species.id
    }

    #---------------------------------------------------------------------------
    # Generates the list of this species' abilities.
    #---------------------------------------------------------------------------
    @data_hash[:ability] = Hash.new { |key, value| key[value] = [] }
    species.abilities.each do |ability|
      next if @data_hash[:ability][0].include?(ability)
      @data_hash[:ability][0] << ability
    end
    species.hidden_abilities.each do |ability|
      next if @data_hash[:ability][0].include?(ability)
      next if @data_hash[:ability][1].include?(ability)
      @data_hash[:ability][1] << ability
    end
    case species.id
    when :GRENINJA
      if GameData::Species.exists?(:GRENINJA_1) &&
         GameData::Species.get(:GRENINJA_1).abilities.include?(:BATTLEBOND)
        @data_hash[:ability][2] << :BATTLEBOND
      end
    when :ROCKRUFF
      if GameData::Species.exists?(:ROCKRUFF_2) &&
         GameData::Species.get(:ROCKRUFF_2).abilities.include?(:OWNTEMPO)
        @data_hash[:ability][2] << :OWNTEMPO
      end
    end

    #---------------------------------------------------------------------------
    # Generates the list of this species' wild held items.
    #---------------------------------------------------------------------------
    @data_hash[:item] = Hash.new { |key, value| key[value] = [] }
    species.wild_item_common.each do |item|
      next if @data_hash[:item][0].include?(item)
      @data_hash[:item][0] << item
    end
    species.wild_item_uncommon.each do |item|
      next if @data_hash[:item][0].include?(item)
      next if @data_hash[:item][1].include?(item)
      @data_hash[:item][1] << item
    end
    species.wild_item_rare.each do |item|
      next if @data_hash[:item][0].include?(item)
      next if @data_hash[:item][1].include?(item)
      next if @data_hash[:item][2].include?(item)
      @data_hash[:item][2] << item
    end
  end

  #-----------------------------------------------------------------------------
  # Draws the data page.
  #-----------------------------------------------------------------------------
  def drawPageData
    @data_page_active = true
    base   = Color.new(248, 248, 248)
    shadow = Color.new(40, 40, 40)
    path   = Settings::POKEDEX_DATA_PAGE_GRAPHICS_PATH
    # Use the dedicated Data-page background so the old Pokedex layout is not
    # left behind behind the new button/stat arrangement.
    @sprites["background"].setBitmap(_INTL(path + "bg_data"))
    overlay = @sprites["overlay"].bitmap
    imagepos = []
    textpos = []
    owned = $player.owned?(@species)
    species_data = GameData::Species.get_species_form(@species, @form)
    pbGenerateDataLists(species_data) if @data_hash[:species] != species_data.id

    #---------------------------------------------------------------------------
    # Draws species name and typing.
    #---------------------------------------------------------------------------
    textpos.push([species_data.name, 114, 56, :left, base, Color.black, :outline])
    if owned
      species_data.types.each_with_index do |type, i|
        type_number = GameData::Type.get(type).icon_position
        type_rect = Rect.new(0, type_number * 28, 64, 28)
        type_x = ((315 + 512) - (64 + (species_data.types.length - 1) * 80)) / 2 + (80 * i)
        overlay.blt(type_x, 50, @typebitmap2.bitmap, type_rect)
      end
    end

    #---------------------------------------------------------------------------
    # Draws gender icons.
    #---------------------------------------------------------------------------
    case species_data.gender_ratio
    when :AlwaysMale   then gender = [1, 0]
    when :AlwaysFemale then gender = [0, 1]
    when :Genderless   then gender = [0, 0]
    else
      if owned && !gender_difference?(@form)
        gender = [1, 1]
      else
        gender = (@gender == 0) ? [1, 0] : [0, 1]
      end
    end
    imagepos.push(
      [path + "gender", 10, 48, 32 * gender[0], 0, 32, 32],
      [path + "gender", 44, 48, 32 * gender[1], 32, 32, 32]
    )

    #---------------------------------------------------------------------------
    # Draws the Pokémon sprites
    #---------------------------------------------------------------------------
    if owned
      # Only reload the large sprite when the viewed Pokémon/form changes.
      # Redrawing the selected button must not restart its animation/load.
      sprite_key = [@species, @form]
      if @data_pokemon_sprite_key != sprite_key
        datapokemon = Pokemon.new(@species, 1, $player, false, false)
        datapokemon.forced_form = @form
        @sprites["datapokemon"].setPokemonBitmap(datapokemon)
        @data_pokemon_sprite_key = sprite_key
      end
      @sprites["datapokemon"].visible = true
      @sprites["movespokemonicon"].pbSetParams(@species, @gender, @form)

      # Place the small species icon immediately to the right of the name.
      name_width = overlay.text_size(species_data.name).width
      @sprites["movespokemonicon"].x = 114 + name_width + 30
      @sprites["movespokemonicon"].y = 65
      @sprites["movespokemonicon"].visible = true
    else
      @sprites["datapokemon"].visible = false
      @sprites["movespokemonicon"].visible = false
    end

    #---------------------------------------------------------------------------
    # Draws the base stats, their values and their colour bars.
    #---------------------------------------------------------------------------
    stats_order = [:HP, :ATTACK, :DEFENSE, :SPECIAL_ATTACK, :SPECIAL_DEFENSE, :SPEED]
    stat_names = ["HP", "Attack", "Defense", "Sp. Atk", "Sp. Def", "Speed"]
    stats_order.each_with_index do |stat_id, i|
      y = 104 + i * 28
      textpos.push([_INTL(stat_names[i]), 12, y, :left, base, shadow, :outline])
      if owned
        stat = species_data.base_stats[stat_id]
        textpos.push([_INTL("{1}", stat), 155, y, :right, base, shadow, :outline])

        # Six colour ranges covering the complete 1-255 stat range.
        colour_row = pbStatColourRow(stat)
        width = (stat * 145 / 255.0).round
        width = 1 if width < 1
        imagepos.push([path + "overlay_stats", 170, 105 + i * 28,
                       0, colour_row * 18, width, 18])
      end
    end

    # Total is displayed below Speed, with a little extra spacing.
    if owned
      textpos.push(
        [_INTL("Total"), 12, 291, :left, base, shadow, :outline],
        [_INTL("{1}", species_data.base_stat_total), 155, 291, :right, base, shadow, :outline]
      )
    end

    #---------------------------------------------------------------------------
    # Draws the three vertically stacked buttons.
    #---------------------------------------------------------------------------
    buttons = [
      [:ability, _INTL("Abilities"), 222],
      [:moves,   _INTL("Moves"),     274],
      [:item,    _INTL("Items"),     326]
    ]
    buttons.each do |cursor, label, y|
      if @data_page_menu_active && @cursor == cursor
        # Dedicated selector frame sized to the button area.
        imagepos.push([path + "data_selector", 321, y - 2, 0, 0, 185, 56])
      end
      textpos.push([label, 414, y + 17, :center, base, shadow, :outline])
    end

    pbDrawImagePositions(overlay, imagepos)
    pbDrawTextPositions(overlay, textpos)
  end

  #-----------------------------------------------------------------------------
  # Returns the row in overlay_stats corresponding to the stat value.
  # Six equal colour ranges are used for values from 1 to 255:
  # red -> orange -> yellow -> light green -> dark green -> blue.
  #-----------------------------------------------------------------------------
  def pbStatColourRow(stat)
    return 0 if stat <= 49
    return 1 if stat <= 74
    return 2 if stat <= 99
    return 3 if stat <= 119
    return 4 if stat <= 149
    return 5
  end
end
