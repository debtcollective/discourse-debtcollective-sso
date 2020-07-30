module ::Debtcollective
  class Engine < ::Rails::Engine
    engine_name "debtcollective"
    isolate_namespace Debtcollective
  end
end
