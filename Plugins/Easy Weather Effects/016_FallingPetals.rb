PETAL_SPRITE_COUNT = 290

class Spriteset_Map
  def petal_fx
    CustomWeather::PersistentFX.state(:FallingPetals)
  end

  def petal_make_bitmaps
    fx = petal_fx
    fx[:bitmaps] = []

    palettes = {
      crimson: [
        Color.new(185,  45,  45, 225),
        Color.new(230, 105,  90, 205),
        Color.new(110,  10,  10, 215),
        Color.new(210,  80,  70, 185),
      ],
      rose: [
        Color.new(215, 110, 130, 215),
        Color.new(248, 178, 190, 205),
        Color.new(155,  60,  80, 200),
        Color.new(235, 145, 162, 185),
      ],
      blue: [
        Color.new(100, 140, 195, 215),
        Color.new(160, 200, 238, 205),
        Color.new( 50,  80, 140, 205),
        Color.new(130, 168, 215, 185),
      ],
    }

    shapes = [
      { w: 10, h: 8, rows: [
        [0, 3, 4],
        [1, 2, 6],
        [2, 1, 8],
        [3, 1, 8],
        [4, 2, 6],
        [5, 3, 4],
        [6, 4, 2],
        [7, 4, 1],
      ]},
      { w: 6, h: 9, rows: [
        [0, 2, 2],
        [1, 1, 4],
        [2, 0, 6],
        [3, 0, 6],
        [4, 0, 6],
        [5, 1, 4],
        [6, 2, 2],
        [7, 2, 2],
        [8, 2, 1],
      ]},
      { w: 8, h: 9, rows: [
        [0, 2, 4],
        [1, 1, 6],
        [2, 0, 8],
        [3, 0, 8],
        [4, 1, 6],
        [5, 2, 4],
        [6, 3, 3],
        [7, 3, 2],
        [8, 3, 1],
      ]},
      { w: 7, h: 7, rows: [
        [0, 2, 3],
        [1, 1, 5],
        [2, 0, 7],
        [3, 0, 7],
        [4, 1, 5],
        [5, 3, 2],
        [6, 3, 1],
      ]},
      { w: 5, h: 10, rows: [
        [0, 1, 3],
        [1, 0, 5],
        [2, 0, 5],
        [3, 0, 5],
        [4, 0, 5],
        [5, 0, 5],
        [6, 1, 3],
        [7, 1, 3],
        [8, 1, 2],
        [9, 2, 1],
      ]},
    ]

    palettes.each do |_name, (core, highlight, shadow, vein)|
      shapes.each do |shape|
        bm    = Bitmap.new(shape[:w], shape[:h])
        mid_y = shape[:h] / 2

        shape[:rows].each do |ry, rx, rw|
          bm.fill_rect(rx, ry, rw, 1, core)

          if rw > 1
            bm.set_pixel(rx,          ry, shadow)
            bm.set_pixel(rx + rw - 1, ry, shadow)
          end

          if ry < mid_y
            bm.set_pixel(rx + 1,      ry, highlight) if rw > 3
            bm.set_pixel(rx + rw - 2, ry, highlight) if rw > 4
          end
        end

        shape[:rows].each do |ry, rx, rw|
          next if rw < 2
          bm.set_pixel(rx + rw / 2, ry, vein)
        end

        fx[:bitmaps].push(bm)
      end
    end
  end

  def petal_setup_layer
    fx = petal_fx
    fx[:sprites] = []
    fx[:info]    = []
    fx[:viewport]   = Viewport.new(0, 0, Graphics.width, Graphics.height)
    fx[:viewport].z = 200
    PETAL_SPRITE_COUNT.times do
      bm             = fx[:bitmaps][rand(fx[:bitmaps].size)]
      sprite         = Sprite.new(fx[:viewport])
      sprite.z       = 1000
      sprite.bitmap  = bm
      sprite.ox      = bm.width  / 2
      sprite.oy      = bm.height / 2
      sprite.angle   = rand(360)
      sprite.opacity = rand(170) + 50

      wx = cw_spawn_x
      wy = cw_map_offset_y + rand(Graphics.height)
      sprite.x = cw_world_to_screen_x(wx)
      sprite.y = cw_world_to_screen_y(wy)

      fx[:sprites].push(sprite)
      angle_speed = (rand(30) - 15) * 0.1
      fx[:info].push([rand(2) + 1, rand(140), rand(60), sprite.angle.to_f, angle_speed, wx, wy])
    end
    fx[:active] = true
  end

  def petal_update_sprites
    fx = petal_fx
    fx[:sprites].each_with_index do |sprite, i|
      speed, sway, wobble, angle, angle_speed, wx, wy = fx[:info][i]
      wx += @cw_frame_jump_x
      wy += @cw_frame_jump_y

      wy += speed == 2 ? 1 : (Graphics.frame_count % 2 == i % 2 ? 1 : 0)

      sway = (sway + 1) % 140
      wx -= 1 if sway < 35
      wx += 1 if sway >= 105

      angle += angle_speed
      sprite.angle = angle.round % 360

      wobble = (wobble + 1) % 60
      sprite.opacity += wobble < 30 ? 1 : -1

      sprite.x = cw_world_to_screen_x(wx)
      sprite.y = cw_world_to_screen_y(wy)

      fx[:info][i] = [speed, sway, wobble, angle, angle_speed, wx, wy]

      # Wrap against the current camera offset every frame (Spores-style)
      # instead of only checking after the screen position is set, so a
      # fast pan can't outrun the check and leave a backlog off-screen.
      ox = cw_map_offset_x
      oy = cw_map_offset_y
      wrapped = false

      if wy > oy + Graphics.height + sprite.bitmap.height
        wy = oy + (-sprite.bitmap.height - rand(30))
        wrapped = true
      elsif wy < oy - sprite.bitmap.height - 30
        wy = oy + rand(Graphics.height)
        wrapped = true
      end

      if wx < ox - CW_HORIZONTAL_SPAWN_PAD || wx > ox + Graphics.width + CW_HORIZONTAL_SPAWN_PAD
        wx = cw_spawn_x
        wrapped = true
      end

      if wrapped
        bm             = fx[:bitmaps][rand(fx[:bitmaps].size)]
        sprite.bitmap  = bm
        sprite.ox      = bm.width  / 2
        sprite.oy      = bm.height / 2
        sprite.angle   = rand(360)
        sprite.opacity = rand(170) + 50
        angle_speed    = (rand(30) - 15) * 0.1
        speed          = rand(2) + 1
        sway           = rand(140)
        wobble         = rand(60)
        angle          = sprite.angle.to_f
      end

      sprite.x = cw_world_to_screen_x(wx)
      sprite.y = cw_world_to_screen_y(wy)

      fx[:info][i] = [speed, sway, wobble, angle, angle_speed, wx, wy]
    end
  end

  def petal_clear_layer
    fx = petal_fx
    fx[:sprites].each { |s| s.dispose }
    fx[:sprites].clear
    fx[:info].clear
    fx[:viewport].dispose if fx[:viewport]
    fx[:viewport] = nil
    fx[:active]   = false
  end
