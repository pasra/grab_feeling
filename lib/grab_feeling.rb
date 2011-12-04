#-*- coding: utf-8 -*-
$:.unshift File.dirname(__FILE__)

ENV["RACK_ENV"] ||= "development"

require 'rubygems'
require 'bundler'
Bundler.setup

require 'grab_feeling/db'
require 'grab_feeling/model'

require 'grab_feeling/communicator'
require 'grab_feeling/scheduler'
require 'grab_feeling/timeouter'

require 'haml'

require 'grab_feeling/app'
require 'grab_feeling/app_ws'

