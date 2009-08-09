class HiddenNodeToPage < ActiveRecord::Base
  
  belongs_to :hidden_node
  belongs_to :page
  
end
