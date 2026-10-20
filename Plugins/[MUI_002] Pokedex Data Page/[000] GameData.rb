#===============================================================================
# Data required by the custom Pokedex Data page.
#===============================================================================
module GameData
  class Species
    #---------------------------------------------------------------------------
    # Returns all tutor moves including special form moves used by this plugin.
    #---------------------------------------------------------------------------
    def get_tutor_moves
      case @id
      when :ROTOM_1     then moves = [:OVERHEAT]
      when :ROTOM_2     then moves = [:HYDROPUMP]
      when :ROTOM_3     then moves = [:BLIZZARD]
      when :ROTOM_4     then moves = [:AIRSLASH]
      when :ROTOM_5     then moves = [:LEAFSTORM]
      when :NECROZMA_1  then moves = [:SUNSTEELSTRIKE]
      when :NECROZMA_2  then moves = [:MOONGEISTBEAM]
      when :ZACIAN_1    then moves = [:BEHEMOTHBLADE]
      when :ZAMAZENTA_1 then moves = [:BEHEMOTHBASH]
      else                   moves = []
      end
      return (self.tutor_moves + moves).sort
    end

    #---------------------------------------------------------------------------
    # Returns all inherited moves including special inherited moves used by this
    # plugin.
    #---------------------------------------------------------------------------
    def get_inherited_moves
      case self.get_baby_species
      when :PICHU then moves = [:VOLTTACKLE]
      else             moves = []
      end
      return (self.get_egg_moves + moves).sort
    end
  end
end
