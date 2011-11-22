#-*- coding: utf-8 -*-
require_relative './lib/grab_feeling'
require 'rack'

GrabFeeling::SocketApp.run!
