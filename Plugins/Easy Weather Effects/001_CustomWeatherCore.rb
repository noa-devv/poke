module CustomWeather
  OVERWORLD_TO_BATTLE = {}
  CUSTOM_WEATHER_IDS = []
  COSMETIC_WEATHER_IDS = []
  CONNECTION_MAP_GROUPS = {}

  def self.custom_weather?(weather_id)
    CUSTOM_WEATHER_IDS.include?(weather_id)
  end

  def self.cosmetic_weather?(weather_id)
    COSMETIC_WEATHER_IDS.include?(weather_id)
  end

  def self.custom_overworld_weather?(weather_id)
    custom_weather?(weather_id) || cosmetic_weather?(weather_id)
  end

  def self.register(overworld_id, battle_id = nil)
    CUSTOM_WEATHER_IDS.push(overworld_id) unless CUSTOM_WEATHER_IDS.include?(overworld_id)
    OVERWORLD_TO_BATTLE[overworld_id] = battle_id if battle_id
  end

  def self.get_battle_weather(overworld_weather)
    OVERWORLD_TO_BATTLE[overworld_weather]
  end

  def self.register_connection_maps(group, map_ids, weather_ids)
    CONNECTION_MAP_GROUPS[group] = { maps: Array(map_ids), weathers: Array(weather_ids) }
  end

  CONNECTION_WEATHER_MAX_HOPS = 2

  # Walks the connection graph outward from start_id (up to
  # CONNECTION_WEATHER_MAX_HOPS steps) and returns the first table-registered
  # weather found on a neighboring map, or nil. Shared by weather_for_map
  # (which map to actually inherit weather from) and connection_map_for?
  # (whether a map is reachable from the given weather's group at all).
  def self.nearby_table_weather(start_id)
    return nil unless @map_weather_table
    visited = { start_id => true }
    frontier = [start_id]
    CONNECTION_WEATHER_MAX_HOPS.times do
      next_frontier = []
      frontier.each do |id|
        MapFactoryHelper.eachConnectionForMap(id) do |conn|
          other = (conn[0] == id) ? conn[3] : conn[0]
          next if visited[other]
          visited[other] = true
          candidate = @map_weather_table[other]
          return candidate if candidate
          next_frontier.push(other)
        end
      end
      frontier = next_frontier
      break if frontier.empty?
    end
    nil
  end

  def self.connection_map_for?(map_id, weather_key)
    return true if CONNECTION_MAP_GROUPS.values.any? { |g| g[:weathers].include?(weather_key) && g[:maps].include?(map_id) }
    nearby_table_weather(map_id) == weather_key
  end

  def self.register_weather(overworld_data, battle_data)
    GameData::Weather.register(overworld_data) if overworld_data
    GameData::BattleWeather.register(battle_data) if battle_data
    overworld_id = overworld_data ? overworld_data[:id] : nil
    battle_id = battle_data ? battle_data[:id] : nil
    if overworld_id && battle_id
      register(overworld_id, battle_id)
    elsif battle_id
      CUSTOM_WEATHER_IDS.push(battle_id) unless CUSTOM_WEATHER_IDS.include?(battle_id)
    end
  end

  def self.register_cosmetic_weather(overworld_data)
    GameData::Weather.register(overworld_data)
    id = overworld_data[:id]
    COSMETIC_WEATHER_IDS.push(id) unless COSMETIC_WEATHER_IDS.include?(id)
  end

  def self.setMapWeather(weather_id, probability = 100, strength = 9)
    return if probability < 100 && rand(100) >= probability
    $game_screen.weather(weather_id, strength, 0)
  end

  def self.weatherActive?(weather_id)
    $game_screen.weather_type == weather_id
  end

  def self.currentWeather
    $game_screen.weather_type
  end

  module PersistentFX
    @store = {}
    @frame_stamp = {}

    def self.state(key)
      @store[key] ||= {}
    end

    def self.active?(key)
      @store[key] && @store[key][:active]
    end

    def self.once_per_frame?(key)
      frame = Graphics.frame_count
      return false if @frame_stamp[key] == frame
      @frame_stamp[key] = frame
      true
    end

    def self.reset!(key)
      @store.delete(key)
      @frame_stamp.delete(key)
    end

    def self.reset_all!
      @store.clear
      @frame_stamp.clear
    end

    def self.dispose_all!
      @store.each_value do |fx|
        fx[:sprites]&.each { |s| s.dispose unless s.disposed? }
        fx[:tile_sprites]&.each { |s| s.dispose unless s.disposed? }
        fx[:viewport].dispose if fx[:viewport] && !fx[:viewport].disposed?
        bitmaps = fx[:bitmaps]
        if bitmaps.is_a?(Array)
          bitmaps.each { |bm| bm.dispose unless bm.disposed? }
        elsif bitmaps.is_a?(Hash)
          bitmaps.each_value do |v|
            if v.is_a?(Array)
              v.each { |bm| bm.dispose unless bm.disposed? }
            else
              v.dispose unless v.disposed?
            end
          end
        end
      end
      reset_all!
    end
  end

  module Handlers
    EORDamage = HandlerHash.new
    DamageImmunity = HandlerHash.new
    TypeBoost = HandlerHash.new
    StartMessage = HandlerHash.new
    ContinueMessage = HandlerHash.new
    EndMessage = HandlerHash.new

    def self.triggerEORDamage(weather, battler, battle)
      EORDamage.trigger(weather, weather, battler, battle)
    end

    def self.triggerDamageImmunity(weather, battler)
      DamageImmunity.trigger(weather, weather, battler) == true
    end

    def self.triggerTypeBoost(weather, move_type, user, target)
      TypeBoost.trigger(weather, weather, move_type, user, target) || 1.0
    end

    def self.triggerStartMessage(weather, battle)
      StartMessage.trigger(weather, weather, battle)
    end

    def self.triggerContinueMessage(weather, battle)
      ContinueMessage.trigger(weather, weather, battle)
    end

    def self.triggerEndMessage(weather, battle)
      EndMessage.trigger(weather, weather, battle)
    end

    def self.add_eor_damage(weather_id, &handler)
      EORDamage.add(weather_id, handler)
    end

    def self.add_damage_immunity(weather_id, &handler)
      DamageImmunity.add(weather_id, handler)
    end

    def self.add_type_boost(weather_id, &handler)
      TypeBoost.add(weather_id, handler)
    end

    def self.add_start_message(weather_id, &handler)
      StartMessage.add(weather_id, handler)
    end

    def self.add_continue_message(weather_id, &handler)
      ContinueMessage.add(weather_id, handler)
    end

    def self.add_end_message(weather_id, &handler)
      EndMessage.add(weather_id, handler)
    end

    def self.register_all(weather_id, handlers = {})
      EORDamage.add(weather_id, handlers[:eor_damage]) if handlers[:eor_damage]
      DamageImmunity.add(weather_id, handlers[:damage_immunity]) if handlers[:damage_immunity]
      TypeBoost.add(weather_id, handlers[:type_boost]) if handlers[:type_boost]
      StartMessage.add(weather_id, handlers[:start_message]) if handlers[:start_message]
      ContinueMessage.add(weather_id, handlers[:continue_message]) if handlers[:continue_message]
      EndMessage.add(weather_id, handlers[:end_message]) if handlers[:end_message]
    end
  end

  @map_weather_table = nil
  @map_weather_strength = 9
end

def pbSetCustomWeather(weather_id, strength = 9, duration = 0)
  $game_screen.weather(weather_id, strength, duration)
end

def pbSetBattleWeather(weather_id)
  if CustomWeather.cosmetic_weather?(weather_id)
    raise ArgumentError, "#{weather_id} is a cosmetic-only weather and has no battle counterpart"
  end
  setBattleRule("weather", weather_id)
end

def pbClearWeather(duration = 20)
  $game_screen.weather(:None, 0, duration)
end
