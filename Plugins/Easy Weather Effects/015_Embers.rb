EMBER_SPRITE_COUNT = 270

class Spriteset_Map
  def ember_fx
    CustomWeather::PersistentFX.state(:Embers)
  end

  def ember_make_bitmaps
    fx = ember_fx
    fx[:bitmaps] = []
    [
      [4, 4, Color.new(255, 120,  20, 240), Color.new(255, 200,  60, 120)],
      [3, 3, Color.new(255,  80,  10, 220), Color.new(255, 160,  40, 100)],
      [5, 5, Color.new(255, 160,  40, 230), Color.new(255, 220, 100, 110)],
      [3, 4, Color.new(220,  60,   5, 200), Color.new(255, 140,  30,  90)],
      [4, 3, Color.new(255, 200,  80, 250), Color.new(255, 240, 160, 130)],
    ].each do |w, h, core, glow|
      bm = Bitmap.new(w + 2, h + 2)
      bm.fill_rect(0,     0,     w + 2, 1, glow)
      bm.fill_rect(0,     h + 1, w + 2, 1, glow)
      bm.fill_rect(0,     1,     1,     h, glow)
      bm.fill_rect(w + 1, 1,     1,     h, glow)
      bm.fill_rect(1, 1, w, h, core)
      fx[:bitmaps].push(bm)
    end
  end

  def ember_setup_layer
    fx = ember_fx
    fx[:sprites] = []
    fx[:info]    = []
    fx[:phase] = []
    fx[:viewport]   = Viewport.new(0, 0, Graphics.width, Graphics.height)
    fx[:viewport].z = 200
    EMBER_SPRITE_COUNT.times do
      sprite         = Sprite.new(fx[:viewport])
      sprite.z       = 1000
      sprite.bitmap  = fx[:bitmaps][rand(fx[:bitmaps].size)]
      sprite.opacity = rand(140) + 20

      wx = cw_spawn_x
      wy = cw_map_offset_y + rand(Graphics.height)
      sprite.x = cw_world_to_screen_x(wx)
      sprite.y = cw_world_to_screen_y(wy)

      fx[:sprites].push(sprite)
      fx[:info].push([rand(3), wx, wy])
      fx[:phase].push(rand(60))
    end
    fx[:active] = true
  end

  def ember_update_sprites
    fx = ember_fx
    fx[:sprites].each_with_index do |sprite, i|
      rise, wx, wy = fx[:info][i]
      wx += @cw_frame_jump_x
      wy += @cw_frame_jump_y

      wy -= (rise % 3) + 1
      fx[:phase][i] = (fx[:phase][i] + 1) % 60
      wx -= 1 if fx[:phase][i] < 15
      wx += 1 if fx[:phase][i] >= 45

      sprite.opacity -= 2
      sprite.opacity += rand(6) - 2

      sprite.x = cw_world_to_screen_x(wx)
      sprite.y = cw_world_to_screen_y(wy)

      fx[:info][i] = [rise, wx, wy]

      if sprite.opacity <= 0 || sprite.y < -sprite.bitmap.height
        sprite.opacity  = rand(80) + 80
        sprite.bitmap   = fx[:bitmaps][rand(fx[:bitmaps].size)]
        wx = cw_spawn_x
        wy = cw_map_offset_y + Graphics.height + rand(30)
        sprite.x        = cw_world_to_screen_x(wx)
        sprite.y        = cw_world_to_screen_y(wy)
        fx[:info][i]  = [rand(3), wx, wy]
        fx[:phase][i] = rand(60)
      elsif cw_off_screen_pan_rising?(sprite)
        sprite.opacity  = rand(80) + 80
        sprite.bitmap   = fx[:bitmaps][rand(fx[:bitmaps].size)]
        wx = cw_spawn_x
        wy = cw_map_offset_y + rand(Graphics.height)
        sprite.x        = cw_world_to_screen_x(wx)
        sprite.y        = cw_world_to_screen_y(wy)
        fx[:info][i]  = [rand(3), wx, wy]
        fx[:phase][i] = rand(60)
      end
    end
  end

  def ember_clear_layer
    fx = ember_fx
    fx[:sprites].each { |s| s.dispose }
    fx[:sprites].clear
    fx[:info].clear
    fx[:phase].clear
    fx[:viewport].dispose if fx[:viewport]
    fx[:viewport] = nil
    fx[:active]   = false
  end
end

CustomWeather::SpritesetHandlers.register(:Embers) do |spriteset|
  spriteset.instance_eval do
    fx = ember_fx
    ember_make_bitmaps unless fx[:bitmaps]

    if $game_screen.weather_type == :Embers
      if CustomWeather::PersistentFX.once_per_frame?(:Embers)
        ember_setup_layer unless fx[:active]
        ember_update_sprites
      end
      cw_weather_grace_reset(:Embers)
    elsif fx[:active] && cw_weather_should_clear?(:Embers)
      ember_clear_layer
    end
  end
end

CustomWeather::SpritesetHandlers.register_dispose(:Embers) do |spriteset|
  spriteset.instance_eval do
    fx = ember_fx
    still_wanted = $game_screen && $game_screen.weather_type == :Embers
    unless still_wanted
      ember_clear_layer if fx[:active]
      if fx[:bitmaps]
        fx[:bitmaps].each { |bm| bm.dispose }
        fx[:bitmaps] = nil
      end
    end
  end
end

CustomWeather.register_weather(
  { :id => :Embers, :id_number => 14, :category => :None, :graphics => [],
    :tone_proc => proc { |strength| Tone.new(strength / 3, -strength / 6, -strength / 3, 0) } },
  { :id => :Embers, :name => _INTL("Embers"), :animation => "Embers" }
)

CustomWeather::Handlers::StartMessage.add(:Embers,
  proc { |weather, battle| next _INTL("Glowing embers rained down from the sky!") })
CustomWeather::Handlers::ContinueMessage.add(:Embers,
  proc { |weather, battle| next _INTL("Embers continued to rain down!") })
CustomWeather::Handlers::EndMessage.add(:Embers,
  proc { |weather, battle| next _INTL("The embers faded and went cold.") })
CustomWeather::Handlers::DamageImmunity.add(:Embers,
  proc { |weather, battler|
    next true if battler.pbHasType?(:FIRE)
    next true if battler.pbHasType?(:ROCK)
    next true if battler.hasActiveAbility?([:OVERCOAT, :FLASHFIRE, :THICKFAT])
    next true if battler.hasActiveItem?(:SAFETYGOGGLES)
    next false
  })
CustomWeather::Handlers::EORDamage.add(:Embers,
  proc { |weather, battler, battle|
    next if battler.fainted?
    next if CustomWeather::Handlers.triggerDamageImmunity(:Embers, battler)
    next if !battler.takesIndirectDamage?
    battle.pbDisplay(_INTL("{1} is scorched by the falling embers!", battler.pbThis))
    battle.scene.pbDamageAnimation(battler)
    battler.pbReduceHP(battler.totalhp / 16, false)
  })
CustomWeather::Handlers::TypeBoost.add(:Embers,
  proc { |weather, move_type, user, target|
    next 1.5 if move_type == :FIRE
    next 1.0
  })
