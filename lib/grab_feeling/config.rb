#-*- coding: utf-8 -*-
require 'yaml'

module GrabFeeling
  module Config
    @@yaml = nil
    SAMPLE_CONFIG = File.expand_path("#{File.dirname(__FILE__)}/../../config.sample.yml")
    CONFIG_FILE = File.expand_path("#{File.dirname(__FILE__)}/../../config.sample.yml")
    class << self
      def [](x)
        yaml[x]
      end

      def yaml(force_reload=false)
        if force_reload || !@@yaml
          @@yaml = YAML.load_file(File.exist?(CONFIG_FILE) ? CONFIG_FILE : SAMPLE_CONFIG)
        else
          @@yaml
        end
      end
    end
  end
end
