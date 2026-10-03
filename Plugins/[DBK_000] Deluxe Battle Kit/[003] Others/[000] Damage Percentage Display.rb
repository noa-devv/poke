#===============================================================================
#
# Deluxe Battle Kit - Damage Percentage Display
#
# Pokémon Essentials v21.1 / Deluxe Battle Kit
#
# Affiche le pourcentage des PV max retiré ou récupéré à chaque changement de PV.
# Compatible avec les attaques multi-coups.
#
#===============================================================================

#===============================================================================
# Damage Percentage Option
#===============================================================================

class PokemonSystem
  attr_accessor :damage_percentage

  alias dbk_damage_percentage_initialize initialize

  def initialize
    dbk_damage_percentage_initialize
    @damage_percentage = true
  end
end

MenuHandlers.add(:options_menu, :damage_percentage, {
  "name"        => _INTL("Damage Percentage"),
  "order"       => 40,
  "type"        => EnumOption,
  "parameters"  => [_INTL("On"), _INTL("Off")],
  "get_proc"    => proc {
    next $PokemonSystem.damage_percentage ? 0 : 1
  },
  "set_proc"    => proc { |value, _scene|
    $PokemonSystem.damage_percentage = (value == 0)
  }
})

module DBKDamagePercentage

  #=============================================================================
  # Configuration
  #=============================================================================

  # Nombre de décimales.
  DECIMAL_PLACES = 1

  # Durée d'affichage en frames.
  DISPLAY_DURATION = 120

  # Distance parcourue vers le haut.
  FLOAT_DISTANCE = 27

  # Taille du texte.
  TEXT_SIZE = 38

  #---------------------------------------------------------------------------
  # Effet vibrant des coups critiques
  #---------------------------------------------------------------------------

  # Distance maximale du mouvement horizontal.
  CRITICAL_SHAKE_DISTANCE = 15

  # Vitesse de l'oscillation.
  CRITICAL_SHAKE_SPEED = 0.35

  #---------------------------------------------------------------------------
  # Couleurs
  #---------------------------------------------------------------------------

  COLORS = {
    # Dégâts normaux.
    :normal          => Color.new(248, 248, 248),

    # Dégâts pas très efficaces / inefficaces.
    :resisted        => Color.new(80, 160, 248),

    # Super efficace.
    :super_effective => Color.new(248, 60, 60),

    # Soins.
    :healing         => Color.new(80, 220, 100)
  }

  SHADOW_COLOR = Color.new(40, 40, 40)


  #=============================================================================
  # Utilitaires
  #=============================================================================

  #-----------------------------------------------------------------------------
  # Vérifie si les dégâts proviennent d'un dégât indirect/fixe.
  #
  # Les dégâts de poison, Vampigraine, Tourbi-Sable, météo, etc. ne doivent
  # pas utiliser la couleur d'efficacité du dernier mouvement.
  #
  # On regarde la pile d'appel pour distinguer les réductions de PV provenant
  # des effets de fin de tour ou d'autres effets indirects.
  #-----------------------------------------------------------------------------

  def self.fixed_or_indirect_damage?
    caller_locations.each do |location|
      # location.path peut être nil dans certains cas.
      # to_s évite l'erreur "undefined method include? for nil:NilClass".
      path = location.path.to_s

      # Même protection pour le nom de méthode.
      method_name = location.base_label.to_s

      #-----------------------------------------------------------------------
      # Effets de fin de tour et dégâts d'effets.
      #-----------------------------------------------------------------------

      return true if method_name.include?("pbTakeEffectDamage")
      return true if method_name.include?("pbEORHealingEffects")
      return true if method_name.include?("pbEndOfRound")
      return true if method_name.include?("pbContinueStatus")
      return true if method_name.include?("pbWeather")
      return true if method_name.include?("pbEffectsOnMoveEnd")

      #-----------------------------------------------------------------------
      # Certaines sources de dégâts indirects passent par des scripts dédiés.
      #-----------------------------------------------------------------------

      return true if path.include?("Battle_EndOfRoundPhase")
    end

    false
  end


  #=============================================================================
  # Display damage / healing
  #=============================================================================

  def self.display(battle, target, amount = nil, healing = false, fixed = false)
    return if !$PokemonSystem.damage_percentage
    return if !battle
    return if !target

    #----------------------------------------------------------------------------
    # Cas où le Pokémon est caché/protégé par un substitut.
    #----------------------------------------------------------------------------

    unless healing
      return if target.damageState.disguise
      return if target.damageState.iceFace
      return if target.damageState.substitute
    end

    amount = amount.to_i

    return if amount <= 0

    total_hp = target.totalhp.to_i
    return if total_hp <= 0

    #----------------------------------------------------------------------------
    # Calcul du pourcentage.
    #----------------------------------------------------------------------------

    percentage = (amount.to_f / total_hp) * 100
    percentage = percentage.round(DECIMAL_PLACES)

    # Supprime ".0" si nécessaire.
    text = if percentage.to_i == percentage
			 "#{healing ? "+" : "-"}#{percentage.to_i}%"
		   else
			 "#{healing ? "+" : "-"}#{percentage}%"
		   end

    #----------------------------------------------------------------------------
    # Couleur.
    #----------------------------------------------------------------------------

    color = if healing

              #-----------------------------------------------------------------
              # SOINS
              #
              # Toujours verts.
              #-----------------------------------------------------------------

              COLORS[:healing]

            elsif fixed || self.fixed_or_indirect_damage?

              #-----------------------------------------------------------------
              # DÉGÂTS FIXES / INDIRECTS
              #
              # Poison, Vampigraine, Tourbi-Sable, météo, etc.
              #
              # Toujours blancs et indépendants de l'efficacité du dernier
              # mouvement utilisé.
              #-----------------------------------------------------------------

              COLORS[:normal]

            elsif Effectiveness.super_effective?(target.damageState.typeMod)

              #-----------------------------------------------------------------
              # SUPER EFFICACE
              #
              # Rouge.
              #-----------------------------------------------------------------

              COLORS[:super_effective]

            elsif Effectiveness.not_very_effective?(target.damageState.typeMod) ||
                  Effectiveness.ineffective?(target.damageState.typeMod)

              #-----------------------------------------------------------------
              # PAS TRÈS EFFICACE / INEFFICACE
              #
              # Bleu.
              #-----------------------------------------------------------------

              COLORS[:resisted]

            else

              #-----------------------------------------------------------------
              # DÉGÂTS NORMAUX
              #
              # Blancs.
              #-----------------------------------------------------------------

              COLORS[:normal]

            end

    #----------------------------------------------------------------------------
    # Coup critique
    #
    # Le coup critique n'a pas de couleur propre.
    #
    # Il conserve la couleur correspondant à l'efficacité :
    #
    #   Super efficace -> rouge
    #   Résisté        -> bleu
    #   Normal         -> blanc
    #
    # Le mouvement vibrant est géré séparément dans pbUpdate.
    #----------------------------------------------------------------------------

    critical = !healing &&
               !fixed &&
               !self.fixed_or_indirect_damage? &&
               target.damageState.critical

    battle.scene.pbShowDamagePercentage(
      target,
      text,
      color,
      critical
    )
  end
