#-*- coding: utf-8 -*-
require 'eventmachine'

module GrabFeeling
  class Timeouter
    @@players = {}
    @@rooms = {}

    def self.for_room(i)
      @@room[i] || {}
    end

    def self.for_player(i)
      @@players[i]
    end

    def initialize(room, player, timeout=Config["operation"]["timeout_to_kick"])
      @room_id = room
      @player_id = player

      @@players[player] = self
      (@@rooms[room] ||= {})[player] = self

      @timer = EM::Timer.new(timeout, &(self.method(:fire)))
    end

    def fire
      if player = Player.find_by_id(@player_id)
        player.leave
      end

      remove
    end

    def remove
      @@players.delete @player_id
      @@rooms[@room_id].delete @player_id
    end

    def cancel
      @timer.cancel if @timer
      self.remove
      true
    end
  end
end

