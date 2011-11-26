#-*- coding: utf-8 -*-
require_relative './lib/grab_feeling'

GrabFeeling::App.run! port: ARGV[0] || 4567
