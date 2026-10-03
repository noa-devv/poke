DIAMOND_DUST_SPRITE_COUNT = 320
DIAMOND_DUST_WRAP_MARGIN  = 60
DIAMOND_DUST_FADE_STEP    = 8

class Spriteset_Map
  def diamond_dust_fx
    CustomWeather::PersistentFX.state(:DiamondDust)
  end

  def diamond_dust_make_bitmaps
    fx = diamond_dust_fx
    return if fx[:bitmaps]
    fx[:bitmaps] = []

    colours = [
      [Color.new(200, 230, 255,  80), Color.new(230, 245, 255, 160), Color.new(255, 255, 255, 220)],
      [Color.new(180, 215, 255,  70), Color.new(210, 235, 255, 150), Color.new(245, 252, 255, 210)],
      [Color.new(220, 240, 255,  90), Color.new(240, 250, 255, 170), Color.new(255, 255, 255, 240)],
    ]

    colours.each do |dim, bright, core|
      bm = Bitmap.new(3, 3)
      bm.set_pixel(1, 1, dim)
      fx[:bitmaps].push(bm)

      bm = Bitmap.new(3, 3)
      bm.set_pixel(1, 1, bright)
      fx[:bitmaps].push(bm)

      bm = Bitmap.new(5, 5)
      bm.fill_rect(2, 1, 1, 3, bright)
      bm.fill_rect(1, 2, 3, 1, bright)
      bm.set_pixel(2, 2, core)
      fx[:bitmaps].push(bm)

      bm = Bitmap.new(9, 9)
      bm.fill_rect(4, 0, 1, 9, dim)
      bm.fill_rect(0, 4, 9, 1, dim)
      bm.fill_rect(4, 1, 1, 7, bright)
      bm.fill_rect(1, 4, 7, 1, bright)
      bm.fill_rect(4, 2, 1, 5, core)
      bm.fill_rect(2, 4, 5, 1, core)
      bm.set_pixel(4, 4, core)
      bm.set_pixel(2, 2, dim)
      bm.set_pixel(6, 2, dim)
      bm.set_pixel(2, 6, dim)
      bm.set_pixel(6, 6, dim)
      fx[:bitmaps].push(bm)

      bm = Bitmap.new(5, 5)
      bm.fill_rect(2, 1, 1, 3, dim)
      bm.fill_rect(1, 2, 3, 1, dim)
      bm.set_pixel(2, 2, bright)
      fx[:bitmaps].push(bm)
    end

    fx[:frames]  = 5
    fx[:colours] = colours.size
  end

  def diamond_dust_wrap_width
    Graphics.width + DIAMOND_DUST_WRAP_MARGIN * 2
  end

  def diamond_dust_wrap_height
    Graphics.height + DIAMOND_DUST_WRAP_MARGIN * 2
  end

  def diamond_dust_screen_x(wx)
    ((wx - cw_map_offset_x + DIAMOND_DUST_WRAP_MARGIN) % diamond_dust_wrap_width) - DIAMOND_DUST_WRAP_MARGIN
  end

  def diamond_dust_screen_y(wy)
    ((wy - cw_map_offset_y + DIAMOND_DUST_WRAP_MARGIN) % diamond_dust_wrap_height) - DIAMOND_DUST_WRAP_MARGIN
  end

  def diamond_dust_setup_layer
    fx = diamond_dust_fx
    fx[:viewport]   = Viewport.new(0, 0, Graphics.width, Graphics.height)
    fx[:viewport].z = 200
    fx[:sprites]    = []
    fx[:info]       = []

    DIAMOND_DUST_SPRITE_COUNT.times do
      colour  = rand(fx[:colours])
      frame   = rand(fx[:frames])
      bm_idx  = colour * fx[:frames] + frame
      sprite         = Sprite.new(fx[:viewport])
      sprite.z       = 1000
      sprite.bitmap  = fx[:bitmaps][bm_idx]
      sprite.opacity = rand(180) + 40

      wx = cw_map_offset_x + rand(Graphics.width)
      wy = cw_map_offset_y + rand(Graphics.height)
      sprite.x = diamond_dust_screen_x(wx)
      sprite.y = diamond_dust_screen_y(wy)

      fall_delay = rand(4) + 1
      countdown  = rand(20) + 8
      fx[:info].push([colour, frame, countdown, rand(20) + 8, fall_delay, wx, wy])
      fx[:sprites].push(sprite)
    end

    fx[:active] = true
  end

  def diamond_dust_update_sprites
    fx = diamond_dust_fx
    frame_count = Graphics.frame_count
    fx[:sprites].each_with_index do |sprite, i|
      info       = fx[:info][i]
      colour     = info[0]
      frame      = info[1]
      countdown  = info[2]
      cycle_len  = info[3]
      fall_delay = info[4]
      wx         = info[5]
      wy         = info[6]

      wy += 1 if frame_count % fall_delay == i % fall_delay
      wx += 1 if frame_count % (fall_delay * 3) == i % (fall_delay * 3)
      wx -= 1 if frame_count % (fall_delay * 5) == i % (fall_delay * 5)

      countdown -= 1
      if countdown <= 0
        frame    = (frame + 1) % fx[:frames]
        bm_idx   = colour * fx[:frames] + frame
        sprite.bitmap = fx[:bitmaps][bm_idx]
        countdown = cycle_len
        case frame
        when 3 then sprite.opacity = rand(80) + 160
        when 0 then sprite.opacity = rand(60) + 20
        else        sprite.opacity = rand(100) + 80
        end
      end

      sprite.x = diamond_dust_screen_x(wx)
      sprite.y = diamond_dust_screen_y(wy)

      info[1] = frame
      info[2] = countdown
      info[5] = wx
      info[6] = wy
    end
  end

  def diamond_dust_clear_layer
    fx = diamond_dust_fx
    fx[:sprites]&.each { |s| s.dispose }
    fx[:sprites]  = []
    fx[:info]     = []
    fx[:viewport]&.dispose
    fx[:viewport] = nil
    fx[:active]   = false
  end

  def diamond_dust_begin_fade_out
    fx = diamond_dust_fx
    fx[:active] = false
    fx[:fading] = true
  end

  def diamond_dust_update_fade_out
    fx = diamond_dust_fx
    done = true
    fx[:sprites].each do |sprite|
      sprite.opacity = [sprite.opacity - DIAMOND_DUST_FADE_STEP, 0].max
      done = false if sprite.opacity > 0
    end
    if done
      diamond_dust_clear_layer
      fx[:fading] = false
    end
  end

  def diamond_dust_map_wants_weather?
    return false unless $game_map
    CustomWeather.table_weather_for($game_map.map_id) == :DiamondDust
  end
