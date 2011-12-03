#-*- coding: utf-8 -*-
require 'eventmachine'

module GrabFeeling
  class Scheduler
    def initialize(pool,development=false)
      @rooms = {}
      @pool = pool
      @timer = EM::PeriodicTimer.new(1, &(development ? self.method(:tick) : ->{tick()}))
    end

    def cancel
      @timer.cancel
    end

    def resume
      Room.where(:in_game => true).each do |room|
        @rooms[room.id] = room
      end
      self
    end

    def add_game(room)
      return nil if @rooms[room.id]

      ActiveRecord::Base.connection_pool.with_connection do
        ActiveRecord::Base.transaction do
          room.in_game = true
          room.round = 1
          room.save!
          room.players.each do |player|
            player.point = 0
            player.save!
            @pool.broadcast room.id, type: :point, player_id: player.id, point: 0
          end
        end
      end

      @rooms[room.id] = [room, false]
    end

    def next(room_id)
      @rooms[room_id][1] = true
    end

    def end_game(room_id)
      if room_ary = @rooms.delete(room_id)
        room = room_ary[0]
        @pool.broadcast room.id, type: :game_end
        @pool.broadcast room.id, type: :topic, topic: ""
        room.in_game = false
        room.round = 1
        room.save!
        room.rounds.delete_all
        room.add_system_log :game_end
        self
      end
    end

    def tick
      ActiveRecord::Base.connection_pool.with_connection do
        @rooms.each do |id,(room, flag)|
          round = room.rounds.last || room.next_round(@pool,true)

          if flag || round.next_at < Time.now
            @rooms[id][1] = false

            # Round - next
            unless (round = room.next_round(@pool))
              # Game end
              # TODO: ranking

              end_game(id)
            end
          elsif round.ends_at < Time.now
            # Round - end
            round.end @pool
          else
            # next open
            elapsed = Time.now - round.started_at
            time, percent = Config["theme_opening"]["timings"].find{ |(t, percent)|
                              elapsed > t } || [nil, nil]

            next unless time
            next unless round.opened < time

            #round.reload

            opened = round.topic.dup
            theme_str = round.theme.text
            text_len = theme_str.size

            _ = opened.chars.each_with_index.map{|c,i|
                  c == Config["theme_opening"]["hider"] ? i : nil }

            open_size = (percent * text_len).round - _.select(&:nil?).size
            next if open_size < 0
            _.reject(&:nil?).sample(open_size).each {|i| opened[i] = theme_str[i] }

            ActiveRecord::Base.transaction do
              round.update_attributes!(topic: opened, opened: time)
            end

            socket_wo_drawer = @pool.find_by_room_id(room.id).reject do |k,pl|
              pl[:player_id] == round.drawer_id
            end
            @pool.broadcast_to socket_wo_drawer, type: :topic, topic: opened
          end
        end
      end
    end
  end
end
