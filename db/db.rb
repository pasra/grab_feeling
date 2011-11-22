#-*- coding: utf-8 -*-
require_relative '../init'
require_relative '../lib/grab_feeling/config'
require 'active_record'
require 'logger'

ActiveRecord::Base.logger = Logger.new(STDOUT)
ActiveRecord::Base.logger.formatter = proc{|s,d,p,m| " #{m}\n" }

ActiveRecord::Base.establish_connection(GrabFeeling::Config["database"][ENV["RACK_ENV"].to_s])
