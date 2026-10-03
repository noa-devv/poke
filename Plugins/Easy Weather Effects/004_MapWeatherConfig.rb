#===============================================================================
# Map Weather Config
# Single source of truth for which maps get which weather, and which of
# those maps use the connection-map no-restart behaviour.
#
# Edit MAP_WEATHER_DATA below. Nothing else in this file needs to change.
#===============================================================================
module CustomWeather
  module MapWeatherConfig

    # group_name => {
    #   maps:     [map_id, map_id, ...],
    #   weather:  :WeatherID,
    #   strength: 9,              # tone strength used for auto-applied weather
    #   connection: true/false,   # true = uses cw_weather_should_clear? grace period
    # }
    MAP_WEATHER_DATA = {
      spore_zone: {
        maps:       [32, 34, 33, 26, 108],
        weather:    :Spores,
        strength:   9,
        connection: true
      },

       Diamond_zone: {
         maps:       [55, 75],
         weather:    :DiamondDust,
         strength:   6,
         connection: true
       },

      # Example additional groups — copy the pattern above, delete if unused.
      # desert_zone: {
      #   maps:       [10, 11, 12],
      #   weather:    :Sandstorm,
      #   strength:   9,
      #   connection: true
      # },
      # coastal_zone: {
      #   maps:       [30, 31],
      #   weather:    :Rain,
      #   strength:   9,
      #   connection: false
      # },
    }

    def self.apply!
      table = {}
      MAP_WEATHER_DATA.each do |group, data|
        if data[:connection]
          CustomWeather.register_connection_maps(group, data[:maps], [data[:weather]])
        end
        data[:maps].each { |map_id| table[map_id] = data[:weather] }
      end
      CustomWeather.setupMapWeatherTable(table)
    end
  end
end

CustomWeather::MapWeatherConfig.apply!
