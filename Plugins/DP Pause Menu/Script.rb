#===============================================================================
#                         Diamond/Pearl Pause Menu
#                 Pokémon Essentials v21.1 - Compatible version
#===============================================================================

#-------------------------------------------------------------------------------
# Configuration
#-------------------------------------------------------------------------------

DP_PAUSE_VISIBLE_OPTIONS = 8
DP_PAUSE_OPTION_HEIGHT   = 48

#===============================================================================
# SpriteHash
#===============================================================================

unless defined?(SpriteHash)
  class SpriteHash < Hash
    def visible=(value)
      @dp_previous_visibility ||= {}

      each_value do |sprite|
        next if !sprite || sprite.disposed?

        if value
          if @dp_previous_visibility.key?(sprite)
            sprite.visible = @dp_previous_visibility.delete(sprite)
          end
        else
          unless @dp_previous_visibility.key?(sprite)
            @dp_previous_visibility[sprite] = sprite.visible
          end
          sprite.visible = false
        end
      end
    end

    def dispose
      each_value do |sprite|
        next if !sprite || sprite.disposed?

        bitmap = sprite.bitmap
        sprite.dispose
        bitmap.dispose if bitmap && !bitmap.disposed?
      end
      clear
    end
  end
end

#===============================================================================
# Calls the Pause menu
#===============================================================================

def pbPauseMenu
  DP_PauseMenu.new
end

#===============================================================================
# Replaces the original pause menu
#===============================================================================

class Scene_Map
  def call_menu
    $game_temp.menu_calling = false
    $game_temp.in_menu = true
    $game_player.straighten
    $game_map.update
    pbPauseMenu
    $game_temp.in_menu = false
  end
end

#===============================================================================
# Stores the last selected option
#===============================================================================

class PokemonGlobalMetadata
  attr_accessor :last_menu_index
end

#===============================================================================
# DP Pause Menu
#===============================================================================

