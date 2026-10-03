INVERSE_RAIN_COUNT = 180

class Spriteset_Map
  def inverse_rain_fx
    CustomWeather::PersistentFX.state(:InverseRain)
  end

  def inverse_rain_make_bitmaps
    fx = inverse_rain_fx
    fx[:bitmaps] = {}

    streak = Bitmap.new(7, 56)
    sc  = Color.new(220, 200, 255, 200)
    sc2 = Color.new(200, 180, 255, 100)
    (0..6).each { |i|
      streak.fill_rect(i, i * 8, 1, 8, i < 2 ? sc2 : sc)
    }
    fx[:bitmaps][:streak] = streak

    splash = Bitmap.new(8, 5)
    splash.fill_rect(1, 0, 6, 1, Color.new(200, 180, 255, 110))
    splash.fill_rect(1, 4, 6, 1, Color.new(200, 180, 255, 110))
    splash.fill_rect(0, 1, 1, 3, Color.new(200, 180, 255, 110))
    splash.fill_rect(7, 1, 1, 3, Color.new(200, 180, 255, 110))
    splash.set_pixel(1, 4, Color.new(220, 200, 255, 190))
    splash.set_pixel(0, 3, Color.new(220, 200, 255, 190))
    fx[:bitmaps][:splash] = splash
  end

  def inverse_rain_setup_layer
    fx = inverse_rain_fx
    fx[:sprites] = []
    fx[:info]    = []
    fx[:viewport]   = Viewport.new(0, 0, Graphics.width, Graphics.height)
    fx[:viewport].z = 200

    INVERSE_RAIN_COUNT.times do
      sprite        = Sprite.new(fx[:viewport])
      sprite.z      = 1000
      sprite.bitmap = fx[:bitmaps][:streak]
      sprite.opacity = rand(120) + 100

      wx = cw_map_offset_x + rand(Graphics.width + 100) - 50
      wy = cw_map_offset_y + rand(Graphics.height)
      sprite.x = cw_world_to_screen_x(wx)
      sprite.y = cw_world_to_screen_y(wy)

      fx[:sprites].push(sprite)
      fx[:info].push([0, wx, wy])
    end
    fx[:active] = true
  end

  def inverse_rain_update_sprites
    fx = inverse_rain_fx
    fx[:sprites].each_with_index do |sprite, i|
      timer, wx, wy = fx[:info][i]
      wx += @cw_frame_jump_x
      wy += @cw_frame_jump_y

      if timer > 0
        timer -= 1
        sprite.opacity -= 30
        fx[:info][i] = [timer, wx, wy]
        if timer <= 0 || sprite.opacity <= 0
          sprite.bitmap  = fx[:bitmaps][:streak]
          wx = cw_map_offset_x + rand(Graphics.width + 100) - 50
          wy = cw_map_offset_y + Graphics.height + fx[:bitmaps][:streak].height + rand(30)
          sprite.x       = cw_world_to_screen_x(wx)
          sprite.y       = cw_world_to_screen_y(wy)
          sprite.opacity = rand(120) + 100
          fx[:info][i] = [0, wx, wy]
        end
      else
        wx += 2
        wy -= 16
        sprite.opacity -= 8

        sprite.x = cw_world_to_screen_x(wx)
        sprite.y = cw_world_to_screen_y(wy)

        fx[:info][i] = [0, wx, wy]

        if sprite.y < -sprite.bitmap.height || sprite.opacity <= 0
          if sprite.y < -sprite.bitmap.height && rand(3) == 0
            sprite.bitmap  = fx[:bitmaps][:splash]
            wy = cw_map_offset_y + 0
            sprite.x       = cw_world_to_screen_x(wx)
            sprite.y       = cw_world_to_screen_y(wy)
            sprite.opacity = 200
            fx[:info][i] = [3, wx, wy]
          else
            sprite.bitmap  = fx[:bitmaps][:streak]
            wx = cw_map_offset_x + rand(Graphics.width + 100) - 50
            wy = cw_map_offset_y + Graphics.height + sprite.bitmap.height + rand(30)
            sprite.x       = cw_world_to_screen_x(wx)
            sprite.y       = cw_world_to_screen_y(wy)
            sprite.opacity = rand(120) + 100
            fx[:info][i] = [0, wx, wy]
          end
        elsif cw_off_screen_pan_rising?(sprite)
          sprite.bitmap  = fx[:bitmaps][:streak]
          wx = cw_map_offset_x + rand(Graphics.width + 100) - 50
          wy = cw_map_offset_y + rand(Graphics.height)
          sprite.x       = cw_world_to_screen_x(wx)
          sprite.y       = cw_world_to_screen_y(wy)
          sprite.opacity = rand(120) + 100
          fx[:info][i] = [0, wx, wy]
        end
      end
    end
  end

  def inverse_rain_clear_layer
    fx = inverse_rain_fx
    fx[:sprites].each { |s| s.dispose }
    fx[:sprites].clear
    fx[:info].clear
    fx[:viewport].dispose if fx[:viewport]
    fx[:viewport] = nil
    fx[:active]   = false
  end
