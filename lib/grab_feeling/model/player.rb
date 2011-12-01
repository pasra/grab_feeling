#-*- coding: utf-8 -*-
require_relative '../db.rb'

class Player < ActiveRecord::Base
  belongs_to :room, :foreign_key => "room_id"
  has_many :logs, :dependent => :nullify

  def next_player
    self.room.players.where('id > ? AND online = ?', self.id, true).first
  end
end
