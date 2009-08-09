class Word < ActiveRecord::Base
  
  has_many :locations, :class_name => 'WordLocation'
  has_many :pages, :through => :locations
  
  has_many :link_words
  has_many :links, :through => :link_words
  
  has_many :word_to_hidden_nodes
  has_many :hidden_nodes, :through => :word_to_hidden_nodes
  
end
