#===============================================================================
# Scene class for handling appearance of the screen
#===============================================================================
class MoveRelearner_Scene
  VISIBLEMOVES = 4

  def pbDisplay(msg, brief = false)
    UIHelper.pbDisplay(@sprites["msgwindow"], msg, brief) { pbUpdate }
  end

  def pbConfirm(msg)
    UIHelper.pbConfirm(@sprites["msgwindow"], msg) { pbUpdate }
  end

  def pbUpdate
    pbUpdateSpriteHash(@sprites)
  end

  def pbStartScene(pokemon, moves)
    @pokemon = pokemon
    @moves = moves
    moveCommands = []
    moves.each { |m| moveCommands.push(GameData::Move.get(m).name) }
    # Create sprite hash
    @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
    @viewport.z = 99999
    @sprites = {}
    addBackgroundPlane(@sprites, "bg", "Move Reminder/bg", @viewport)
    @sprites["pokeicon"] = PokemonIconSprite.new(@pokemon, @viewport)
    @sprites["pokeicon"].setOffset(PictureOrigin::CENTER)
    @sprites["pokeicon"].x = 300
    @sprites["pokeicon"].y = 70
    @sprites["overlay"] = BitmapSprite.new(Graphics.width, Graphics.height, @viewport)
    pbSetSystemFont(@sprites["overlay"].bitmap)
    @sprites["commands"] = Window_CommandPokemon.new(moveCommands, 32)
    @sprites["commands"].height = 32 * (VISIBLEMOVES + 1)
    @sprites["commands"].visible = false
    @sprites["msgwindow"] = Window_AdvancedTextPokemon.new("")
    @sprites["msgwindow"].visible = false
    @sprites["msgwindow"].viewport = @viewport
    @typebitmap = AnimatedBitmap.new(_INTL("Graphics/UI/types_mini"))
    pbDrawMoveList
    pbDeactivateWindows(@sprites)
    # Fade in all sprites
    pbFadeInAndShow(@sprites) { pbUpdate }
  end

  def pbDrawMoveList
    overlay = @sprites["overlay"].bitmap
    overlay.clear
    @pokemon.types.each_with_index do |type, i|
      type_number = GameData::Type.get(type).icon_position
      type_rect = Rect.new(0, type_number * 28, 24, 28)
      diff = PluginManager.installed?("[DBK] Terastallization") && @pokemon.tera_type ? 36 : 0
      type_x = (@pokemon.types.length == 1) ? 474 : 446 + (28 * i)
      overlay.blt(type_x - diff, 68, @typebitmap.bitmap, type_rect)
    end
    textpos = [
      [_INTL("Teach which move?"), 16, 38, :left, Color.new(248, 248, 248), Color.new(70, 70, 70)],
      [@pokemon.name, 336, 38, :left, Color.new(64, 64, 64), Color.new(162, 162, 162)]
    ]
    imagepos = []
    if @pokemon.male?
      imagepos.push(["Graphics/UI/Summary/icon_genders", 336, 68, 0, 0, 22, 22])
    elsif @pokemon.female?
      imagepos.push(["Graphics/UI/Summary/icon_genders", 336, 68, 22, 0, 22, 22])
    end
    yPos = 72
    VISIBLEMOVES.times do |i|
      moveobject = @moves[@sprites["commands"].top_item + i]
      if moveobject
        moveData = GameData::Move.get(moveobject)
        type_number = GameData::Type.get(moveData.display_type(@pokemon)).icon_position
        imagepos.push([_INTL("Graphics/UI/types_mini"), 16, yPos - 2, 0, type_number * 28, 24, 28])
        textpos.push([moveData.name, 44, yPos, :left, Color.new(248, 248, 248), Color.new(70, 70, 70)])
        textpos.push([_INTL("PP"), 124, yPos + 32, :left, Color.new(248, 248, 248), Color.new(70, 70, 70)])
        if moveData.total_pp > 0
          textpos.push([moveData.total_pp.to_s + "/" + moveData.total_pp.to_s, 242, yPos + 32, :right,
                        Color.new(248, 248, 248), Color.new(70, 70, 70)])
        else
          textpos.push(["--", 242, yPos + 32, :right, Color.new(248, 248, 248), Color.new(70, 70, 70)])
        end
      end
      yPos += 64
    end
    imagepos.push(["Graphics/UI/Move Reminder/cursor",
                   14, 66 + ((@sprites["commands"].index - @sprites["commands"].top_item) * 64)])
    selMoveData = GameData::Move.get(@moves[@sprites["commands"].index])
    power = selMoveData.display_damage(@pokemon)
    category = selMoveData.display_category(@pokemon)
    accuracy = selMoveData.display_accuracy(@pokemon)
    textpos.push([_INTL("Category"), 268, 102, :left, Color.new(64, 64, 64), Color.new(162, 162, 162)])
    textpos.push([_INTL("Power"), 268, 134, :left, Color.new(64, 64, 64), Color.new(162, 162, 162)])
    textpos.push([power <= 1 ? power == 1 ? "???" : "---" : power.to_s, 498, 134, :right,
                  Color.new(64, 64, 64), Color.new(162, 162, 162)])
    textpos.push([_INTL("Accuracy"), 268, 166, :left, Color.new(64, 64, 64), Color.new(162, 162, 162)])
    textpos.push([accuracy == 0 ? "---" : "#{accuracy}%", 498, 166, :right,
                  Color.new(64, 64, 64), Color.new(162, 162, 162)])
    pbDrawTextPositions(overlay, textpos)
    imagepos.push(["Graphics/UI/category", 434, 98, 0, category * 28, 64, 28])
    if @sprites["commands"].index < @moves.length - 1
      imagepos.push(["Graphics/UI/Move Reminder/buttons", 228, 332, 0, 0, 20, 20])
    end
    if @sprites["commands"].index > 0
      imagepos.push(["Graphics/UI/Move Reminder/buttons", 228, 36, 20, 0, 20, 20])
    end
    pbDrawImagePositions(overlay, imagepos)
    drawTextEx(overlay, 268, 200, 230, 5, selMoveData.description,
               Color.new(64, 64, 64), Color.new(162, 162, 162))
  end

  # Processes the scene
  def pbChooseMove
    oldcmd = -1
    pbActivateWindow(@sprites, "commands") do
      loop do
        oldcmd = @sprites["commands"].index
        Graphics.update
        Input.update
        pbUpdate
        if @sprites["commands"].index != oldcmd
          pbDrawMoveList
        end
        if Input.trigger?(Input::BACK)
          return nil
        elsif Input.trigger?(Input::USE)
          return @moves[@sprites["commands"].index]
        end
      end
    end
  end

  # End the scene here
  def pbEndScene
    pbFadeOutAndHide(@sprites) { pbUpdate }
    pbDisposeSpriteHash(@sprites)
    @typebitmap.dispose
    @viewport.dispose
  end
end