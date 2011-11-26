#-*- coding: utf-8 -*-
require_relative './lib/grab_feeling'
require_relative './lib/grab_feeling/websocket_starter'
require 'rack'

GrabFeeling::SocketApp.run! port: ARGV[0] || 4568