end


#===============================================================================
# Battle Scene
#===============================================================================

class Battle::Scene

  #----------------------------------------------------------------------------
  # Update
  #----------------------------------------------------------------------------

  alias dbk_damage_percentage_pbUpdate pbUpdate

  def pbUpdate(*args)
    dbk_damage_percentage_pbUpdate(*args)

    return if !@damage_percentage_sprites

    @damage_percentage_sprites.each do |data|
      sprite = data[:sprite]

      next if sprite.disposed?

      data[:timer] -= 1

      #-----------------------------------------------------------------------
      # Mouvement vers le haut
      #-----------------------------------------------------------------------

      progress = 1.0 - (
        data[:timer].to_f /
        DBKDamagePercentage::DISPLAY_DURATION
      )

      sprite.y = data[:start_y] -
                 (DBKDamagePercentage::FLOAT_DISTANCE * progress)

      #-----------------------------------------------------------------------
      # Effet vibrant des coups critiques
      #-----------------------------------------------------------------------

      if data[:critical]

        # Oscillation gauche/droite.
        shake = Math.sin(
          progress *
          Math::PI *
          2 *
          DBKDamagePercentage::CRITICAL_SHAKE_SPEED *
          10
        )

        sprite.x = data[:start_x] +
                   (
                     shake *
                     DBKDamagePercentage::CRITICAL_SHAKE_DISTANCE
                   )
      end

      #-----------------------------------------------------------------------
      # Fade out
      #-----------------------------------------------------------------------

      if data[:timer] <
         DBKDamagePercentage::DISPLAY_DURATION / 2

        sprite.opacity = (
          data[:timer].to_f /
          (DBKDamagePercentage::DISPLAY_DURATION / 2) *
          255
        ).to_i
      end

      #-----------------------------------------------------------------------
      # Suppression
      #-----------------------------------------------------------------------

      if data[:timer] <= 0
        sprite.bitmap.dispose if sprite.bitmap &&
                                !sprite.bitmap.disposed?
        sprite.dispose
      end
    end

    @damage_percentage_sprites.delete_if do |data|
      data[:timer] <= 0 ||
      data[:sprite].disposed?
    end
  end


  #----------------------------------------------------------------------------
  # Show percentage
  #----------------------------------------------------------------------------

  def pbShowDamagePercentage(target, text, color, critical = false)
    @damage_percentage_sprites ||= []

    battler_sprite = @sprites["pokemon_#{target.index}"]

    return if !battler_sprite
    return if battler_sprite.disposed?

    viewport = @viewport

    sprite = Sprite.new(viewport)

    # Bitmap plus grand pour le texte.
    bitmap = Bitmap.new(220, 64)

    # Police système.
    pbSetSystemFont(bitmap)

    # Taille du texte.
    bitmap.font.size = DBKDamagePercentage::TEXT_SIZE

    #---------------------------------------------------------------------------
    # Texte
    #---------------------------------------------------------------------------

    text_pos = [
      text,
      110,
      0,
      :center,
      color,
      DBKDamagePercentage::SHADOW_COLOR
    ]

    pbDrawTextPositions(
      bitmap,
      [text_pos]
    )

    sprite.bitmap = bitmap

    sprite.ox = bitmap.width / 2
    sprite.oy = bitmap.height

    #---------------------------------------------------------------------------
    # Position
    #---------------------------------------------------------------------------

    sprite.x = battler_sprite.x

    sprite.y = battler_sprite.y -
               battler_sprite.bitmap.height * 0.55

    sprite.z = 250
    sprite.opacity = 255

    #---------------------------------------------------------------------------
    # Ajout
    #---------------------------------------------------------------------------

    @damage_percentage_sprites << {
      :sprite    => sprite,
      :timer     => DBKDamagePercentage::DISPLAY_DURATION,
      :start_y   => sprite.y,
      :start_x   => sprite.x,
      :critical  => critical
    }
  end