end

CustomWeather::SpritesetHandlers.register(:DiamondDust) do |spriteset|
  spriteset.instance_eval do
    fx = diamond_dust_fx
    diamond_dust_make_bitmaps unless fx[:bitmaps]

    if $game_screen.weather_type == :DiamondDust && diamond_dust_map_wants_weather?
      diamond_dust_clear_layer if fx[:fading]
      fx[:fading] = false
      if CustomWeather::PersistentFX.once_per_frame?(:DiamondDust)
        diamond_dust_setup_layer unless fx[:active]
        diamond_dust_update_sprites
      end
      cw_weather_grace_reset(:DiamondDust)
    elsif fx[:active] && cw_weather_should_clear?(:DiamondDust)
      diamond_dust_begin_fade_out
    elsif fx[:fading]
      diamond_dust_update_fade_out
    end
  end
end

CustomWeather::SpritesetHandlers.register_dispose(:DiamondDust) do |spriteset|
  spriteset.instance_eval do
    fx = diamond_dust_fx
    # Only tear the layer down here if the weather is genuinely off.
    # An ordinary Spriteset_Map dispose during a map transfer/connection
    # must NOT kill a still-active weather layer — that's the whole point
    # of storing it outside the spriteset instance.
    still_wanted = $game_screen && $game_screen.weather_type == :DiamondDust && diamond_dust_map_wants_weather?
    unless still_wanted
      if fx[:active] || fx[:fading]
        diamond_dust_clear_layer
        fx[:fading] = false
      end
      if fx[:bitmaps]
        fx[:bitmaps].each { |bm| bm.dispose }
        fx[:bitmaps] = nil
      end
    end
  end
end

CustomWeather.register_weather(
  { :id => :DiamondDust, :id_number => 13, :category => :Hail, :graphics => [],
    :tone_proc => proc { |strength|
      Tone.new(strength / 5, strength / 5, strength / 3, strength / 5)
    }
  },
  { :id => :DiamondDust, :name => _INTL("Diamond Dust"), :animation => "DiamondDust" }
)

CustomWeather::Handlers::StartMessage.add(:DiamondDust,
  proc { |weather, battle| next _INTL("There is a crystalline fog!") })
CustomWeather::Handlers::ContinueMessage.add(:DiamondDust,
  proc { |weather, battle| next _INTL("The crystals hang in the air!") })
CustomWeather::Handlers::EndMessage.add(:DiamondDust,
  proc { |weather, battle| next _INTL("The diamond dust settled.") })
CustomWeather::Handlers::DamageImmunity.add(:DiamondDust,
  proc { |weather, battler|
    next true if battler.pbHasType?(:ROCK)
    next true if battler.pbHasType?(:ICE)
    next true if battler.hasActiveAbility?([:OVERCOAT, :IMMUNITY, :ICEBODY, :SNOWCLOAK, :MAGICGUARD])
    next true if battler.hasActiveItem?(:SAFETYGOGGLES)
    next false
  })
CustomWeather::Handlers::EORDamage.add(:DiamondDust,
  proc { |weather, battler, battle|
    next if battler.fainted?
    next if CustomWeather::Handlers.triggerDamageImmunity(:DiamondDust, battler)
    next if !battler.takesIndirectDamage?
    battle.pbDisplay(_INTL("{1} is hit by the hard crystals!", battler.pbThis))
    battle.scene.pbDamageAnimation(battler)
    battler.pbReduceHP(battler.totalhp / 16, false)
  })