end

CustomWeather::SpritesetHandlers.register(:InverseRain) do |spriteset|
  spriteset.instance_eval do
    fx = inverse_rain_fx
    inverse_rain_make_bitmaps unless fx[:bitmaps]

    if $game_screen.weather_type == :InverseRain
      if CustomWeather::PersistentFX.once_per_frame?(:InverseRain)
        inverse_rain_setup_layer unless fx[:active]
        inverse_rain_update_sprites
      end
      cw_weather_grace_reset(:InverseRain)
    elsif fx[:active] && cw_weather_should_clear?(:InverseRain)
      inverse_rain_clear_layer
    end
  end
end

CustomWeather::SpritesetHandlers.register_dispose(:InverseRain) do |spriteset|
  spriteset.instance_eval do
    fx = inverse_rain_fx
    still_wanted = $game_screen && $game_screen.weather_type == :InverseRain
    unless still_wanted
      inverse_rain_clear_layer if fx[:active]
      if fx[:bitmaps]
        fx[:bitmaps].each_value { |bm| bm.dispose }
        fx[:bitmaps] = nil
      end
    end
  end
end

CustomWeather.register_weather(
  { :id => :InverseRain, :id_number => 20, :category => :Rain, :graphics => [],
    :tone_proc => proc { |strength|
      Tone.new(-strength / 6, -strength / 8, strength / 4, strength / 8)
    }
  },
  { :id => :InverseRain, :name => _INTL("Inverse Rain"), :animation => "InverseRain" }
)

CustomWeather::Handlers::StartMessage.add(:InverseRain,
  proc { |weather, battle| next _INTL("Rain began falling upward!") })
CustomWeather::Handlers::ContinueMessage.add(:InverseRain,
  proc { |weather, battle| next _INTL("Rain continues to defy gravity!") })
CustomWeather::Handlers::EndMessage.add(:InverseRain,
  proc { |weather, battle| next _INTL("The inverse rain subsided.") })
CustomWeather::Handlers::DamageImmunity.add(:InverseRain,
  proc { |weather, battler|
    next true if battler.pbHasType?(:WATER)
    next true if battler.hasActiveAbility?([:DRYSKIN, :WATERABSORB, :STORMDRAIN, :OVERCOAT])
    next true if battler.hasActiveItem?(:SAFETYGOGGLES)
    next false
  })
CustomWeather::Handlers::EORDamage.add(:InverseRain,
  proc { |weather, battler, battle|
    next if battler.fainted?
    next if CustomWeather::Handlers.triggerDamageImmunity(:InverseRain, battler)
    next if !battler.takesIndirectDamage?
    battle.pbDisplay(_INTL("{1} is pelted by the rising rain!", battler.pbThis))
    battle.scene.pbDamageAnimation(battler)
    battler.pbReduceHP(battler.totalhp / 16, false)
  })
CustomWeather::Handlers::TypeBoost.add(:InverseRain,
  proc { |weather, move_type, user, target|
    next 1.5 if move_type == :WATER
    next 1.0
  })