end


#===============================================================================
# Damage detection
#===============================================================================
#
# Le hook se fait directement sur pbReduceHP.
#
# Cela permet de récupérer les dégâts de CHAQUE impact.
#
#===============================================================================

class Battle::Battler

  #----------------------------------------------------------------------------
  # Dégâts
  #----------------------------------------------------------------------------

  alias dbk_damage_percentage_pbReduceHP pbReduceHP

  def pbReduceHP(amount, *args)
    old_hp = self.hp

    result = dbk_damage_percentage_pbReduceHP(amount, *args)

    #---------------------------------------------------------------------------
    # Dégâts réellement subis.
    #---------------------------------------------------------------------------

    actual_damage = old_hp - self.hp

    # Aucun dégât réel.
    return result if actual_damage <= 0

    #---------------------------------------------------------------------------
    # Ne rien faire si aucun battle/scene n'est disponible.
    #---------------------------------------------------------------------------

    return result if !@battle
    return result if !@battle.scene

    #---------------------------------------------------------------------------
    # Vérifie que le damageState correspond bien à un dégât.
    #---------------------------------------------------------------------------

    return result if !self.damageState

    #---------------------------------------------------------------------------
    # Détection des dégâts fixes/indirects.
    #---------------------------------------------------------------------------

    fixed_damage = DBKDamagePercentage.fixed_or_indirect_damage?

    #---------------------------------------------------------------------------
    # Affichage du pourcentage pour CE coup.
    #---------------------------------------------------------------------------

    DBKDamagePercentage.display(
      @battle,
      self,
      actual_damage,
      false,
      fixed_damage
    )

    return result
  end


  #----------------------------------------------------------------------------
  # Soins
  #----------------------------------------------------------------------------

  alias dbk_damage_percentage_pbRecoverHP pbRecoverHP

  def pbRecoverHP(amount, *args)
    old_hp = self.hp

    result = dbk_damage_percentage_pbRecoverHP(amount, *args)

    #---------------------------------------------------------------------------
    # PV réellement récupérés.
    #---------------------------------------------------------------------------

    actual_healing = self.hp - old_hp

    # Aucun soin réel.
    return result if actual_healing <= 0

    #---------------------------------------------------------------------------
    # Ne rien faire si aucun battle/scene n'est disponible.
    #---------------------------------------------------------------------------

    return result if !@battle
    return result if !@battle.scene

    #---------------------------------------------------------------------------
    # Affichage du pourcentage de soin.
    #---------------------------------------------------------------------------

    DBKDamagePercentage.display(
      @battle,
      self,
      actual_healing,
      true,
      false
    )

    return result
  end
end