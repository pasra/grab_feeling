#-*- coding: utf-8 -*-

module GrabFeeling
  class SocketPool
    def initialize
      @pool = {}
      @pool_player= {}
      @sockets = {}
    end

    def find(socket)
      @sockets[socket.__id__]
    end

    def find_by_room_id(room_id)
      @pool[room_id] || []
    end

    def find_by_player_id(player_id)
      @pool_player[player_id]
    end

    def broadcast(room_id, msg={})
      broadcast_ find_by_room_id(room_id), msg
    end

    def broadcast_to_all(msg={})
      broadcast_ @pool_player.values, msg
    end

    def add(room_id, player_id, socket)
      player = Player.find_by_id(player_id)
      obj = {socket: socket, room_id: room_id, player_id: player_id, loaded: false}
      obj[:name] = player ? player.name : "???"
      @pool[room_id] ||= {}
      @pool[room_id][player_id] = obj
      @pool_player[player_id] = obj
      @sockets[socket.__id__] = obj
      self
    end

    def remove(socket)
      remove_ find(socket)
    end

    def remove_by_player_id(player_id)
      remove_ find_by_player_id(player_id)
    end

    private

    def broadcast_(ary, msg={})
      message = msg.to_json
      ary.each do |pid,player|
        player[:socket].send message
      end
    end

    def remove_(obj)
      return nil unless obj
      @sockets.delete(obj[:socket].__id__)
      @pool[obj[:room_id]].delete(obj[:player_id])
      @pool_player.delete(obj[:player_id])
      self
    end
  end
end
