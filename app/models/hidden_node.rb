class HiddenNode < ActiveRecord::Base
  
  has_many :word_to_hidden_nodes
  has_many :words, :through => :word_to_hidden_nodes
  
  has_many :hidden_node_to_pages
  has_many :pages, :through => :hidden_node_to_pages
  
end
