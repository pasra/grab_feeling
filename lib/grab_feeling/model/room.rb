#-*- coding: utf-8 -*-
require_relative '../db.rb'

class Room < ActiveRecord::Base
  has_many :players
  has_many :statuses
  has_many :logs
  has_one :drawer, :class_name => "Player", :foreign_key => "drawer_id"

  validates_uniqueness_of :unique_id

  def session_key
    :"player_#{@room.id}"
  end
end