class DP_PauseMenu
  BaseColor    = Color.new(82, 82, 90)
  ShadowColor  = Color.new(165, 165, 173)
  OutlineColor = Color.new(0, 0, 0)

  VISIBLE_OPTIONS = DP_PAUSE_VISIBLE_OPTIONS
  OPTION_HEIGHT   = DP_PAUSE_OPTION_HEIGHT

  #---------------------------------------------------------------------------
  # Initialize
  #---------------------------------------------------------------------------

  def initialize
    @options = []

    # Retire: Safari
    if pbInSafari?
      @options << ["RETIRE", "retireA", "retireB", proc {
        if pbConfirmMessage(
          _INTL("Would you like to leave the Safari Game right now?")
        )
          @done = true
          pbSafariState.decision = 1
          pbSafariState.pbGoToStart
        end
      }]
    end

    # Retire: Bug-Catching Contest
    if pbInBugContest?
      @options << [_INTL("Retire"), "retireA", "retireB", proc {
        if pbConfirmMessage(_INTL("Would you like to end the Contest now?"))
          @done = true
          pbBugContestState.pbStartJudging
        end
      }]
    end

    # Pokédex
    if $player.has_pokedex
      @options << [_INTL("Pokédex"), "pokedexA", "pokedexB", proc {
        pbFadeOutIn do
          scene = nil
          screen = nil

          if Settings::USE_CURRENT_REGION_DEX
            scene = PokemonPokedex_Scene.new
            screen = PokemonPokedexScreen.new(scene)
          elsif $player.pokedex.accessible_dexes.length == 1
            $PokemonGlobal.pokedexDex =
              $player.pokedex.accessible_dexes[0]
            scene = PokemonPokedex_Scene.new
            screen = PokemonPokedexScreen.new(scene)
          else
            scene = PokemonPokedexMenu_Scene.new
            screen = PokemonPokedexMenuScreen.new(scene)
          end

          screen.pbStartScreen
        end
      }]
    end

    # Pokémon
    if $player.party.size > 0
      @options << [_INTL("Pokémon"), "pokemonA", "pokemonB", proc {
        hiddenmove = nil

        pbFadeOutIn do
          scene = PokemonParty_Scene.new
          screen = PokemonPartyScreen.new(scene, $player.party)
          hiddenmove = screen.pbPokemonScreen
        end

        if hiddenmove
          @done = true
          $game_temp.in_menu = false
          Kernel.pbUseHiddenMove(hiddenmove[0], hiddenmove[1])
        end
      }]
    end

    # Bag
    unless pbInBugContest?
      @options << [_INTL("Bag"), "bagA", ["bagBm", "bagBf"], proc {
        item = 0

        pbFadeOutIn do
          scene = PokemonBag_Scene.new
          screen = PokemonBagScreen.new(scene, $bag)
          item = screen.pbStartScreen
        end

        next false if !item

        $game_temp.in_menu = false
        pbUseKeyItemInField(item)
        next true
      }]
    end

    # Town Map
    if !$player.has_pokegear && $bag.has?(:TOWNMAP)
      @options << [_INTL("Map"), "townMapA", "townMapB", proc {
        pbFadeOutIn do
          scene = PokemonRegionMap_Scene.new(-1, false)
          screen = PokemonRegionMapScreen.new(scene)
          screen.pbStartScreen

          @done = true if $game_temp.fly_destination
        end

        next pbFlyToNewLocation
      }]
    end

    # Encounter List UI - immediately after Town Map
    if defined?(pbViewEncounters)
      @options << ["Poké radar", "encountersA", "encountersB", proc {
        pbFadeOutIn do
          pbViewEncounters
        end
      }]
    end

    # Trainer Card
    @options << [$player.name, "PlayercardA", "PlayercardB", proc {
      pbFadeOutIn do
        scene = PokemonTrainerCard_Scene.new
        screen = PokemonTrainerCardScreen.new(scene)
        screen.pbStartScreen
      end
    }]

    # Save Game - accessed with the SPECIAL action key.
    @save_option = [
      _INTL("Save"),
      "saveA",
      ["saveBm", "saveBf"],
      proc { executeSaveShortcut }
    ]

    # Options
    @options << [_INTL("Options"), "optionsA", "optionsB", proc {
      pbFadeOutIn do
        scene = PokemonOption_Scene.new
        screen = PokemonOptionScreen.new(scene)
        screen.pbStartScreen
        pbUpdateSceneMap
      end
    }]

    #---------------------------------------------------------------------------
    # Initialize menu state
    #---------------------------------------------------------------------------

    @count = @options.length
    return if @count == 0

    $PokemonGlobal.last_menu_index ||= 0

    @option = $PokemonGlobal.last_menu_index
    @option = 0 if @option < 0 || @option >= @count

    @done = false
    @top_index = 0

    screen_capacity = [(Graphics.height - 32) / OPTION_HEIGHT, 1].max
    @visible_count = [
      @count,
      VISIBLE_OPTIONS,
      screen_capacity
    ].min

    updateScrollPosition
    createSprites

    pbSEPlay("GUI menu open")
    main
  end

  #---------------------------------------------------------------------------
  # Load a bitmap from Graphics/UI/DP Pause Menu
  #---------------------------------------------------------------------------

  def loadMenuBitmap(name)
    path = "Graphics/UI/DP Pause Menu/#{name}"
    path += ".png" unless path.downcase.end_with?(".png")
    return Bitmap.new(path)
  end

  #---------------------------------------------------------------------------
  # Get the icon path
  #---------------------------------------------------------------------------

  def getIconPath(option)
    path = option[2]
    path = path[$player.gender] if path.is_a?(Array)

    if option[0] == "ENCOUNTERS"
      full_path = "Graphics/UI/DP Pause Menu/#{path}.png"
      path = "optionsB" unless File.exist?(full_path)
    end

    return path
  end

  #---------------------------------------------------------------------------
  # Get the current map/area name
  #---------------------------------------------------------------------------

  def getCurrentAreaName
    map_id = $game_map.map_id

    if defined?(pbGetMapNameFromId)
      name = pbGetMapNameFromId(map_id)
      return name if name && !name.empty?
    end

    if defined?(GameData::MapMetadata)
      metadata = GameData::MapMetadata.try_get(map_id)
      if metadata && metadata.respond_to?(:name)
        name = metadata.name
        return name if name && !name.empty?
      end
    end

    if defined?($map_factory) && $map_factory &&
       $map_factory.respond_to?(:getMapNameFromId)
      name = $map_factory.getMapNameFromId(map_id)
      return name if name && !name.empty?
    end

    if $game_map.respond_to?(:name)
      name = $game_map.name
      return name if name && !name.empty?
    end

    return ""
  end

  #---------------------------------------------------------------------------
  # Creates menu sprites
  #---------------------------------------------------------------------------

  def createSprites
    viewport_x = Graphics.width - 204
    viewport_y = 4

    viewport_height = [
      24 + OPTION_HEIGHT * @visible_count,
      Graphics.height - viewport_y
    ].min

    @viewport = Viewport.new(
      viewport_x,
      viewport_y,
      200,
      viewport_height
    )
    @viewport.z = 99999

    @sprites = SpriteHash.new

    # Top background
    @sprites["bgTop"] = Sprite.new(@viewport)
    @sprites["bgTop"].bitmap = loadMenuBitmap("bgTop")
    @sprites["bgTop"].z = 0

    # Middle background
    @sprites["bgMid"] = Sprite.new(@viewport)
    @sprites["bgMid"].bitmap = loadMenuBitmap("bgMid")
    @sprites["bgMid"].y = 12
    @sprites["bgMid"].z = 0

    mid_bitmap = @sprites["bgMid"].bitmap
    if mid_bitmap.height > 0
      @sprites["bgMid"].zoom_y =
        (OPTION_HEIGHT * @visible_count).to_f / mid_bitmap.height
    end

    # Bottom background
    @sprites["bgBtm"] = Sprite.new(@viewport)
    @sprites["bgBtm"].bitmap = loadMenuBitmap("bgBtm")
    @sprites["bgBtm"].y = 12 + OPTION_HEIGHT * @visible_count
    @sprites["bgBtm"].z = 0

    # Selection indicator
    @sprites["sel"] = Sprite.new(@viewport)
    @sprites["sel"].bitmap = loadMenuBitmap("selector")
    @sprites["sel"].z = 1

    # Text bitmap
    @sprites["txt"] = Sprite.new(@viewport)
    @sprites["txt"].bitmap = Bitmap.new(200, viewport_height)
    @sprites["txt"].z = 2

    # Option icons
    @options.each_with_index do |option, i|
      @sprites["option_#{i}"] = Sprite.new(@viewport)
      @sprites["option_#{i}"].z = 3
    end

    # Animated scroll arrows: 8 frames, each 28x40 pixels.
    @sprites["uparrow"] = AnimatedSprite.new(
      "Graphics/UI/up_arrow", 8, 28, 40, 2, @viewport
    )
    @sprites["uparrow"].x = 164
    @sprites["uparrow"].y = 0
    @sprites["uparrow"].visible = false
    @sprites["uparrow"].play

    @sprites["downarrow"] = AnimatedSprite.new(
      "Graphics/UI/down_arrow", 8, 28, 40, 2, @viewport
    )
    @sprites["downarrow"].x = 164
    @sprites["downarrow"].y = @viewport.rect.height - 40
    @sprites["downarrow"].visible = false
    @sprites["downarrow"].play

    # Area name viewport
    @area_viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
    @area_viewport.z = 100002

    @sprites["area_text"] = Sprite.new(@area_viewport)
    @sprites["area_text"].bitmap = Bitmap.new(Graphics.width, 32)
    @sprites["area_text"].z = 1
    @sprites["area_text"].x = 0
    @sprites["area_text"].y = 4

    # Save shortcut panel, including the leaf image above it.
    createSaveShortcutSprites

    refreshAreaName
    refreshMenu
  end

  #---------------------------------------------------------------------------
  # Creates the separate Save shortcut at the bottom-left
  #---------------------------------------------------------------------------

  def createSaveShortcutSprites
    @save_viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
    @save_viewport.z = 100001

    x = 5
    y = Graphics.height - 93

    # Leaf image: its bottom edge is aligned with the top of the Save panel.
    @sprites["save_leaf"] = Sprite.new(@save_viewport)
    @sprites["save_leaf"].bitmap = loadMenuBitmap("leaf")
    @sprites["save_leaf"].x = x
    @sprites["save_leaf"].y = y - @sprites["save_leaf"].bitmap.height
    @sprites["save_leaf"].z = 1

    # Top background
    @sprites["save_bgTop"] = Sprite.new(@save_viewport)
    @sprites["save_bgTop"].bitmap = loadMenuBitmap("bgTop")
    @sprites["save_bgTop"].x = x
    @sprites["save_bgTop"].y = y
    @sprites["save_bgTop"].z = 0
    @sprites["save_bgTop"].zoom_x =
      200.0 / [@sprites["save_bgTop"].bitmap.width, 1].max
    @sprites["save_bgTop"].zoom_y =
      12.0 / [@sprites["save_bgTop"].bitmap.height, 1].max

    # Middle background
    @sprites["save_bgMid"] = Sprite.new(@save_viewport)
    @sprites["save_bgMid"].bitmap = loadMenuBitmap("bgMid")
    @sprites["save_bgMid"].x = x
    @sprites["save_bgMid"].y = y + 12
    @sprites["save_bgMid"].z = 0
    @sprites["save_bgMid"].zoom_x =
      200.0 / [@sprites["save_bgMid"].bitmap.width, 1].max
    @sprites["save_bgMid"].zoom_y =
      48.0 / [@sprites["save_bgMid"].bitmap.height, 1].max

    # Bottom background
    @sprites["save_bgBtm"] = Sprite.new(@save_viewport)
    @sprites["save_bgBtm"].bitmap = loadMenuBitmap("bgBtm")
    @sprites["save_bgBtm"].x = x
    @sprites["save_bgBtm"].y = y + 60
    @sprites["save_bgBtm"].z = 0
    @sprites["save_bgBtm"].zoom_x =
      200.0 / [@sprites["save_bgBtm"].bitmap.width, 1].max
    @sprites["save_bgBtm"].zoom_y =
      12.0 / [@sprites["save_bgBtm"].bitmap.height, 1].max

    # Save icon
    @sprites["save_icon"] = Sprite.new(@save_viewport)
    @sprites["save_icon"].bitmap = loadMenuBitmap(getIconPath(@save_option))
    @sprites["save_icon"].ox = @sprites["save_icon"].bitmap.width / 2
    @sprites["save_icon"].oy = @sprites["save_icon"].bitmap.height / 2
    @sprites["save_icon"].x = x + 38
    @sprites["save_icon"].y = y + 36
    @sprites["save_icon"].z = 3

    # Save label
    @sprites["save_text"] = Sprite.new(@save_viewport)
    @sprites["save_text"].bitmap = Bitmap.new(150, 48)
    @sprites["save_text"].x = x + 66
    @sprites["save_text"].y = y + 12
    @sprites["save_text"].z = 3

    bitmap = @sprites["save_text"].bitmap
    pbSetSystemFont(bitmap)
    pbDrawTextPositions(bitmap, [[
      _INTL("[D] ") + _INTL("Save"),
      0,
      13,
      0,
      BaseColor,
      ShadowColor
    ]])
  end

  #---------------------------------------------------------------------------
  # Shows or hides every pause menu element together
  #---------------------------------------------------------------------------

  def setMenuVisibility(value)
    @sprites.visible = value if @sprites

    if @viewport && !@viewport.disposed?
      @viewport.visible = value
    end

    if @save_viewport && !@save_viewport.disposed?
      @save_viewport.visible = value
    end

    if @area_viewport && !@area_viewport.disposed?
      @area_viewport.visible = value
    end
  end

  #---------------------------------------------------------------------------
  # Draws the current area name with a black outline
  #---------------------------------------------------------------------------

  def refreshAreaName
    sprite = @sprites["area_text"]
    return if !sprite || sprite.disposed?

    bitmap = sprite.bitmap
    bitmap.clear
    pbSetSystemFont(bitmap)

    area_name = getCurrentAreaName
    return if area_name == ""

    text_x = Graphics.width / 8
    text_y = 3

    pbDrawTextPositions(bitmap, [[
      area_name,
      text_x,
      text_y,
      2,
      Color.new(248, 248, 248),
      OutlineColor,
      :outline
    ]])
  end

  #---------------------------------------------------------------------------
  # Redraws menu text, icons, selector and scroll arrows
  #---------------------------------------------------------------------------

  def refreshMenu
    return if !@sprites

    text_bitmap = @sprites["txt"].bitmap
    text_bitmap.clear
    pbSetSystemFont(text_bitmap)

    textpos = []

    @options.each_with_index do |option, i|
      row = i - @top_index
      next if row < 0 || row >= @visible_count

      textpos << [
        option[0],
        72,
        26 + OPTION_HEIGHT * row,
        0,
        BaseColor,
        ShadowColor
      ]
    end

    pbDrawTextPositions(text_bitmap, textpos) if !textpos.empty?

    # Icons are always colored and do not animate when selected.
    @options.each_with_index do |option, i|
      sprite = @sprites["option_#{i}"]
      row = i - @top_index

      if row < 0 || row >= @visible_count
        sprite.visible = false
        next
      end

      sprite.visible = true

      unless sprite.instance_variable_get(:@dp_icon_loaded)
        sprite.bitmap = loadMenuBitmap(getIconPath(option))
        sprite.ox = sprite.bitmap.width / 2
        sprite.oy = sprite.bitmap.height / 2
        sprite.instance_variable_set(:@dp_icon_loaded, true)
      end

      sprite.x = 39
      sprite.y = 36 + OPTION_HEIGHT * row
      sprite.angle = 0
      sprite.zoom_x = 1.0
      sprite.zoom_y = 1.0
    end

    # Selector position
    @sprites["sel"].visible = true
    @sprites["sel"].x = 8
    @sprites["sel"].y =
      10 + OPTION_HEIGHT * (@option - @top_index)

    # Scroll arrows
    @sprites["uparrow"].visible = (@top_index > 0)
    @sprites["downarrow"].visible =
      (@top_index + @visible_count < @count)

    @sprites["downarrow"].y = @viewport.rect.height - 40
  end

  #---------------------------------------------------------------------------
  # Calculates the scroll position
  #---------------------------------------------------------------------------

  def updateScrollPosition
    return if !@visible_count || @visible_count <= 0

    if @option < @top_index
      @top_index = @option
    elsif @option >= @top_index + @visible_count
      @top_index = @option - @visible_count + 1
    end

    max_top = [@count - @visible_count, 0].max
    @top_index = [[@top_index, 0].max, max_top].min
  end

  #---------------------------------------------------------------------------
  # Checks whether the SPECIAL action key was pressed
  #---------------------------------------------------------------------------

  def specialActionTriggered?
    return Input.trigger?(Input::SPECIAL) if defined?(Input::SPECIAL)
    return Input.trigger?(Input::AUX3) if defined?(Input::AUX3)
    return false
  end

  #---------------------------------------------------------------------------
  # Opens the Save screen without adding SAVE to the main list
  #---------------------------------------------------------------------------

  def executeSaveShortcut
    return if @done
    return if !$game_system || $game_system.save_disabled
    return if pbInSafari? || pbInBugContest?

    setMenuVisibility(false)

    pbFadeOutIn do
      if PluginManager.installed?("HGSS Multi-Save")
        if UI::Save.new.main
          @done = true
        end
      else
        scene = PokemonSave_Scene.new
        screen = PokemonSaveScreen.new(scene)

        if screen.pbSaveScreen
          @done = true
        end
      end
    end

    unless @done
      setMenuVisibility(true)
      refreshAreaName
      refreshMenu
    end
  end

  #---------------------------------------------------------------------------
  # Updates the animated arrows
  #---------------------------------------------------------------------------

  def updateAnimatedArrows
    ["uparrow", "downarrow"].each do |key|
      sprite = @sprites[key]
      next if !sprite || sprite.disposed? || !sprite.visible
      sprite.update if sprite.respond_to?(:update)
    end
  end

  #---------------------------------------------------------------------------
  # Main menu loop
  #---------------------------------------------------------------------------

  def main
    loop do
      Graphics.update
      Input.update
      pbUpdateSceneMap
      updateAnimatedArrows

      changed = false

      # Keyboard navigation
      if Input.repeat?(Input::DOWN)
        @option += 1
        @option = 0 if @option >= @count
        changed = true
      elsif Input.repeat?(Input::UP)
        @option -= 1
        @option = @count - 1 if @option < 0
        changed = true
      end

      # Mouse navigation
      if $mouse
        (0...@visible_count).each do |row|
          index = @top_index + row
          next if index >= @count

          mouse_x = Graphics.width - 204
          mouse_y = 4 + 10 + OPTION_HEIGHT * row

          if $mouse.inArea?(mouse_x, mouse_y, 200, OPTION_HEIGHT)
            if index != @option
              @option = index
              changed = true
            end
          end
        end
      end

      # Mouse confirmation
      confirmed = false

      if $mouse
        mouse_x = Graphics.width - 204
        mouse_y = 4

        confirmed = (
          $mouse.x >= mouse_x &&
          $mouse.x <= mouse_x + 200 &&
          $mouse.y >= mouse_y + 10 &&
          $mouse.y < mouse_y + 10 + OPTION_HEIGHT * @visible_count &&
          $mouse.click?
        )
      end

      confirmed = true if Input.trigger?(Input::C)

      # Save shortcut: SPECIAL (D by default).
      if specialActionTriggered?
        executeSaveShortcut
        Input.update
      end

      # Update selection and scrolling.
      if changed
        pbPlayCursorSE
        $PokemonGlobal.last_menu_index = @option

        updateScrollPosition
        refreshMenu
      end

      # Execute selected option.
      if confirmed && !@done
        pbPlayDecisionSE

        # Hide the entire pause menu before opening any selected submenu.
        setMenuVisibility(false)

        @options[@option][3].call
        Input.update

        # Restore the main menu only if the action did not close it.
        unless @done
          setMenuVisibility(true)
          refreshAreaName
          refreshMenu
        end
      end

      break if @done

      if Input.trigger?(Input::B)
        pbPlayCancelSE
        break
      end
    end

    dispose
  end

  #---------------------------------------------------------------------------
  # Dispose
  #---------------------------------------------------------------------------

  def dispose
    @sprites.dispose if @sprites

    if @viewport && !@viewport.disposed?
      @viewport.dispose
    end

    if @area_viewport && !@area_viewport.disposed?
      @area_viewport.dispose
    end

    if @save_viewport && !@save_viewport.disposed?
      @save_viewport.dispose
    end

    Input.update
  end
end