module CustomWeather
  def self.setupMapWeatherTable(map_weather, strength = 9)
    @map_weather_table = map_weather
    @map_weather_strength = strength
  end

  def self.table_weather_for(map_id)
    @map_weather_table && @map_weather_table[map_id]
  end

  def self.table_weather_strength
    @map_weather_strength || 9
  end

  # Direct table weather for this map, or - if this map has none of its own -
  # the weather reachable from it via nearby_table_weather (see
  # 001_CustomWeatherCore.rb). Lets weather already carry across a connection
  # border instead of cutting in only once the player's $game_map.map_id
  # actually flips. Memoized against the current map_id so it only
  # recomputes on an actual map change, not every frame.
  def self.weather_for_map(map_id)
    return nil unless @map_weather_table
    if @weather_lookup_map_id != map_id
      @weather_lookup_map_id = map_id
      @weather_lookup_result = @map_weather_table[map_id] || nearby_table_weather(map_id)
    end
    @weather_lookup_result
  end

  def self.applyMapWeatherFromTable
    return false unless @map_weather_table
    weather = weather_for_map($game_map.map_id)
    if weather
      strength = @map_weather_strength || 9
      if $game_screen.weather_type != weather
        $game_screen.weather(weather, strength, 0)
        return true
      end
    elsif @map_weather_table.value?($game_screen.weather_type)
      $game_screen.weather(:None, 0, 0)
      return true
    end
    false
  end

  module SpritesetHandlers
    @update_handlers = {}
    @dispose_handlers = {}

    def self.register(key, &block)
      @update_handlers[key] = block
    end

    def self.register_dispose(key, &block)
      @dispose_handlers[key] = block
    end

    def self.run_update(spriteset)
      @update_handlers.each_value { |handler| handler.call(spriteset) }
    end

    def self.run_dispose(spriteset)
      @dispose_handlers.each_value { |handler| handler.call(spriteset) }
    end
  end
end

