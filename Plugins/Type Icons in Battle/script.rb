#-------------------------------------------------------------------------------
# Config Options
#-------------------------------------------------------------------------------
class Battle::Scene::PokemonDataBox

  # Set this to certain values to draw the icons at different positions
  # 0 - Draw above the databox
  # 1 - Draw below the databox
  # 2 - Draw at the side of the databox
  TYPE_ICONS_POSITION = 2

  # Position des types avec 2 types
  PLAYER_TYPES_Y_2   = 4
  OPPONENT_TYPES_Y_2 = 2

  # Position des types avec 1 seul type
  PLAYER_TYPES_Y_1   = 15
  OPPONENT_TYPES_Y_1 = 10

end

#-------------------------------------------------------------------------------
# Main Script
#-------------------------------------------------------------------------------
class Battle::Scene::PokemonDataBox

  alias __types__initializeOtherGraphics initializeOtherGraphics unless method_defined?(:__types__initializeOtherGraphics)
  def initializeOtherGraphics(*args)
    @types_bitmap = AnimatedBitmap.new("Graphics/UI/Battle/icon_types")
    @types_sprite = Sprite.new(viewport)

    height = @types_bitmap.height / GameData::Type.count
    @types_x = 0
    @types_y = 0

    case TYPE_ICONS_POSITION
    when 2
      height = @databoxBitmap.height
      @types_x = (@battler.opposes?(0)) ? @databoxBitmap.width - @types_bitmap.width : 0
      @types_y = 4

    when 1
      height = @types_bitmap.height / GameData::Type.count
      @types_x = (@battler.opposes?(0)) ? 24 : 40
      @types_y = @databoxBitmap.height

    when 0
      height = @types_bitmap.height / GameData::Type.count
      @types_x = (@battler.opposes?(0)) ? 24 : 40
      @types_y = -height
    end

    @types_sprite.bitmap = Bitmap.new(
      [@databoxBitmap.width - @types_x, @types_bitmap.width * 2].max,
      height
    )

    @sprites["types_sprite"] = @types_sprite

    __types__initializeOtherGraphics(*args)
  end

  alias __types__dispose dispose unless method_defined?(:__types__dispose)
  def dispose(*args)
    __types__dispose(*args)
    @types_bitmap.dispose
  end

alias __types__set_x x= unless method_defined?(:__types__set_x)
def x=(value)
  __types__set_x(value)

  if !@battler.opposes?(0)
    # Joueur
    if @battler.battle.pbSideSize(0) >= 2 && @battler.pbTypes.length >= 2
      # Combat double + 2 types : position normale
      @types_sprite.x = value + @types_x
    else
      # Tous les autres cas joueur : +22 px
      @types_sprite.x = value + @types_x + 22
    end
  else
    # Ennemi : toujours position normale
    @types_sprite.x = value + @types_x
  end