end

CustomWeather::SpritesetHandlers.register(:FallingPetals) do |spriteset|
  spriteset.instance_eval do
    fx = petal_fx
    petal_make_bitmaps unless fx[:bitmaps]

    if $game_screen.weather_type == :FallingPetals
      if CustomWeather::PersistentFX.once_per_frame?(:FallingPetals)
        petal_setup_layer unless fx[:active]
        petal_update_sprites
      end
      cw_weather_grace_reset(:FallingPetals)
    elsif fx[:active] && cw_weather_should_clear?(:FallingPetals)
      petal_clear_layer
    end
  end
end

CustomWeather::SpritesetHandlers.register_dispose(:FallingPetals) do |spriteset|
  spriteset.instance_eval do
    fx = petal_fx
    still_wanted = $game_screen && $game_screen.weather_type == :FallingPetals
    unless still_wanted
      petal_clear_layer if fx[:active]
      if fx[:bitmaps]
        fx[:bitmaps].each { |bm| bm.dispose }
        fx[:bitmaps] = nil
      end
    end
  end
end

CustomWeather.register_weather(
  { :id => :FallingPetals, :id_number => 16, :category => :None, :graphics => [],
    :tone_proc => proc { |strength| Tone.new(strength / 6, -strength / 12, -strength / 8, 0) } },
  { :id => :FallingPetals, :name => _INTL("Falling Petals"), :animation => "FallingPetals" }
)

CustomWeather::Handlers::StartMessage.add(:FallingPetals,
  proc { |weather, battle| next _INTL("Colourful petals began to flutter down!") })
CustomWeather::Handlers::ContinueMessage.add(:FallingPetals,
  proc { |weather, battle| next _INTL("Petals continue to drift gently through the air.") })
CustomWeather::Handlers::EndMessage.add(:FallingPetals,
  proc { |weather, battle| next _INTL("The petals settled on the ground.") })
