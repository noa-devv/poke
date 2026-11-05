
#===============================================================================
# Grass Rustling Per Map
# Pokémon Essentials v21.1
#
# Allows different animation spritesheets for grass rustling on each map.
# Uses the existing Essentials grass animation and preserves its timings,
# frames, positions and other settings.
#===============================================================================

module GrassRustlingPerMap

  #---------------------------------------------------------------------------
  # Configuration
  #---------------------------------------------------------------------------

  # Original spritesheet used by the default grass animation.
  BASE_SHEET_NAME = "Overworld dust and grass"

  # Map ID => Alternative spritesheet name.
  # Files must be located in Graphics/Animations/.
  # Do not include the .png extension.
  MAP_SHEETS = {
    78 => "Overworld dust and grass yellow"
  }

  #---------------------------------------------------------------------------
  # Get the spritesheet configured for a map
  #---------------------------------------------------------------------------

  def self.sheet_for(map_id)
    return MAP_SHEETS[map_id]
  end

end

#===============================================================================
# Spriteset_Map
#===============================================================================

class Spriteset_Map

  unless method_defined?(:grp_original_add_user_animation)

    alias grp_original_add_user_animation addUserAnimation

    def addUserAnimation(animation_id, x, y, *args)

      # Only modify the default grass rustling animation.
      if animation_id == Settings::GRASS_ANIMATION_ID

        map_id = self.map.map_id
        sheet_name = GrassRustlingPerMap.sheet_for(map_id)

        if sheet_name

          original_animation = $data_animations[animation_id]

          if original_animation

            # Clone the animation to avoid modifying the original data.
            custom_animation = Marshal.load(
              Marshal.dump(original_animation)
            )

            replaced = false

            # Replace the original spritesheet while preserving the
            # other animation graphic if it uses a different file.
            [:animation_name, :animation_name2].each do |property|

              next unless custom_animation.respond_to?(property)
              next unless custom_animation.respond_to?("#{property}=")

              if custom_animation.send(property) ==
                 GrassRustlingPerMap::BASE_SHEET_NAME

                custom_animation.send("#{property}=", sheet_name)
                replaced = true

              end
            end

            if replaced

              # Temporarily provide the modified animation to Essentials.
              $data_animations[animation_id] = custom_animation

              begin

                grp_original_add_user_animation(
                  animation_id, x, y, *args
                )

              ensure

                # Restore the original animation data.
                $data_animations[animation_id] = original_animation

              end

              return

            end
          end
        end
      end

      # Default behaviour for all other animations and maps.
      grp_original_add_user_animation(animation_id, x, y, *args)

    end
  end

end