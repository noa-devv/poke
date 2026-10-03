class Battle
  unless @__customweather_battle_patched
    @__customweather_battle_patched = true

    alias customweather_pbEORWeatherDamage pbEORWeatherDamage
    def pbEORWeatherDamage(battler)
      unless CustomWeather.custom_weather?(battler.effectiveWeather)
        return customweather_pbEORWeatherDamage(battler)
      end
      return if battler.fainted?
      CustomWeather::Handlers.triggerEORDamage(battler.effectiveWeather, battler, self)
      return if battler.fainted?
      battler.pbItemHPHealCheck
      battler.pbAbilitiesOnDamageTaken
      battler.pbFaint if battler.fainted?
    end

    alias customweather_pbEOREndWeather pbEOREndWeather
    def pbEOREndWeather(priority)
      unless CustomWeather.custom_weather?(@field.weather)
        return customweather_pbEOREndWeather(priority)
      end
      @field.weatherDuration -= 1 if @field.weatherDuration > 0
      if @field.weatherDuration == 0
        end_msg = CustomWeather::Handlers.triggerEndMessage(@field.weather, self)
        pbDisplay(end_msg) if end_msg
        @field.weather = :None
        allBattlers.each { |b| b.pbCheckFormOnWeatherChange }
        pbStartWeather(nil, @field.defaultWeather) if @field.defaultWeather != :None
        return if @field.weather == :None
      end
      weather_data = GameData::BattleWeather.try_get(@field.weather)
      pbCommonAnimation(weather_data.animation) if weather_data
      continue_msg = CustomWeather::Handlers.triggerContinueMessage(@field.weather, self)
      pbDisplay(continue_msg) if continue_msg
      priority.each do |battler|
        if battler.abilityActive?
          Battle::AbilityEffects.triggerEndOfRoundWeather(battler.ability, battler.effectiveWeather, battler, self)
          battler.pbFaint if battler.fainted?
        end
        pbEORWeatherDamage(battler)
      end
    end

    alias customweather_pbStartWeather pbStartWeather
    def pbStartWeather(user, newWeather, fixedDuration = false, showAnimation = true)
      unless CustomWeather.custom_weather?(newWeather)
        return customweather_pbStartWeather(user, newWeather, fixedDuration, showAnimation)
      end
      return if @field.weather == newWeather
      if respond_to?(:field_blocks_weather?) && field_blocks_weather?(newWeather)
        if respond_to?(:field_weather_block_message)
          msg = field_weather_block_message(newWeather)
          pbDisplay(msg) if msg
        end
        return
      end
      @field.weather = newWeather
      if fixedDuration
        @field.weatherDuration = 5
        @field.weatherDuration = 8 if user && user.hasActiveItem?(:WEATHEREXTENDER)
      else
        @field.weatherDuration = -1
      end
      if fixedDuration && has_field? && respond_to?(:current_field)
        field_data = current_field
        if field_data.respond_to?(:weatherDuration)
          ext = field_data.weatherDuration[newWeather]
          @field.weatherDuration = ext if ext && ext > @field.weatherDuration
        end
      end
      if showAnimation
        weather_data = GameData::BattleWeather.try_get(@field.weather)
        pbCommonAnimation(weather_data.animation) if weather_data
      end
      start_msg = CustomWeather::Handlers.triggerStartMessage(newWeather, self)
      pbDisplay(start_msg) if start_msg
      allBattlers.each { |b| b.pbCheckFormOnWeatherChange }
      pbStartWeatherAbilities(newWeather)
    end

    def pbStartWeatherAbilities(weather)
      pbPriority(true).each { |battler| battler.pbAbilityOnTerrainChange if battler.abilityActive? }
    end
  end
end

class Battle::Move
  unless @__customweather_damagecalc_patched
    @__customweather_damagecalc_patched = true

    alias customweather_pbCalcDamageMultipliers pbCalcDamageMultipliers
    def pbCalcDamageMultipliers(user, target, numTargets, type, baseDmg, multipliers)
      customweather_pbCalcDamageMultipliers(user, target, numTargets, type, baseDmg, multipliers)
      weather = user.effectiveWeather
      return unless CustomWeather.custom_weather?(weather) && type
      boost = CustomWeather::Handlers.triggerTypeBoost(weather, type, user, target)
      multipliers[:final_damage_multiplier] *= boost if boost && boost != 1.0
    end
  end
end

module BattleCreationHelperMethods
  unless singleton_class.instance_variable_get(:@__customweather_battlestart_patched)
    singleton_class.instance_variable_set(:@__customweather_battlestart_patched, true)

    class << self
      alias customweather_prepare_battle prepare_battle
    end

    def self.prepare_battle(battle)
      customweather_prepare_battle(battle)
      battleRules = $game_temp.battle_rules
      if battleRules["defaultWeather"].nil?
        overworld_weather = $game_screen.weather_type
        battle_weather = CustomWeather.get_battle_weather(overworld_weather)
        battle.defaultWeather = battle_weather if battle_weather
      end
    end
  end
end
