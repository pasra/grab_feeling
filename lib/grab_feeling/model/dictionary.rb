#-*- coding: utf-8 -*-
require_relative '../db.rb'

class Dictionary < ActiveRecord::Base
  has_many :themes

  has_and_belongs_to_many :rooms
end
