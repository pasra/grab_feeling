#-*- coding: utf-8 -*-
require 'grab_feeling/db'

class TheMigration < ActiveRecord::Migration
  def self.up
    create_table :rooms do |t|
      t.string :name
      t.boolean :listed
      t.boolean :watchable
      t.boolean :ended, :default => false
      t.string :join_key
      t.string :watch_key
      t.string :drawer_id
      t.string :unique_id
      t.integer :round
      t.integer :max_round
    end

    create_table :logs do |t|
      t.string :text
      t.boolean :system
      t.integer :player_id
      t.integer :room_id
    end

    create_table :players do |t|
      t.integer :room_id
      t.boolean :admin
      t.string :name
      t.string :token
      t.integer :point, :default => 0
    end

    create_table :themes do |t|
      t.integer :dictionary_id
      t.string :text
    end

    create_table :dictionaries do |t|
      t.string :name
    end

    add_index :rooms, :unique_id
    add_index :logs, :room_id
    add_index :players, :room_id
    add_index :themes, :dictionary_id
  end

  def self.down
    drop_table :rooms
    drop_table :logs
    drop_table :statuses
    drop_table :players
  end
end
