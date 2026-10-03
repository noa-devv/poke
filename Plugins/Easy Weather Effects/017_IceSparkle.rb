ICE_SPARKLE_SPRITE_COUNT = 200

class Spriteset_Map
  def ice_fx
    CustomWeather::PersistentFX.state(:IceSparkle)
  end

  def ice_make_bitmaps
    fx = ice_fx
    fx[:bitmaps]   = []
    fx[:dim_count] = 0

    dim_colors = [
      Color.new(200, 230, 255, 140),
      Color.new(220, 240, 255, 120),
      Color.new(180, 210, 255, 100),
      Color.new(240, 248, 255, 130),
    ]
    bright_colors = [
      Color.new(255, 255, 255, 240),
      Color.new(210, 240, 255, 230),
      Color.new(230, 245, 255, 220),
    ]

    dim_colors.each do |col|
      bm = Bitmap.new(1, 1)
      bm.set_pixel(0, 0, col)
      fx[:bitmaps].push(bm)

      bm2 = Bitmap.new(3, 3)
      bm2.set_pixel(1, 0, col)
      bm2.set_pixel(0, 1, col)
      bm2.set_pixel(1, 1, col)
      bm2.set_pixel(2, 1, col)
      bm2.set_pixel(1, 2, col)
      fx[:bitmaps].push(bm2)
    end

    fx[:dim_count]    = fx[:bitmaps].size
    fx[:bright_start] = fx[:dim_count]

    bright_colors.each do |col|
      bm = Bitmap.new(3, 3)
      bm.set_pixel(1, 0, col)
      bm.set_pixel(0, 1, col)
      bm.set_pixel(1, 1, col)
      bm.set_pixel(2, 1, col)
      bm.set_pixel(1, 2, col)
      faint = Color.new(col.red, col.green, col.blue, (col.alpha * 0.5).to_i)
      bm.set_pixel(0, 0, faint)
      bm.set_pixel(2, 0, faint)
      bm.set_pixel(0, 2, faint)
      bm.set_pixel(2, 2, faint)
      fx[:bitmaps].push(bm)
    end
  end

  def ice_setup_layer
    fx = ice_fx
    fx[:sprites] = []
    fx[:info]    = []
    fx[:phase] = []
    fx[:viewport]   = Viewport.new(0, 0, Graphics.width, Graphics.height)
    fx[:viewport].z = 160
    ICE_SPARKLE_SPRITE_COUNT.times do
      sprite         = Sprite.new(fx[:viewport])
      sprite.z       = 800
      sprite.bitmap  = fx[:bitmaps][rand(fx[:dim_count])]
      sprite.opacity = rand(100) + 60

      wx = cw_spawn_x
      wy = cw_map_offset_y + rand(Graphics.height)
      sprite.x = cw_world_to_screen_x(wx)
      sprite.y = cw_world_to_screen_y(wy)

      fx[:sprites].push(sprite)
      fx[:info].push([rand(120) + 20, wx, wy])
      fx[:phase].push(rand(200))
    end
    fx[:active] = true
  end

  def ice_update_sprites
    fx = ice_fx
    bright_count = fx[:bitmaps].size - fx[:bright_start]
    fx[:sprites].each_with_index do |sprite, i|
      countdown, wx, wy = fx[:info][i]
      wx += @cw_frame_jump_x
      wy += @cw_frame_jump_y

      fx[:phase][i] = (fx[:phase][i] + 1) % 200
      wy += 1 if fx[:phase][i] % 40 == 0
      wx += 1 if fx[:phase][i] % 80 == 0
      wx -= 1 if fx[:phase][i] == 120

      countdown -= 1
      if countdown == 10
        sprite.bitmap  = fx[:bitmaps][fx[:bright_start] + rand(bright_count)]
        sprite.opacity = 230
      elsif countdown == 0
        sprite.bitmap  = fx[:bitmaps][rand(fx[:dim_count])]
        sprite.opacity = rand(100) + 60
        countdown      = rand(80) + 40
      end
      sprite.opacity += rand(5) - 2
      sprite.opacity = sprite.opacity.clamp(40, 240)

      ox = cw_map_offset_x
      oy = cw_map_offset_y
      wy = oy                    if wy > oy + Graphics.height + 2
      wy = oy + Graphics.height  if wy < oy - 4
      wx = cw_spawn_x if wx < ox - 4 || wx > ox + Graphics.width + 4

      sprite.x = cw_world_to_screen_x(wx)
      sprite.y = cw_world_to_screen_y(wy)

      fx[:info][i] = [countdown, wx, wy]
    end
  end

  def ice_clear_layer
    fx = ice_fx
    fx[:sprites].each { |s| s.dispose }
    fx[:sprites].clear
    fx[:info].clear
    fx[:phase].clear
    fx[:viewport].dispose if fx[:viewport]
    fx[:viewport] = nil
    fx[:active]   = false
  end
end

CustomWeather::SpritesetHandlers.register(:IceSparkle) do |spriteset|
  spriteset.instance_eval do
    fx = ice_fx
    ice_make_bitmaps unless fx[:bitmaps]

    if $game_screen.weather_type == :IceSparkle
      if CustomWeather::PersistentFX.once_per_frame?(:IceSparkle)
        ice_setup_layer unless fx[:active]
        ice_update_sprites
      end
      cw_weather_grace_reset(:IceSparkle)
    elsif fx[:active] && cw_weather_should_clear?(:IceSparkle)
      ice_clear_layer
    end
  end
end

CustomWeather::SpritesetHandlers.register_dispose(:IceSparkle) do |spriteset|
  spriteset.instance_eval do
    fx = ice_fx
    still_wanted = $game_screen && $game_screen.weather_type == :IceSparkle
    unless still_wanted
      ice_clear_layer if fx[:active]
      if fx[:bitmaps]
        fx[:bitmaps].each { |bm| bm.dispose }
        fx[:bitmaps] = nil
      end
    end
  end
end

CustomWeather.register_weather(
  {
    :id        => :IceSparkle,
    :id_number => 16,
    :category  => :None,
    :graphics  => [],
    :tone_proc => proc { |strength|
      Tone.new(-strength / 8, -strength / 16, strength / 6, strength / 10)
    }
  },
  {
    :id        => :IceSparkle,
    :name      => _INTL("Ice Sparkle"),
    :animation => "IceSparkle"
  }
)

CustomWeather::Handlers::StartMessage.add(:IceSparkle,
  proc { |weather, battle| next _INTL("The air filled with glittering ice crystals!") })
CustomWeather::Handlers::ContinueMessage.add(:IceSparkle,
  proc { |weather, battle| next _INTL("Ice crystals sparkled through the air.") })
CustomWeather::Handlers::EndMessage.add(:IceSparkle,
  proc { |weather, battle| next _INTL("The ice crystals faded away.") })
