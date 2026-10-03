SAKURA_SPRITE_COUNT = 220

class Spriteset_Map
  def sakura_fx
    CustomWeather::PersistentFX.state(:SakuraPetals)
  end

  def sakura_make_bitmaps
    fx = sakura_fx
    fx[:bitmaps] = []
    [
      [6, 4, Color.new(255, 182, 193, 180), Color.new(255, 220, 230, 230)],
      [5, 3, Color.new(255, 160, 180, 170), Color.new(255, 210, 220, 220)],
      [7, 5, Color.new(255, 200, 185, 160), Color.new(255, 240, 220, 200)],
      [4, 4, Color.new(255, 230, 200, 190), Color.new(255, 255, 240, 220)],
      [5, 4, Color.new(255, 175, 170, 175), Color.new(255, 220, 215, 210)],
    ].each do |w, h, outer, inner|
      bm = Bitmap.new(w + 2, h + 2)
      bm.fill_rect(1, 0,     w,     1, outer)
      bm.fill_rect(0, 1,     w + 2, h, outer)
      bm.fill_rect(1, h + 1, w,     1, outer)
      bm.fill_rect(1, 1, (w / 2).ceil, (h / 2).ceil, inner)
      fx[:bitmaps].push(bm)
    end
  end

  def sakura_setup_layer
    fx = sakura_fx
    fx[:sprites] = []
    fx[:info]    = []
    fx[:phase] = []
    fx[:viewport]   = Viewport.new(0, 0, Graphics.width, Graphics.height)
    fx[:viewport].z = 180
    SAKURA_SPRITE_COUNT.times do
      sprite         = Sprite.new(fx[:viewport])
      sprite.z       = 900
      sprite.bitmap  = fx[:bitmaps][rand(fx[:bitmaps].size)]
      sprite.opacity = rand(120) + 80
      sprite.zoom_x  = [0.6, 0.8, 1.0].sample
      sprite.zoom_y  = sprite.zoom_x

      wx = cw_spawn_x
      wy = cw_map_offset_y + rand(Graphics.height)
      sprite.x = cw_world_to_screen_x(wx)
      sprite.y = cw_world_to_screen_y(wy)

      fx[:sprites].push(sprite)
      fx[:info].push([rand(3), wx, wy])
      fx[:phase].push(rand(80))
    end
    fx[:active] = true
  end

  def sakura_update_sprites
    fx = sakura_fx
    fx[:sprites].each_with_index do |sprite, i|
      fall_speed, wx, wy = fx[:info][i]
      wx += @cw_frame_jump_x
      wy += @cw_frame_jump_y

      wy += (fall_speed % 2) + 1
      fx[:phase][i] = (fx[:phase][i] + 1) % 80
      phase = fx[:phase][i]
      if    phase < 20 then wx -= 1
      elsif phase < 60 then wx += 0
      else                  wx += 1
      end

      sprite.opacity -= 1
      sprite.opacity += rand(3) - 1

      sprite.x = cw_world_to_screen_x(wx)
      sprite.y = cw_world_to_screen_y(wy)

      fx[:info][i] = [fall_speed, wx, wy]

      if sprite.opacity <= 0 || sprite.y > Graphics.height + sprite.bitmap.height
        sprite.opacity   = rand(120) + 80
        sprite.bitmap    = fx[:bitmaps][rand(fx[:bitmaps].size)]
        sprite.zoom_x    = [0.6, 0.8, 1.0].sample
        sprite.zoom_y    = sprite.zoom_x
        wx = cw_spawn_x
        wy = cw_map_offset_y + (-sprite.bitmap.height - rand(40))
        sprite.x         = cw_world_to_screen_x(wx)
        sprite.y         = cw_world_to_screen_y(wy)
        fx[:info][i]  = [rand(3), wx, wy]
        fx[:phase][i] = rand(80)
      elsif cw_off_screen_pan?(sprite)
        sprite.opacity   = rand(120) + 80
        sprite.bitmap    = fx[:bitmaps][rand(fx[:bitmaps].size)]
        sprite.zoom_x    = [0.6, 0.8, 1.0].sample
        sprite.zoom_y    = sprite.zoom_x
        wx = cw_spawn_x
        wy = cw_map_offset_y + rand(Graphics.height)
        sprite.x         = cw_world_to_screen_x(wx)
        sprite.y         = cw_world_to_screen_y(wy)
        fx[:info][i]  = [rand(3), wx, wy]
        fx[:phase][i] = rand(80)
      end
    end
  end

  def sakura_clear_layer
    fx = sakura_fx
    fx[:sprites].each { |s| s.dispose }
    fx[:sprites].clear
    fx[:info].clear
    fx[:phase].clear
    fx[:viewport].dispose if fx[:viewport]
    fx[:viewport] = nil
    fx[:active]   = false
  end
end

CustomWeather::SpritesetHandlers.register(:SakuraPetals) do |spriteset|
  spriteset.instance_eval do
    fx = sakura_fx
    sakura_make_bitmaps unless fx[:bitmaps]

    if $game_screen.weather_type == :SakuraPetals
      if CustomWeather::PersistentFX.once_per_frame?(:SakuraPetals)
        sakura_setup_layer unless fx[:active]
        sakura_update_sprites
      end
      cw_weather_grace_reset(:SakuraPetals)
    elsif fx[:active] && cw_weather_should_clear?(:SakuraPetals)
      sakura_clear_layer
    end
  end
end

CustomWeather::SpritesetHandlers.register_dispose(:SakuraPetals) do |spriteset|
  spriteset.instance_eval do
    fx = sakura_fx
    still_wanted = $game_screen && $game_screen.weather_type == :SakuraPetals
    unless still_wanted
      sakura_clear_layer if fx[:active]
      if fx[:bitmaps]
        fx[:bitmaps].each { |bm| bm.dispose }
        fx[:bitmaps] = nil
      end
    end
  end
end

CustomWeather.register_weather(
  {
    :id        => :SakuraPetals,
    :id_number => 15,
    :category  => :None,
    :graphics  => [],
    :tone_proc => proc { |strength|
      Tone.new(strength / 8, -strength / 16, -strength / 8, 0)
    }
  },
  {
    :id        => :SakuraPetals,
    :name      => _INTL("Sakura Petals"),
    :animation => "SakuraPetals"
  }
)

CustomWeather::Handlers::StartMessage.add(:SakuraPetals,
  proc { |weather, battle| next _INTL("Sakura petals began to fall!") })
CustomWeather::Handlers::ContinueMessage.add(:SakuraPetals,
  proc { |weather, battle| next _INTL("Petals continued to drift through the air.") })
CustomWeather::Handlers::EndMessage.add(:SakuraPetals,
  proc { |weather, battle| next _INTL("The sakura petals settled.") })
