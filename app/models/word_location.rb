class WordLocation < ActiveRecord::Base
  
  belongs_to :page
  belongs_to :word
  
end