class Spriteset_Map
  unless @custom_weather_patched
    @custom_weather_patched = true

    alias custom_weather_update_original update
    def update
      cw_track_map_offset_jump
      CustomWeather.applyMapWeatherFromTable if $game_map
      custom_weather_update_original
      CustomWeather::SpritesetHandlers.run_update(self)
      cw_update_tone_overlay
    end

    alias custom_weather_dispose_original dispose
    def dispose
      CustomWeather::SpritesetHandlers.run_dispose(self)
      # NOTE: the tone overlay is intentionally NOT disposed here. It lives in
      # CustomWeather::PersistentFX (see cw_tone_fx below), same as every other
      # weather layer, specifically so an ordinary map-transfer dispose/rebuild
      # of Spriteset_Map doesn't tear it down and force a same-frame rebuild of
      # two full-screen bitmaps on the arriving map. It's only ever torn down
      # by PersistentFX.dispose_all! (title screen reset).
      custom_weather_dispose_original
    end
  end

  def cw_tone_fx
    CustomWeather::PersistentFX.state(:__tone_overlay__)
  end

  def cw_ensure_tone_overlay
    fx = cw_tone_fx
    return if fx[:viewport] && !fx[:viewport].disposed?

    fx[:viewport]   = Viewport.new(0, 0, Graphics.width, Graphics.height)
    fx[:viewport].z = 999

    black_bitmap = Bitmap.new(Graphics.width, Graphics.height)
    black_bitmap.fill_rect(0, 0, Graphics.width, Graphics.height, Color.new(0, 0, 0))
    white_bitmap = Bitmap.new(Graphics.width, Graphics.height)
    white_bitmap.fill_rect(0, 0, Graphics.width, Graphics.height, Color.new(255, 255, 255))
    fx[:bitmaps] = [black_bitmap, white_bitmap]

    sprite         = Sprite.new(fx[:viewport])
    sprite.bitmap  = black_bitmap
    sprite.opacity = 0
    fx[:sprites]   = [sprite]
  end

  def cw_update_tone_overlay
    return if !$game_screen
    tone = $game_screen.tone
    fx = cw_tone_fx

    if tone.red == 0 && tone.green == 0 && tone.blue == 0 && tone.gray == 0
      fx[:sprites]&.first&.tap { |s| s.opacity = 0 unless s.disposed? }
      return
    end

    cw_ensure_tone_overlay
    fx = cw_tone_fx
    sprite = fx[:sprites].first
    black_bitmap, white_bitmap = fx[:bitmaps]

    avg = (tone.red + tone.green + tone.blue) / 3.0
    if avg < 0
      sprite.bitmap     = black_bitmap
      sprite.blend_type = 0
      sprite.opacity    = (-avg).clamp(0, 255)
    else
      sprite.bitmap     = white_bitmap
      sprite.blend_type = 1
      sprite.opacity    = avg.clamp(0, 255)
    end
  end

  CW_MAP_JUMP_THRESHOLD = 256

  def cw_track_map_offset_jump
    track = CustomWeather::PersistentFX.state(:__map_jump__)
    @cw_frame_jump_x = 0
    @cw_frame_jump_y = 0
    return unless $game_map
    raw_x = $game_map.display_x
    raw_y = $game_map.display_y
    if track[:last_x]
      dx = raw_x - track[:last_x]
      dy = raw_y - track[:last_y]
      @cw_frame_jump_x = dx / 4.0 if dx.abs > CW_MAP_JUMP_THRESHOLD
      @cw_frame_jump_y = dy / 4.0 if dy.abs > CW_MAP_JUMP_THRESHOLD
    end
    track[:last_x] = raw_x
    track[:last_y] = raw_y
  end

  def cw_map_offset_x(parallax: 1.0)
    ($game_map.display_x / 4.0) * parallax
  end

  def cw_map_offset_y(parallax: 1.0)
    ($game_map.display_y / 4.0) * parallax
  end

  def cw_world_to_screen_x(world_x, parallax: 1.0)
    world_x - cw_map_offset_x(parallax: parallax)
  end

  def cw_world_to_screen_y(world_y, parallax: 1.0)
    world_y - cw_map_offset_y(parallax: parallax)
  end

  CW_HORIZONTAL_SPAWN_PAD = 120

  def cw_spawn_x(width = Graphics.width, pad: CW_HORIZONTAL_SPAWN_PAD, parallax: 1.0)
    cw_map_offset_x(parallax: parallax) + rand(width + pad * 2) - pad
  end

  CW_HORIZONTAL_RECYCLE_MARGIN = 20

  def cw_off_horizontal?(sprite)
    bw = sprite.bitmap ? sprite.bitmap.width : 0
    sprite.x < -(bw + CW_HORIZONTAL_RECYCLE_MARGIN) || sprite.x > Graphics.width + CW_HORIZONTAL_RECYCLE_MARGIN
  end

  # A particle's own fall/rise/drift is slow relative to camera pan speed,
  # so running can push it past whichever screen edge its own motion never
  # approaches (the top for a falling particle, the bottom for a rising
  # one). Left unchecked it just sits off-screen accumulating in
  # world-space, then a whole run's worth of backlog re-enters the view at
  # once when the camera pans back over that ground — the "huge patch"
  # effect. These let each weather script recycle on the edge(s) its own
  # motion doesn't already cover.
  def cw_off_top_pan?(sprite)
    bh = sprite.bitmap ? sprite.bitmap.height : 0
    sprite.y < -(bh + CW_HORIZONTAL_RECYCLE_MARGIN)
  end

  def cw_off_bottom_pan?(sprite)
    sprite.y > Graphics.height + CW_HORIZONTAL_RECYCLE_MARGIN
  end

  # Falling weathers (natural recycle on hitting the bottom): fold in the
  # top-pan case alongside the existing horizontal check.
  def cw_off_screen_pan?(sprite)
    cw_off_top_pan?(sprite) || cw_off_horizontal?(sprite)
  end

  # Rising weathers (natural recycle on hitting the top): fold in the
  # bottom-pan case alongside the existing horizontal check.
  def cw_off_screen_pan_rising?(sprite)
    cw_off_bottom_pan?(sprite) || cw_off_horizontal?(sprite)
  end

  # Weathers with no dominant vertical direction (side-scrolling dust,
  # drifting fog banks): cover every edge, since none of them are ruled
  # out by the particle's own motion.
  def cw_off_screen?(sprite)
    cw_off_horizontal?(sprite) || cw_off_top_pan?(sprite) || cw_off_bottom_pan?(sprite)
  end

  CW_WEATHER_GRACE_FRAMES = 20

  def cw_weather_should_clear?(key)
    return true unless $game_map && CustomWeather.connection_map_for?($game_map.map_id, key)
    track = CustomWeather::PersistentFX.state(:__weather_grace__)
    track[key] = (track[key] || 0) + 1
    return true if track[key] > CW_WEATHER_GRACE_FRAMES
    false
  end

  def cw_weather_grace_reset(key)
    CustomWeather::PersistentFX.state(:__weather_grace__)[key] = 0
  end
