class WordToHiddenNode < ActiveRecord::Base
  
  belongs_to :word
  belongs_to :hidden_node
  
end
