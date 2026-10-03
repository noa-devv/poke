WIND_SPRITE_COUNT = 120

class Spriteset_Map
  def wind_fx
    CustomWeather::PersistentFX.state(:StrongWinds)
  end

  def wind_make_bitmaps
    fx = wind_fx
    fx[:bitmaps] = []
    [
      [18, 1, Color.new(255, 255, 255,  50)],
      [24, 1, Color.new(235, 240, 255,  60)],
      [12, 1, Color.new(255, 255, 255,  40)],
      [40, 1, Color.new(255, 255, 255,  80)],
      [50, 1, Color.new(220, 230, 255,  70)],
      [35, 2, Color.new(255, 255, 255,  55)],
      [70, 1, Color.new(255, 255, 255, 110)],
      [90, 2, Color.new(255, 255, 255,  90)],
      [60, 2, Color.new(240, 245, 255, 100)],
    ].each do |w, h, color|
      bm = Bitmap.new(w, h)
      fade_w = [w / 4, 8].min
      (0...w).each do |x|
        a = if x < fade_w
              x.to_f / fade_w
            elsif x >= w - fade_w
              (w - 1 - x).to_f / fade_w
            else
              1.0
            end
        c = Color.new(color.red, color.green, color.blue, (color.alpha * a).round)
        h.times { |y| bm.set_pixel(x, y, c) }
      end
      fx[:bitmaps].push(bm)
    end
  end

  def wind_setup_layer
    fx = wind_fx
    fx[:sprites] = []
    fx[:info]    = []
    fx[:viewport]   = Viewport.new(0, 0, Graphics.width, Graphics.height)
    fx[:viewport].z = 200
    WIND_SPRITE_COUNT.times do
      bm             = fx[:bitmaps][rand(fx[:bitmaps].size)]
      sprite         = Sprite.new(fx[:viewport])
      sprite.z       = 1000
      sprite.bitmap  = bm
      sprite.opacity = rand(180) + 40

      wx = cw_map_offset_x + rand(Graphics.width + bm.width) - bm.width
      wy = cw_map_offset_y + rand(Graphics.height)
      sprite.x = cw_world_to_screen_x(wx)
      sprite.y = cw_world_to_screen_y(wy)

      fx[:sprites].push(sprite)
      fx[:info].push([rand(12) + 8, rand(4), wx, wy])
    end
    fx[:active] = true
  end

  def wind_update_sprites
    fx = wind_fx
    fx[:sprites].each_with_index do |sprite, i|
      speed, drift, wx, wy = fx[:info][i]
      wx += @cw_frame_jump_x
      wy += @cw_frame_jump_y

      wx += speed
      drift += 1
      if drift >= 6
        wy += rand(3) - 1
        drift = 0
      end

      fx[:info][i] = [speed, drift, wx, wy]

      sprite.opacity -= 1
      sprite.opacity += rand(4) if rand(20) == 0

      sprite.x = cw_world_to_screen_x(wx)
      sprite.y = cw_world_to_screen_y(wy)

      if sprite.x > Graphics.width || sprite.opacity <= 0 || cw_off_top_pan?(sprite) || cw_off_bottom_pan?(sprite)
        bm             = fx[:bitmaps][rand(fx[:bitmaps].size)]
        sprite.bitmap  = bm
        wx = cw_map_offset_x + (-bm.width - rand(80))
        wy = cw_map_offset_y + rand(Graphics.height)
        sprite.x       = cw_world_to_screen_x(wx)
        sprite.y       = cw_world_to_screen_y(wy)
        sprite.opacity = rand(160) + 60
        fx[:info][i]  = [rand(12) + 8, rand(4), wx, wy]
      end
    end
  end

  def wind_clear_layer
    fx = wind_fx
    fx[:sprites].each { |s| s.dispose }
    fx[:sprites].clear
    fx[:info].clear
    fx[:viewport].dispose if fx[:viewport]
    fx[:viewport] = nil
    fx[:active]   = false
  end
end

CustomWeather::SpritesetHandlers.register(:StrongWinds) do |spriteset|
  spriteset.instance_eval do
    fx = wind_fx
    wind_make_bitmaps unless fx[:bitmaps]

    if $game_screen.weather_type == :StrongWinds
      if CustomWeather::PersistentFX.once_per_frame?(:StrongWinds)
        wind_setup_layer unless fx[:active]
        wind_update_sprites
      end
      cw_weather_grace_reset(:StrongWinds)
    elsif fx[:active] && cw_weather_should_clear?(:StrongWinds)
      wind_clear_layer
    end
  end
end

CustomWeather::SpritesetHandlers.register_dispose(:StrongWinds) do |spriteset|
  spriteset.instance_eval do
    fx = wind_fx
    still_wanted = $game_screen && $game_screen.weather_type == :StrongWinds
    unless still_wanted
      wind_clear_layer if fx[:active]
      if fx[:bitmaps]
        fx[:bitmaps].each { |bm| bm.dispose }
        fx[:bitmaps] = nil
      end
    end
  end
end

CustomWeather.register_weather(
  { :id => :StrongWinds, :id_number => 17, :category => :None, :graphics => [],
    :tone_proc => proc { |strength| Tone.new(strength / 8, strength / 8, strength / 8, strength / 10) } },
  { :id => :StrongWinds, :name => _INTL("Strong Winds"), :animation => "StrongWinds" }
)

CustomWeather::Handlers::StartMessage.add(:StrongWinds,
  proc { |weather, battle| next _INTL("A fierce wind began to blow across the battlefield!") })
CustomWeather::Handlers::ContinueMessage.add(:StrongWinds,
  proc { |weather, battle| next _INTL("The fierce wind continues to blow!") })
CustomWeather::Handlers::EndMessage.add(:StrongWinds,
  proc { |weather, battle| next _INTL("The wind died down.") })
CustomWeather::Handlers::TypeBoost.add(:StrongWinds,
  proc { |weather, move_type, user, target|
    next 1.3 if move_type == :FLYING
    next 1.0
  })
