STARSTORM_SPRITE_COUNT = 250

class Spriteset_Map
  def starstorm_fx
    CustomWeather::PersistentFX.state(:Starstorm)
  end

  def starstorm_make_bitmaps
    fx = starstorm_fx
    fx[:bitmaps] = []

    families = [
      [Color.new(219, 191,  95), Color.new(233, 210, 142), Color.new(242, 229, 190)],
      [Color.new( 44, 166,   0), Color.new( 88, 221,  89), Color.new(205, 246, 205)],
      [Color.new(  5,  88, 168), Color.new(102, 181, 221), Color.new(189, 225, 242)],
      [Color.new( 71,   0, 222), Color.new(155, 107, 255), Color.new(216, 197, 255)],
      [Color.new(178,  15,  56), Color.new(196,  55,  84), Color.new(241, 185, 187)],
      [Color.new(222, 124,   0), Color.new(255, 180,  85), Color.new(255, 220, 177)],
    ]

    families.each do |outer, mid, bright|
      bm = Bitmap.new(16, 16)
      bm.fill_rect(7, 7, 2, 2, mid)
      bm.set_pixel(7,  7, bright)
      bm.set_pixel(8,  7, bright)
      bm.set_pixel(7,  8, bright)
      bm.set_pixel(8,  8, bright)
      fx[:bitmaps].push(bm)

      bm = Bitmap.new(16, 16)
      bm.fill_rect(7, 4, 2, 8, mid)
      bm.fill_rect(4, 7, 8, 2, mid)
      bm.fill_rect(7, 6, 2, 4, bright)
      bm.fill_rect(6, 7, 4, 2, bright)
      fx[:bitmaps].push(bm)

      bm = Bitmap.new(16, 16)
      bm.set_pixel(2,  2,  outer); bm.set_pixel(3,  3,  outer)
      bm.set_pixel(4,  4,  mid);   bm.set_pixel(5,  5,  mid)
      bm.set_pixel(13, 2,  outer); bm.set_pixel(12, 3,  outer)
      bm.set_pixel(11, 4,  mid);   bm.set_pixel(10, 5,  mid)
      bm.fill_rect(6, 6, 4, 4, mid)
      bm.fill_rect(7, 7, 2, 2, bright)
      bm.set_pixel(5,  10, mid);   bm.set_pixel(4,  11, mid)
      bm.set_pixel(3,  12, outer); bm.set_pixel(2,  13, outer)
      bm.set_pixel(10, 10, mid);   bm.set_pixel(11, 11, mid)
      bm.set_pixel(12, 12, outer); bm.set_pixel(13, 13, outer)
      fx[:bitmaps].push(bm)

      bm = Bitmap.new(16, 16)
      bm.fill_rect(7, 1, 2, 14, outer)
      bm.fill_rect(1, 7, 14, 2, outer)
      bm.fill_rect(7, 3, 2, 10, mid)
      bm.fill_rect(3, 7, 10, 2, mid)
      bm.fill_rect(7, 5, 2, 6,  bright)
      bm.fill_rect(5, 7, 6,  2, bright)
      fx[:bitmaps].push(bm)

      bm = Bitmap.new(16, 16)
      bm.fill_rect(7, 1, 2, 14, outer)
      bm.fill_rect(1, 7, 14, 2, outer)
      bm.set_pixel(2,  2,  outer); bm.set_pixel(3,  3,  outer)
      bm.set_pixel(13, 2,  outer); bm.set_pixel(12, 3,  outer)
      bm.set_pixel(2,  13, outer); bm.set_pixel(3,  12, outer)
      bm.set_pixel(13, 13, outer); bm.set_pixel(12, 12, outer)
      bm.set_pixel(4,  4,  mid);   bm.set_pixel(5,  5,  mid)
      bm.set_pixel(11, 4,  mid);   bm.set_pixel(10, 5,  mid)
      bm.set_pixel(4,  11, mid);   bm.set_pixel(5,  10, mid)
      bm.set_pixel(11, 11, mid);   bm.set_pixel(10, 10, mid)
      bm.fill_rect(7, 3, 2, 10, mid)
      bm.fill_rect(3, 7, 10,  2, mid)
      bm.fill_rect(7, 5, 2, 6, bright)
      bm.fill_rect(5, 7, 6, 2, bright)
      bm.fill_rect(7, 7, 2, 2, bright)
      fx[:bitmaps].push(bm)

      bm = Bitmap.new(16, 16)
      bm.fill_rect(7, 4, 2, 8, mid)
      bm.fill_rect(4, 7, 8, 2, mid)
      bm.fill_rect(7, 6, 2, 4, bright)
      bm.fill_rect(6, 7, 4, 2, bright)
      fx[:bitmaps].push(bm)
    end

    fx[:frames_per_family] = 6
    fx[:family_count]      = families.size
  end

  def starstorm_setup_layer
    fx = starstorm_fx
    fx[:sprites] = []
    fx[:info]    = []
    fx[:viewport]   = Viewport.new(0, 0, Graphics.width, Graphics.height)
    fx[:viewport].z = 200

    STARSTORM_SPRITE_COUNT.times do
      sprite         = Sprite.new(fx[:viewport])
      sprite.z       = 1000
      family       = rand(fx[:family_count])
      frame        = rand(fx[:frames_per_family])
      bm_idx       = family * fx[:frames_per_family] + frame
      sprite.bitmap  = fx[:bitmaps][bm_idx]
      sprite.opacity = rand(160) + 60

      wx = cw_spawn_x
      wy = cw_map_offset_y + rand(Graphics.height)
      sprite.x = cw_world_to_screen_x(wx)
      sprite.y = cw_world_to_screen_y(wy)

      x_spd = rand(3) + 1
      y_spd = rand(4) + 5
      fx[:info].push([family, frame, rand(15), x_spd, y_spd, wx, wy])
      fx[:sprites].push(sprite)
    end

    fx[:active] = true
  end

  def starstorm_update_sprites
    fx = starstorm_fx
    fx[:sprites].each_with_index do |sprite, i|
      family, frame, countdown, x_spd, y_spd, wx, wy = fx[:info][i]
      wx += @cw_frame_jump_x
      wy += @cw_frame_jump_y

      wx -= x_spd
      wy += y_spd

      countdown -= 1
      if countdown <= 0
        frame     = (frame + 1) % fx[:frames_per_family]
        bm_idx    = family * fx[:frames_per_family] + frame
        sprite.bitmap = fx[:bitmaps][bm_idx]
        countdown = 15
      end

      sprite.opacity -= 1

      sprite.x = cw_world_to_screen_x(wx)
      sprite.y = cw_world_to_screen_y(wy)

      fx[:info][i] = [family, frame, countdown, x_spd, y_spd, wx, wy]

      sx = sprite.x
      sy = sprite.y
      if sprite.opacity <= 0 || sy > Graphics.height + 8 || sy < -(sprite.bitmap.height + 8) || sx < -8 || sx > Graphics.width + 8
        new_family   = rand(fx[:family_count])
        new_frame    = 0
        sprite.bitmap = fx[:bitmaps][new_family * fx[:frames_per_family]]
        sprite.opacity = rand(140) + 80
        if rand(2) == 0
          wx = cw_spawn_x
          wy = cw_map_offset_y + (-sprite.bitmap.height - rand(20))
        else
          wx = cw_map_offset_x + Graphics.width + rand(60)
          wy = cw_map_offset_y + rand(Graphics.height / 2)
        end
        sprite.x = cw_world_to_screen_x(wx)
        sprite.y = cw_world_to_screen_y(wy)
        fx[:info][i] = [new_family, new_frame, 15, rand(3) + 1, rand(4) + 5, wx, wy]
      end
    end
  end

  def starstorm_clear_layer
    fx = starstorm_fx
    fx[:sprites].each { |s| s.dispose }
    fx[:sprites].clear
    fx[:info].clear
    fx[:viewport].dispose if fx[:viewport]
    fx[:viewport] = nil
    fx[:active]   = false
  end
