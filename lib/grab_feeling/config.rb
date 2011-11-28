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
        if Config["theme_opening"] && (timings = Config["theme_opening"]["timings"])
          Config["theme_opening"]["timings"] = timings.to_a.sort_by(&:first).reverse
          Config["theme_opening"]["timings"].map! {|(t,percent)| [t, percent/100.0] }
        end
      end
    end
  end
end
