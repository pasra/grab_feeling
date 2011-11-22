#-*- coding: utf-8 -*-
require 'active_record'
require 'logger'

require 'grab_feeling/config'

ActiveRecord::Base.logger = Logger.new(STDOUT)
ActiveRecord::Base.logger.formatter = proc{|s,d,p,m| " #{m}\n" }

ActiveRecord::Base.establish_connection(GrabFeeling::Config["database"][ENV["RACK_ENV"].to_s])
