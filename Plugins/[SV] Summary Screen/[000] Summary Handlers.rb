#-------------------------------------------------------------------------------
# Pokemon Summary handlers.
# (Decapitalises and changes page names from Modular UI Scenes)
#-------------------------------------------------------------------------------

# Info page.
UIHandlers.add(:summary, :page_info, { 
  "name"      => "Pokémon Info",
  "suffix"    => "info",
  "order"     => 10,
  "options"   => [:item, :nickname, :pokedex, :mark],
  "layout"    => proc { |pkmn, scene| scene.drawPageOne }
})

# Memo page.
UIHandlers.add(:summary, :page_memo, {
  "name"      => "Trainer Memo",
  "suffix"    => "memo",
  "order"     => 20,
  "options"   => [:item, :nickname, :pokedex, :mark],
  "layout"    => proc { |pkmn, scene| scene.drawPageTwo }
})

# Stat page.
UIHandlers.add(:summary, :page_skills, {
  "name"      => "Pokémon Skills",
  "suffix"    => "skills",
  "order"     => 30,
  "options"   => [:item, :nickname, :pokedex, :mark],
  "layout"    => proc { |pkmn, scene| scene.drawPageThree }
})

# Moves page.
UIHandlers.add(:summary, :page_moves, {
  "name"      => "Battle Moves",
  "suffix"    => "moves",
  "order"     => 40,
  "options"   => [:moves, :remember, :forget, :tms],
  "layout"    => proc { |pkmn, scene| scene.drawPageFour }
})

# Ribbons page.
UIHandlers.add(:summary, :page_ribbons, {
  "name"      => "Ribbons",
  "suffix"    => "ribbons",
  "order"     => 50,
  "layout"    => proc { |pkmn, scene| scene.drawPageFive }
})

#-------------------------------------------------------------------------------
# Egg Summary handlers.
#-------------------------------------------------------------------------------

# Info page.
UIHandlers.add(:summary, :page_egg, {
  "name"      => "Trainer Memo",
  "suffix"    => "egg",
  "order"     => 10,
  "onlyEggs"  => true,
  "options"   => [:mark],
  "layout"    => proc { |pkmn, scene| scene.drawPageOneEgg }
})