end

CustomWeather::SpritesetHandlers.register(:Starstorm) do |spriteset|
  spriteset.instance_eval do
    fx = starstorm_fx
    starstorm_make_bitmaps unless fx[:bitmaps]

    if $game_screen.weather_type == :Starstorm
      if CustomWeather::PersistentFX.once_per_frame?(:Starstorm)
        starstorm_setup_layer unless fx[:active]
        starstorm_update_sprites
      end
      cw_weather_grace_reset(:Starstorm)
    elsif fx[:active] && cw_weather_should_clear?(:Starstorm)
      starstorm_clear_layer
    end
  end
end

CustomWeather::SpritesetHandlers.register_dispose(:Starstorm) do |spriteset|
  spriteset.instance_eval do
    fx = starstorm_fx
    still_wanted = $game_screen && $game_screen.weather_type == :Starstorm
    unless still_wanted
      starstorm_clear_layer if fx[:active]
      if fx[:bitmaps]
        fx[:bitmaps].each { |bm| bm.dispose }
        fx[:bitmaps] = nil
      end
    end
  end
end

CustomWeather.register_weather(
  { :id => :Starstorm, :id_number => 13, :category => :None, :graphics => [],
    :tone_proc => proc { |strength|
      Tone.new(strength / 12, -strength / 14, strength / 10, 0)
    }
  },
  { :id => :Starstorm, :name => _INTL("Starstorm"), :animation => "Starstorm" }
)

CustomWeather::Handlers::StartMessage.add(:Starstorm,
  proc { |weather, battle| next _INTL("Stars fell from the sky!") })
CustomWeather::Handlers::ContinueMessage.add(:Starstorm,
  proc { |weather, battle| next _INTL("Stars continue falling from above!") })
CustomWeather::Handlers::EndMessage.add(:Starstorm,
  proc { |weather, battle| next _INTL("The stars stopped falling.") })
CustomWeather::Handlers::DamageImmunity.add(:Starstorm,
  proc { |weather, battler|
    next true if battler.pbHasType?(:PSYCHIC)
    next true if battler.hasActiveAbility?([:OVERCOAT, :IMMUNITY])
    next true if battler.hasActiveItem?(:SAFETYGOGGLES)
    next false
  })
CustomWeather::Handlers::TypeBoost.add(:Starstorm,
  proc { |weather, move_type, user, target|
    next 1.1 if move_type == :PSYCHIC
    next 1.0
  })
