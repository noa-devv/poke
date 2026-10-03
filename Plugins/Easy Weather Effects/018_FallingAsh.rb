ASH_SPRITE_COUNT = 320

class Spriteset_Map
  def ash_fx
    CustomWeather::PersistentFX.state(:FallingAsh)
  end

  def ash_make_bitmaps
    fx = ash_fx
    fx[:bitmaps] = []
    [
      { w: 2, h: 2, color: Color.new(200, 200, 200, 160) },
      { w: 2, h: 2, color: Color.new(180, 180, 180, 140) },
      { w: 2, h: 2, color: Color.new(210, 205, 200, 130) },
      { w: 3, h: 2, color: Color.new(160, 160, 160, 170) },
      { w: 2, h: 3, color: Color.new(170, 165, 160, 160) },
      { w: 4, h: 3, color: Color.new(140, 140, 140, 175), irregular: true },
      { w: 3, h: 4, color: Color.new(130, 125, 120, 185), irregular: true },
      { w: 4, h: 4, color: Color.new(110, 110, 110, 145), irregular: true },
      { w: 5, h: 3, color: Color.new(150, 148, 145, 155), irregular: true },
      { w: 3, h: 5, color: Color.new(120, 118, 115, 165), irregular: true },
    ].each do |data|
      bm = Bitmap.new(data[:w], data[:h])
      if data[:irregular]
        (0...data[:w]).each do |x|
          (0...data[:h]).each do |y|
            next if x == 0 && y == 0
            next if x == data[:w] - 1 && y == 0
            next if x == 0 && y == data[:h] - 1
            next if x == data[:w] - 1 && y == data[:h] - 1
            a = [[data[:color].alpha + rand(40) - 20, 0].max, 255].min
            bm.set_pixel(x, y, Color.new(data[:color].red, data[:color].green, data[:color].blue, a))
          end
        end
      else
        bm.fill_rect(0, 0, data[:w], data[:h], data[:color])
      end
      fx[:bitmaps].push(bm)
    end
  end

  def ash_setup_layer
    fx = ash_fx
    fx[:sprites] = []
    fx[:info]    = []
    fx[:viewport]   = Viewport.new(0, 0, Graphics.width, Graphics.height)
    fx[:viewport].z = 200
    ASH_SPRITE_COUNT.times do
      sprite         = Sprite.new(fx[:viewport])
      sprite.z       = 1000
      sprite.bitmap  = fx[:bitmaps][rand(fx[:bitmaps].size)]
      sprite.opacity = rand(160) + 40

      wx = cw_spawn_x
      wy = cw_map_offset_y + rand(Graphics.height)
      sprite.x = cw_world_to_screen_x(wx)
      sprite.y = cw_world_to_screen_y(wy)

      fx[:sprites].push(sprite)
      fx[:info].push([rand(2) + 1, rand(120), wx, wy])
    end
    fx[:active] = true
  end

  def ash_update_sprites
    fx = ash_fx
    fx[:sprites].each_with_index do |sprite, i|
      speed, phase, wx, wy = fx[:info][i]
      wx += @cw_frame_jump_x
      wy += @cw_frame_jump_y

      wy += speed == 2 ? 1 : (Graphics.frame_count % 2 == i % 2 ? 1 : 0)
      phase = (phase + 1) % 120
      if    phase < 30  then wx -= 1
      elsif phase < 90  then wx += 0
      else                   wx += 1
      end

      sprite.opacity += rand(3) - 1

      sprite.x = cw_world_to_screen_x(wx)
      sprite.y = cw_world_to_screen_y(wy)

      fx[:info][i] = [speed, phase, wx, wy]

      if sprite.y > Graphics.height + sprite.bitmap.height
        sprite.opacity = rand(160) + 40
        sprite.bitmap  = fx[:bitmaps][rand(fx[:bitmaps].size)]
        wx = cw_spawn_x
        wy = cw_map_offset_y + (-sprite.bitmap.height - rand(20))
        sprite.x       = cw_world_to_screen_x(wx)
        sprite.y       = cw_world_to_screen_y(wy)
        fx[:info][i]   = [rand(2) + 1, rand(120), wx, wy]
      elsif cw_off_screen_pan?(sprite)
        sprite.opacity = rand(160) + 40
        sprite.bitmap  = fx[:bitmaps][rand(fx[:bitmaps].size)]
        wx = cw_spawn_x
        wy = cw_map_offset_y + rand(Graphics.height)
        sprite.x       = cw_world_to_screen_x(wx)
        sprite.y       = cw_world_to_screen_y(wy)
        fx[:info][i]   = [rand(2) + 1, rand(120), wx, wy]
      end
    end
  end

  def ash_clear_layer
    fx = ash_fx
    fx[:sprites].each { |s| s.dispose }
    fx[:sprites].clear
    fx[:info].clear
    fx[:viewport].dispose if fx[:viewport]
    fx[:viewport] = nil
    fx[:active]   = false
  end
end

CustomWeather::SpritesetHandlers.register(:FallingAsh) do |spriteset|
  spriteset.instance_eval do
    fx = ash_fx
    ash_make_bitmaps unless fx[:bitmaps]

    if $game_screen.weather_type == :FallingAsh
      if CustomWeather::PersistentFX.once_per_frame?(:FallingAsh)
        ash_setup_layer unless fx[:active]
        ash_update_sprites
      end
      cw_weather_grace_reset(:FallingAsh)
    elsif fx[:active] && cw_weather_should_clear?(:FallingAsh)
      ash_clear_layer
    end
  end
end

CustomWeather::SpritesetHandlers.register_dispose(:FallingAsh) do |spriteset|
  spriteset.instance_eval do
    fx = ash_fx
    still_wanted = $game_screen && $game_screen.weather_type == :FallingAsh
    unless still_wanted
      ash_clear_layer if fx[:active]
      if fx[:bitmaps]
        fx[:bitmaps].each { |bm| bm.dispose }
        fx[:bitmaps] = nil
      end
    end
  end
end

CustomWeather.register_cosmetic_weather(
  { :id => :FallingAsh, :id_number => 18, :category => :None, :graphics => [],
    :tone_proc => proc { |strength| Tone.new(-strength / 8, -strength / 10, -strength / 12, strength / 5) } }
)
