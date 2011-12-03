#-*- coding: utf-8 -*-
require_relative '../db.rb'

class Round < ActiveRecord::Base
  belongs_to :room
  belongs_to :theme
  belongs_to :drawer, :class_name => "Player", :foreign_key => "drawer_id"

  def ends_at
    self.started_at + GrabFeeling::Config["operation"]["turn"]
  end

  def end(pool, answerer = nil, next_right_now=false)
    point = (self.ends_at - Time.now).to_i

    pool.broadcast self.room_id, type: :round_end

    is_last = (self.ends_at == self.next_at)

    if answerer || next_right_now
      self.next_at = Time.now + (is_last ? 0 : GrabFeeling::Config["operation"]["interval"])
    end

    if answerer
      pool.broadcast self.room_id,  type: :correct, player_id: answerer.id,
                                    point: point, answer: theme.text

      [self.drawer, answerer].each do |player|
        player.point += point
        player.save!
        pool.broadcast self.room_id, type: :point, player_id: player.id, point: player.point
      end
      room.add_system_log :correct, name: answerer.name, point: point
    end

    self.topic = self.theme.text
    self.done = true
    self.save!

    pool.broadcast self.room_id, type: :topic, topic: self.topic

    if !is_last
      room.add_system_log :round_end,
                          next_game: self.next_at - Time.now,
                          next_drawer: ((self.drawer && self.drawer.next_player) || room.players.first).name,
                          answer: self.theme.text
    else
      room.add_system_log :last_round_end, answer: self.topic
    end
  end
end
