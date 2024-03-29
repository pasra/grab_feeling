#-*- coding: utf-8 -*-
require 'grab_feeling/db'

class TheMigration < ActiveRecord::Migration
  def self.up
    create_table :rooms, :force => true do |t|
      t.string :name
      t.string :unique_id

      t.boolean :listed, :default => true
      t.boolean :watchable, :default => true

      t.boolean :ended, :default => false
      t.boolean :in_game, :default => false

      t.string :join_key
      t.string :watch_key

      t.string :ws_server # for future use...

      t.integer :round, :default => 1
      t.integer :max_round, :default => 3
    end

    create_table :rounds, :force => true do |t|
      t.string :topic

      t.datetime :started_at
      t.datetime :next_at

      t.integer :opened, :default => 0
      t.boolean :done, :default => false

      t.integer :theme_id
      t.integer :room_id
      t.integer :drawer_id
    end

    create_table :logs, :force => true do |t|
      t.string :text
      t.string :name

      t.integer :player_id
      t.integer :room_id
    end

    create_table :statuses, :force => true do |t|
      t.string :en
      t.string :ja
      t.integer :room_id
    end

    create_table :players, :force => true do |t|
      t.string :name
      t.string :token

      t.boolean :admin, :default => false
      t.boolean :viewer, :default => false
      t.boolean :online, :default => false

      t.datetime :last_available

      t.integer :point, :default => 0

      t.integer :room_id
    end

    create_table :themes, :force => true do |t|
      t.integer :dictionary_id
      t.string :text
    end

    create_table :dictionaries, :force => true do |t|
      t.string :name
      t.boolean :official, :default => false
    end

    create_table :dictionaries_rooms, :id => false, :force => true do |t|
      t.integer :room_id
      t.integer :dictionary_id
    end

    add_index :rooms, :unique_id
    add_index :logs, :room_id
    add_index :players, :room_id
    add_index :themes, :dictionary_id
    add_index :rounds, :room_id
  end

  def self.down
    drop_table :rooms
    drop_table :logs
    drop_table :statuses
    drop_table :players
    drop_table :themes
    drop_table :dictionaries
  end
end
