#-*- coding: utf-8 -*-
require_relative '../db.rb'

class Status < ActiveRecord::Base
  belongs_to :room
end
