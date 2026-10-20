#===============================================================================
# Handles the Abilities and Held Items sub menus of the Data page.
#===============================================================================
class PokemonPokedexInfo_Scene
  #-----------------------------------------------------------------------------
  # Controls for navigating text-based sub menus (Abilities/Items).
  #-----------------------------------------------------------------------------
  def pbChooseDataList(cursor = nil)
    return if !$player.owned?(@species)

    cursor = @cursor if !cursor
    list = []
    @data_hash[cursor].each { |_, values| list.concat(values) }

    pbPlayBuzzerSE if list.empty?
    return if list.empty?

    list.uniq!
    index = 0
    maxidx = list.length - 1

    # The description box is drawn on data_overlay so it sits above the main
    # Data-page buttons/stats instead of underneath the main overlay.
    @sprites["datapokemon"].visible = false
    pbSEPlay("GUI storage show party panel")
    pbDrawDataList(list, index, cursor)

    loop do
      Graphics.update
      Input.update
      pbUpdate
      dorefresh = false

      if Input.repeat?(Input::UP)
        if index > 0
          index -= 1
          dorefresh = true
        end
        pbPlayCursorSE if dorefresh

      elsif Input.repeat?(Input::DOWN)
        if index < maxidx
          index += 1
          dorefresh = true
        end
        pbPlayCursorSE if dorefresh

      elsif Input.trigger?(Input::BACK)
        pbSEPlay("GUI storage hide party panel")
        drawPage(@page)
        break

      elsif Input.trigger?(Input::USE)
        # Abilities and Items are information lists only.
        next
      end

      pbDrawDataList(list, index, cursor) if dorefresh
    end
  end

  #-----------------------------------------------------------------------------
  # Draws the Abilities/Items list and its description box.
  #-----------------------------------------------------------------------------
  def pbDrawDataList(list, index, cursor = nil)
    cursor = @cursor if !cursor
    data = (cursor == :item) ? GameData::Item : GameData::Ability
    return if list.empty?

    overlay = @sprites["data_overlay"].bitmap
    overlay.clear

    base = Color.new(248, 248, 248)
    shadow = Color.new(56, 56, 56)
    path = Settings::POKEDEX_DATA_PAGE_GRAPHICS_PATH
    textpos = []
    imagepos = [[path + "submenu", 0, 88, 0, 196, 512, 196]]
    @sprites["movespokemonicon"].pbSetParams(@species, @gender, @form)
    # Keep the small species icon just to the right of the Pokémon name.
    species_data = GameData::Species.get_species_form(@species, @form)
    name_width = @sprites["overlay"].bitmap.text_size(species_data.name).width
    @sprites["movespokemonicon"].x = 114 + name_width + 30
    @sprites["movespokemonicon"].y = 65
    @sprites["movespokemonicon"].visible = true

    case index
    when 0
      real_idx = 0
    when list.length - 1
      real_idx = [list.length - 1, 2].min
    else
      real_idx = 1
    end

    idx_start = (index > 1) ? index - 1 : 0
    if list.length - index > 1
      idx_end = idx_start + 2
    else
      idx_start = [list.length - 3, 0].max
      idx_end = list.length - 1
    end

    list[idx_start..idx_end].each_with_index do |id, i|
      idx = 0
      note = ""

      @data_hash[cursor].keys.each do |num|
        next if !@data_hash[cursor][num].include?(id)

        if cursor == :item
          note = case num
                 when 0 then "Common"
                 when 1 then "Uncommon"
                 when 2 then "Rare"
                 end
        else
          note = case num
                 when 0 then "Slot #{list.index(id) + 1}"
                 when 1 then "Hidden"
                 when 2 then "Special"
                 end
        end

        idx = num
        break if !nil_or_empty?(note)
      end

      case idx
      when 1
        imagepos.push([path + "submenu", 50, 104 + 42 * i, 0, 392, 412, 40])
      when 2
        imagepos.push([path + "submenu", 50, 104 + 42 * i, 0, 432, 412, 40])
      end

      textpos.push([
        sprintf("%d/%d", index + 1, list.length),
        115, 243, :center, base, shadow, :outline
      ])

      if id.is_a?(Symbol)
        textpos.push(
          [_INTL("{1}", note), 115, 114 + 42 * i, :center, base, shadow, :outline],
          [data.get(id).name, 326, 114 + 42 * i, :center, base, shadow, :outline]
        )
      else
        imagepos.push([path + "submenu", 98, 110 + 42 * i, 468, 392, 34, 28])
        textpos.push([
          id, 326, 114 + 42 * i, :center,
          base, Color.new(148, 148, 148), :outline
        ])
      end
    end

    imagepos.push([
      path + "cursor", 184, 98 + 42 * real_idx,
      0, 288, 284, 52
    ])

    imagepos.push([
      path + "page_cursor", 248, 236,
      0, 70, 76, 32
    ]) if index < list.length - 1

    imagepos.push([
      path + "page_cursor", 328, 236,
      76, 70, 76, 32
    ]) if index > 0

    # Draw the message box on the custom overlay. This places it above the
    # main Data-page overlay, hiding the buttons and Total stat underneath.
    imagepos.push([path + "messagebox", 0, Graphics.height - 100])

    pbDrawImagePositions(overlay, imagepos)
    pbDrawTextPositions(overlay, textpos)

    data_text = DATA_TEXT_TAGS[0] + data.get(list[index]).description
    drawFormattedTextEx(overlay, 34, 294, 446, _INTL("{1}", data_text))
  end
end
