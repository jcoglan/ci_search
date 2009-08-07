class LinkWord < ActiveRecord::Base
  
  belongs_to :word
  belongs_to :link
  
end
