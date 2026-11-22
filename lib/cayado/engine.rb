require "rails/engine"

module Cayado
  class Engine < ::Rails::Engine
    isolate_namespace Cayado

    config.generators do |g|
      g.test_framework :rspec
    end
  end
end
