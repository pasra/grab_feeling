#-*- coding: utf-8 -*-
require_relative '../db.rb'

class Status < ActiveRecord::Base
  has_one :theme
end
