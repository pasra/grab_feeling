#-*- coding: utf-8 -*-
require_relative '../db.rb'

class Player < ActiveRecord::Base
  belongs_to :room, :foreign_key => "room_id"
end
