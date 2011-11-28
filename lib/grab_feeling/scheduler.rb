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
          room.save!
        end
      end

      @rooms[room.id] = room
    end

    def tick
      ActiveRecord::Base.connection_pool.with_connection do
        @rooms.each do |id,room|
          round = room.rounds.last || room.next_round(true)

          # Round - timeout
          if round.next_at < Time.now
            room.next_round
          end

          # next open
          elapsed = Time.now - round.started_at
          time, percent = Config["theme_opening"]["timings"].find{ |(t, percent)|
                            elapsed > t }
          if round.opened < time
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
          end
        end
      end
    end

  end
end