end

  alias __types__set_y y= unless method_defined?(:__types__set_y)
  def y=(value)
    __types__set_y(value)
    @types_sprite.y = value + @types_y
  end

  alias __types__set_z z= unless method_defined?(:__types__set_z)
  def z=(value)
    __types__set_z(value)
    @types_sprite.z = value - 1
  end

  alias __databox__refresh refresh unless method_defined?(:__databox__refresh)
  def refresh
    self.bitmap.clear
    return if !@battler.pokemon
    __databox__refresh
    draw_type_icons
  end

  #---------------------------------------------------------------------------
  # Vérifie si le combat est un combat double
  #---------------------------------------------------------------------------
  def double_battle?
    return false if !@battler || !@battler.battle

    return @battler.battle.pbSideSize(0) >= 2 ||
           @battler.battle.pbSideSize(1) >= 2
  end

  #---------------------------------------------------------------------------
  # Draw type icons
  #---------------------------------------------------------------------------
  def draw_type_icons
    @types_sprite.bitmap.clear

    width  = @types_bitmap.width
    height = @types_bitmap.height / GameData::Type.count

    types = @battler.pbTypes.clone

    #---------------------------------------------------------------------------
    # Illusion
    #---------------------------------------------------------------------------
    if @battler.effects[PBEffects::Illusion]
      illusion_types = @battler.effects[PBEffects::Illusion].types
      base_types = @battler.pokemon.types

      base_types.each { |type| types.delete(type) }
      illusion_types.reverse.each { |type| types.insert(0, type) }
    end

    #---------------------------------------------------------------------------
    # Position verticale
    #---------------------------------------------------------------------------
    if TYPE_ICONS_POSITION == 2
      if types.length >= 2
        # Combat double + 2 types
        if double_battle?
          @types_y = if @battler.opposes?(0)
                       OPPONENT_TYPES_Y_1
                     else
                       PLAYER_TYPES_Y_1
                     end
        else
          # Combat simple + 2 types
          @types_y = if @battler.opposes?(0)
                       OPPONENT_TYPES_Y_2
                     else
                       PLAYER_TYPES_Y_2
                     end
        end
      else
        # Type unique
        @types_y = if @battler.opposes?(0)
                     OPPONENT_TYPES_Y_1
                   else
                     PLAYER_TYPES_Y_1
                   end
      end

      @types_sprite.y = self.y + @types_y
    end

    #---------------------------------------------------------------------------
    # Position horizontale spéciale pour :
    # Combat double + 2 types
    #
    # On utilise la position du type unique comme référence.
    #
    # Joueur :
    #   On décale le sprite de "width" afin que les deux icônes
    #   soient placées vers l'intérieur sans recouvrir la barre de vie.
    #
    # Adversaire :
    #   Les deux icônes sont placées côte à côte vers l'intérieur.
    #---------------------------------------------------------------------------
    if TYPE_ICONS_POSITION == 2 && types.length >= 2 && double_battle?
      if @battler.opposes?(0)
        # Adversaire
        @types_sprite.x = self.x + @types_x
      else
        # Joueur
        @types_sprite.x = self.x + @types_x
      end
    else
      # Position horizontale normale
      @types_sprite.x = self.x + @types_x
    end

    #---------------------------------------------------------------------------
    # Dessin des icônes
    #---------------------------------------------------------------------------
    types.each_with_index do |type, i|
      type_number = GameData::Type.get(type).icon_position

      type_rect = Rect.new(
        0,
        type_number * height,
        width,
        height
      )

      #-----------------------------------------------------------------------
      # Combat double + 2 types
      #
      # Les deux icônes sont affichées côte à côte.
      #-----------------------------------------------------------------------
      if TYPE_ICONS_POSITION == 2 && types.length >= 2 && double_battle?

        icon_x = width * i

        @types_sprite.bitmap.blt(
          icon_x,
          0,
          @types_bitmap.bitmap,
          type_rect
        )

      #-----------------------------------------------------------------------
      # Combat simple + 2 types
      #
      # Comportement actuel : les icônes restent superposées verticalement.
      #-----------------------------------------------------------------------
      elsif TYPE_ICONS_POSITION == 2

        @types_sprite.bitmap.blt(
          0,
          height * i,
          @types_bitmap.bitmap,
          type_rect
        )

      #-----------------------------------------------------------------------
      # Position au-dessus / en-dessous
      #-----------------------------------------------------------------------
      else

        @types_sprite.bitmap.blt(
          (width - 6) * i,
          0,
          @types_bitmap.bitmap,
          type_rect
        )

      end
    end
  end
end

#-------------------------------------------------------------------------------
# Battle::Battler
#-------------------------------------------------------------------------------
class Battle::Battler

  alias __types__pbChangeTypes pbChangeTypes unless method_defined?(:__types__pbChangeTypes)
  def pbChangeTypes(*args)
    ret = __types__pbChangeTypes(*args)

    @battle.scene.sprites["dataBox_#{self.index}"]&.refresh

    return ret
  end

  alias __types__pbEffectsOnMakingHit pbEffectsOnMakingHit unless method_defined?(:__types__pbEffectsOnMakingHit)
  def pbEffectsOnMakingHit(*args)
    ret = __types__pbEffectsOnMakingHit(*args)

    @battle.scene.sprites["dataBox_#{args[1]&.index || 0}"]&.refresh
    @battle.scene.sprites["dataBox_#{args[2]&.index || 0}"]&.refresh

    return ret
  end

end