class Word < ActiveRecord::Base
  
  has_many :locations, :class_name => 'WordLocation'
  has_many :pages, :through => :locations
  
  has_many :link_words
  has_many :links, :through => :link_words
  
end
