#===============================================================================
# Settings.
#===============================================================================
module Settings
  #-----------------------------------------------------------------------------
  # Graphics path
  #-----------------------------------------------------------------------------
  POKEDEX_DATA_PAGE_GRAPHICS_PATH = "Graphics/Plugins/Pokedex Data Page/"

  #-----------------------------------------------------------------------------
  # Switch used to unlock the Data page.
  #-----------------------------------------------------------------------------
  POKEDEX_DATA_PAGE_SWITCH = 60
end

#===============================================================================
# Menu handler for the Pokedex Data page.
#===============================================================================
UIHandlers.add(:pokedex, :page_data, {
  "name"      => "DATA",
  "suffix"    => "data",
  "order"     => 40,
  "condition" => proc { next $game_switches[Settings::POKEDEX_DATA_PAGE_SWITCH] },
  "layout"    => proc { |species, scene| scene.drawPageData }
})

#===============================================================================
# Utilities required by the custom Data page.
#===============================================================================
class PokemonPokedexInfo_Scene
  #-----------------------------------------------------------------------------
  # Text colors used by the Data page menus.
  #-----------------------------------------------------------------------------
  DATA_TEXT_TAGS = [
    shadowc3tag(Color.new(56, 56, 56),  Color.new(184, 184, 184)), # Black
    shadowc3tag(Color.new(232, 32, 16), Color.new(248, 168, 184)), # Red
    shadowc3tag(Color.new(0, 112, 248), Color.new(120, 184, 232)), # Blue
    shadowc3tag(Color.new(96, 176, 72), Color.new(174, 208, 144))  # Green
  ]

  alias modular_pbStartScene pbStartScene
  def pbStartScene(*args)
    @cursor        = :ability
    @data_page_menu_active = false
    @data_hash     = {}
    @moveList      = []
    @moveCommands  = []
    @moveListIndex = 0
    @viewingMoves  = false
    @forceRefresh  = false

    if PluginManager.installed?("[DBK] Z-Power")
      @zcrystals = []
      GameData::Item.each { |item| @zcrystals.push(item) if item.is_zcrystal? }
    end
    if PluginManager.installed?("[DBK] Dynamax")
      @maxmoves = GameData::Move.get_generic_dynamax_moves
    end

    modular_pbStartScene(*args)

    @typebitmap2 = AnimatedBitmap.new(_INTL("Graphics/UI/types"))

    # Pokémon sprite displayed on the main Data page.
    @sprites["datapokemon"] = PokemonSprite.new(@viewport)
    @sprites["datapokemon"].setOffset(PictureOrigin::CENTER)
    @sprites["datapokemon"].x = 414
    @sprites["datapokemon"].y = 153
    @sprites["datapokemon"].zoom_x = 1
    @sprites["datapokemon"].zoom_y = 1
    @sprites["datapokemon"].visible = false

    @sprites["movespokemonicon"] = PokemonSpeciesIconSprite.new(nil, @viewport)
    @sprites["movespokemonicon"].setOffset(PictureOrigin::CENTER)
    @sprites["movespokemonicon"].visible = false

    @sprites["leftarrow"] = AnimatedSprite.new("Graphics/UI/left_arrow", 8, 40, 28, 2, @viewport)
    @sprites["leftarrow"].x = -2
    @sprites["leftarrow"].y = 46
    @sprites["leftarrow"].visible = false
    @sprites["leftarrow"].play

    @sprites["rightarrow"] = AnimatedSprite.new("Graphics/UI/right_arrow", 8, 40, 28, 2, @viewport)
    @sprites["rightarrow"].x = 220
    @sprites["rightarrow"].y = 46
    @sprites["rightarrow"].visible = false
    @sprites["rightarrow"].play

    @sprites["movecmds"] = Window_CommandPokemon.new(@moveCommands, 32)
    @sprites["movecmds"].height = 32 * 5
    @sprites["movecmds"].visible = false

    @sprites["data_overlay"] = BitmapSprite.new(Graphics.width, Graphics.height, @viewport)
    pbSetSystemFont(@sprites["data_overlay"].bitmap)
  end

  alias modular_pbEndScene pbEndScene
  def pbEndScene
    @sprites["datapokemon"]&.dispose if @sprites["datapokemon"] && !@sprites["datapokemon"].disposed?
    modular_pbEndScene
    @typebitmap2&.dispose
  end

  #-----------------------------------------------------------------------------
  # Keeps the Data page's special UI state isolated from the other Pokedex pages.
  # The standard message box is hidden only on the main Data page and restored
  # everywhere else. The custom Items/Abilities menus explicitly show it again.
  #-----------------------------------------------------------------------------
  alias modular_drawPage drawPage
  def drawPage(page)
    @data_page_active = false
    @sprites["datapokemon"].visible = false if @sprites["datapokemon"]
    @sprites["movespokemonicon"].visible = false if @sprites["movespokemonicon"]
    @sprites["data_overlay"].bitmap.clear if @sprites["data_overlay"]

    modular_drawPage(page)

    if @sprites["messagebox"]
      @sprites["messagebox"].visible = !@data_page_active
    end

    # drawPageData is responsible for showing the sprite again when the actual
    # Data page is rendered.
  end

  #-----------------------------------------------------------------------------
  # Allows a custom action on the Data page when USE is pressed.
  #-----------------------------------------------------------------------------
  alias modular_pbPageCustomUse pbPageCustomUse
  def pbPageCustomUse(page_id)
    if page_id == :page_data
      pbDataPageMenu
      return true
    end
    return modular_pbPageCustomUse(page_id)
  end

  #-----------------------------------------------------------------------------
  # Used by the main page to determine whether gender-specific sprites/forms are
  # different. Form support itself is retained because the Pokedex can still
  # display a species' currently selected form.
  #-----------------------------------------------------------------------------
  def gender_difference?(form)
    file1 = GameData::Species.front_sprite_filename(@species, form)
    file2 = GameData::Species.front_sprite_filename(@species, form, 1)
    return true if file1 != file2
    species_data = GameData::Species.get_species_form(@species, form)
    return [_INTL("Male"), _INTL("Female")].include?(species_data.form_name)
  end
end

#===============================================================================
# Fix for shiny icons appearing when they shouldn't be if you have any installed.
#===============================================================================
class PokemonSpeciesIconSprite < Sprite
  alias _shinyfix_initialize initialize
  def initialize(*args)
    _shinyfix_initialize(*args)
    @shiny = false
    refresh
  end
end
