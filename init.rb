#-*- coding: utf-8 -*-

ENV["RACK_ENV"] ||= "development"

$:.unshift File.join(File.dirname(__FILE__), 'lib')

require 'rubygems'
require 'bundler'
Bundler.setup
