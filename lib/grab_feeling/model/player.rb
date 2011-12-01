#-*- coding: utf-8 -*-
require_relative '../db.rb'

class Player < ActiveRecord::Base
  belongs_to :room, :foreign_key => "room_id"
  has_many :logs, :dependent => :nullify

  def next_player
    self.room.players.where('id > ? AND online = ?', self.id, true).first
  end

  def leave
    GrabFeeling::Communicator.notify :leave, room_id: self.room.id, player_id: self.id,
                                             player_name: self.name
    self.room.add_system_log :player_left, name: self.name

    self.destroy

    if self.room.players.where(admin: true).empty?
      self.room.ended = true
      self.room.save!

      self.room.add_system_log :room_end
      Communicator.notify :room_end, room_id: self.room.id
    end
  end
end
