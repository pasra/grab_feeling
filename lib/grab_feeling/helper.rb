#-*- coding: utf-8 -*-
require 'i18n'

module GrabFeeling
  module Helper
    def t(*args)
      I18n.t *args
    end

    def create_player(room, name)
      player = {name: params[:player][:name],
                token: Digest::SHA1.hexdigest(3.times.map{rand(100000000000)}.join)}
      @player = @room.players.build(player)

      if (_=@player.save)
        if room.players[0].id == @player.id
          @player.admin = true
          @player.save!
        end
        session[@room.session_key] = @player.id
        Communicator.notify :join, room_id: room.id, player_id: @player.id,
                                   player_name: @player.name
        room.add_system_log :player_joined, name: @player.name
        true
      else
        false
      end
    end
  end
end
