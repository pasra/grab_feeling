#-*- coding: utf-8 -*-
require 'eventmachine'

module GrabFeeling
  class Scheduler
    def initialize(pool)
      @rooms = {}
      @pool = pool
      @timer = EM::PeriodicTimer.new(1, &(self.method(:tick)))
    end

    def resume
      Room.where(:in_game => true).each do |room|
        @rooms[room.id] = room
      end
    end

    def add_game(room)
      ActiveRecord::Base.connection_pool.with_connection do
        ActiveRecord::Base.transaction do
          room.in_game = true
          room.round = 1
          room.save!
        end
      end

      @rooms[room.id] = room
    end

    def tick
      ActiveRecord::Base.connection_pool.with_connection do
        @rooms.each do |id,room|
          round = room.rounds.last || room.next_round(true)

          if round.next_at < Time.now
            # Round - next
            if (round = room.next_round)
              @pool.broadcast room.id, type: :topic, topic: round.topic.text
              @pool.broadcast room.id, type: :round,
                                       started_at: round.started_at,
                                       next_at: round.next_at,
                                       drawer: round.drawer.id
            else
              # Game end
              @rooms.delete(id)
              @pool.broadcast room.id, type: :game_end
              room.add_system_log :game_end
            end
          elsif round.ends_at < Time.now
            # Round - end
            @pool.broadcast room.id, type: :round_end
            unless round.ends_at == round.next_at
              room.add_system_log :round_end,
                                  next_game: Time.now - round.next_at,
                                  next_drawer: round.drawer.next_drawer.name
            end
          else
            # next open
            elapsed = Time.now - round.started_at
            time, percent = Config["theme_opening"]["timings"].find{ |(t, percent)|
                              elapsed > t }

            next unless round.opened < time

            opened = round.topic
            theme_str = round.theme.text
            text_len = theme_str.size

            _ = opened.chars.each_with_index.map{|c,i|
                  c == Config["theme_opening"]["hider"] ? i : nil }

            open_size = (percent * text_len).round - _.select(&:nil?).size
            _.reject(&:nil?).sample(open_size).each {|i| opened[i] = theme_str[i] }

            ActiveRecord::Base.transaction do
              round.topic = opened
              round.opened = time
              round.save!
            end
            @pool.broadcast room.id, type: :topic, topic: opened
          end
        end
      end
    end
  end
end
