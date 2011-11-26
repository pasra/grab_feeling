#-*- coding: utf-8 -*-
require_relative '../db.rb'

class Log < ActiveRecord::Base
  belongs_to :room
  belongs_to :player
end
