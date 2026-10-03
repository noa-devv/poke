GLITCH_SPRITE_COUNT = 55

GLITCH_FADE_IN   = 30
GLITCH_ACTIVE    = 150
GLITCH_FADE_OUT  = 30
GLITCH_SILENT    = 90
GLITCH_CYCLE     = GLITCH_FADE_IN + GLITCH_ACTIVE + GLITCH_FADE_OUT + GLITCH_SILENT

class Spriteset_Map
  def glitch_fx
    CustomWeather::PersistentFX.state(:Glitch)
  end

  def glitch_make_bitmaps
    fx = glitch_fx
    fx[:bitmaps] = []

    palettes = [
      Color.new(  0, 230, 255, 255),
      Color.new(  0, 200, 255, 255),
      Color.new( 20,  80, 255, 255),
      Color.new(  0,  40, 220, 255),
      Color.new(230,   0,  60, 255),
      Color.new(200,  10,  30, 255),
      Color.new(255,  20, 180, 255),
      Color.new(220,   0, 200, 255),
    ]

    widths  = [18, 28, 40, 55, 75, 100, 130, 160, 200, 240, 280, 320]
    heights = [1, 1, 1, 2, 2, 3, 4]

    palettes.each do |col|
      widths.each do |w|
        heights.each do |h|
          bm = Bitmap.new(w, h)
          fade = [w / 6, 12].min
          bm.fill_rect(fade, 0, w - fade * 2, h, col)
          fade.times do |fxi|
            a = ((fxi.to_f / fade) * col.alpha).round
            cap = Color.new(col.red, col.green, col.blue, a)
            bm.fill_rect(fxi,             0, 1, h, cap)
            bm.fill_rect(w - 1 - fxi,     0, 1, h, cap)
          end
          fx[:bitmaps].push(bm)
        end
      end
    end
  end

  def glitch_setup_layer
    fx = glitch_fx
    fx[:sprites] = []
    fx[:info]    = []
    fx[:viewport]   = Viewport.new(0, 0, Graphics.width, Graphics.height)
    fx[:viewport].z = 210
    fx[:viewport].ox = 0

    GLITCH_SPRITE_COUNT.times do
      sprite        = Sprite.new(fx[:viewport])
      sprite.z      = 1000
      sprite.bitmap = fx[:bitmaps][rand(fx[:bitmaps].size)]
      sprite.x      = rand(Graphics.width)
      sprite.y      = rand(Graphics.height)
      sprite.opacity = 0
      fx[:sprites].push(sprite)
      fx[:info].push([rand(20) + 5, rand(180) + 60])
    end

    fx[:phase]     = 0
    fx[:master_op] = 0
    fx[:active]    = true
  end

  def glitch_update_sprites
    fx = glitch_fx
    fx[:phase] = (fx[:phase] + 1) % GLITCH_CYCLE

    if fx[:phase] < GLITCH_FADE_IN
      fx[:master_op] = ((fx[:phase].to_f / GLITCH_FADE_IN) * 255).round
    elsif fx[:phase] < GLITCH_FADE_IN + GLITCH_ACTIVE
      fx[:master_op] = 220 + rand(35)
    elsif fx[:phase] < GLITCH_FADE_IN + GLITCH_ACTIVE + GLITCH_FADE_OUT
      elapsed = fx[:phase] - GLITCH_FADE_IN - GLITCH_ACTIVE
      fx[:master_op] = ((1.0 - elapsed.to_f / GLITCH_FADE_OUT) * 255).round
    else
      fx[:master_op] = 0
    end
    fx[:master_op] = fx[:master_op].clamp(0, 255)

    in_active = (fx[:phase] >= GLITCH_FADE_IN &&
                 fx[:phase] < GLITCH_FADE_IN + GLITCH_ACTIVE)

    fx[:sprites].each_with_index do |sprite, i|
      jump_cd, base_op = fx[:info][i]

      if fx[:master_op] == 0
        sprite.opacity = 0
        next
      end

      if in_active
        jump_cd -= 1
        if jump_cd <= 0
          sprite.bitmap = fx[:bitmaps][rand(fx[:bitmaps].size)]
          sprite.x      = rand(Graphics.width + 40) - 20
          sprite.y      = rand(Graphics.height)
          base_op       = rand(180) + 60
          jump_cd       = rand(25) + 4

          sprite.x += rand(30) - 5 if rand(8) == 0
        end
        fx[:info][i] = [jump_cd, base_op]
      end

      sprite.opacity = ((base_op / 255.0) * fx[:master_op]).round.clamp(0, 255)
    end
  end

  def glitch_clear_layer
    fx = glitch_fx
    fx[:sprites].each { |s| s.dispose }
    fx[:sprites].clear
    fx[:info].clear
    fx[:viewport].dispose if fx[:viewport]
    fx[:viewport]  = nil
    fx[:phase]     = 0
    fx[:master_op] = 0
    fx[:active]    = false
  end
end

CustomWeather::SpritesetHandlers.register(:Glitch) do |spriteset|
  spriteset.instance_eval do
    fx = glitch_fx
    glitch_make_bitmaps unless fx[:bitmaps]

    if $game_screen.weather_type == :Glitch
      if CustomWeather::PersistentFX.once_per_frame?(:Glitch)
        glitch_setup_layer unless fx[:active]
        glitch_update_sprites
      end
      cw_weather_grace_reset(:Glitch)
    elsif fx[:active] && cw_weather_should_clear?(:Glitch)
      glitch_clear_layer
    end
  end
end

CustomWeather::SpritesetHandlers.register_dispose(:Glitch) do |spriteset|
  spriteset.instance_eval do
    fx = glitch_fx
    still_wanted = $game_screen && $game_screen.weather_type == :Glitch
    unless still_wanted
      glitch_clear_layer if fx[:active]
      if fx[:bitmaps]
        fx[:bitmaps].each { |bm| bm.dispose }
        fx[:bitmaps] = nil
      end
    end
  end
end

CustomWeather.register_cosmetic_weather(
  { :id => :Glitch, :id_number => 21, :category => :None, :graphics => [],
    :tone_proc => proc { |strength|
      Tone.new(-strength / 14, -strength / 10, strength / 8, strength / 12)
    }
  }
)
