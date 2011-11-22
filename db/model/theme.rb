#-*- coding: utf-8 -*-
require_relative '../db.rb'

class Theme < ActiveRecord::Base
  belongs_to :dictionary
end
