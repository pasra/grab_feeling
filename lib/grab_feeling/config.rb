#-*- coding: utf-8 -*-
require 'yaml'

module GrabFeeling
  module Config
    @@yaml = nil
    SAMPLE_CONFIG = File.expand_path("#{File.dirname(__FILE__)}/../../config.sample.yml")
    CONFIG_FILE = File.expand_path("#{File.dirname(__FILE__)}/../../config.yml")
    class << self
      def [](x)
        yaml[x]
      end

      def yaml(force_reload=false)
        if force_reload || !@@yaml
          @@yaml = YAML.load_file(File.exist?(CONFIG_FILE) ? CONFIG_FILE : SAMPLE_CONFIG)
          after_load
          @@yaml
        else
          @@yaml
        end
      end

      def after_load
        if Config["theme_opening"] && Config["theme_opening"]["timing"]
          timings = Config["theme_opening"]["timing"].to_a
          Config["theme_opening"]["timing"] = timings.each_with_index.map do |t,i|
            [t[0] - (i-1 > 0 ? timings[i-1][0] : 0), t[1]]
          end
        end
      end
    end
  end
end