end

module RPG
  class Weather
    unless @__customweather_overworld_patched
      @__customweather_overworld_patched = true

      alias_method :customweather_prepare_bitmaps, :prepare_bitmaps
      def prepare_bitmaps(new_type)
        if CustomWeather.custom_overworld_weather?(new_type)
          @weatherTypes[new_type] = [GameData::Weather.try_get(new_type), [], []]
          return
        end
        customweather_prepare_bitmaps(new_type)
      end

      alias_method :customweather_type=, :type=
      def type=(type)
        resolved = GameData::Weather.get(type).id
        unless CustomWeather.custom_overworld_weather?(resolved)
          return customweather_type=(resolved)
        end
        return if @type == resolved
        if @fading
          @max = @target_max
          @fading = false
        end
        @type = resolved
        prepare_bitmaps(@type)
        @tiles_wide = @tiles_tall = 0
        ensureSprites
        @sprites.each_with_index { |sprite, i| set_sprite_bitmap(sprite, i, @type) }
        ensureTiles
        @tiles.each_with_index { |sprite, i| set_tile_bitmap(sprite, i, @type) }
      end
    end

    alias owsfx_update update unless method_defined?(:owsfx_update)
    def update
      if @type == :Storm && !@fading && @time_until_flash > 0 && @time_until_flash - Graphics.delta <= 0
        sfx = ["OWThunder1", "OWThunder2", nil].sample
        pbSEPlay(sfx) if sfx
      end
      owsfx_update
    end
  end
end

class Game_Screen
  alias owsfx_weather weather unless method_defined?(:owsfx_weather)

  def weather(type, power, duration)
    old_type = @weather_type
    owsfx_weather(type, power, duration)

    return if @weather_type == old_type

    case @weather_type
    when :Rain        then pbBGSPlay("Rain")
    when :Storm       then pbBGSPlay("Storm")
    when :Snow        then pbBGSPlay("Snow")
    when :Blizzard    then pbBGSPlay("Blizzard")
    when :Sandstorm   then pbBGSPlay("Sandstorm")
    when :HeavyRain   then pbBGSPlay("HeavyStorm")
    when :Sun, :Sunny then pbBGSPlay("Sunny")
    when :Fog         then pbBGSPlay("Fog")
    else                   pbBGSFade(duration)
    end
  end
end

unless respond_to?(:cw_reset_cleanup_pbCallTitle, true)
  alias cw_reset_cleanup_pbCallTitle pbCallTitle

  def pbCallTitle
    CustomWeather::PersistentFX.dispose_all!
    cw_reset_cleanup_pbCallTitle
  end
end

EventHandlers.add(:on_enter_map, :set_weather,
  proc { |old_map_id|
    next if old_map_id == 0 || old_map_id == $game_map.map_id
    old_weather = $game_screen.weather_type
    table_weather = CustomWeather.weather_for_map($game_map.map_id)
    if table_weather
      new_weather = table_weather
      strength = CustomWeather.table_weather_strength
    else
      new_weather = :None
      strength = 9
      new_map_metadata = $game_map.metadata
      if new_map_metadata&.weather
        new_weather = new_map_metadata.weather[0] if rand(100) < new_map_metadata.weather[1]
      end
    end
    next if old_weather == new_weather
    $game_screen.weather(new_weather, strength, 0)
    Graphics.frame_reset
  }
)
