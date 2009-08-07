class Link < ActiveRecord::Base
  
  belongs_to :from_page, :class_name => 'Page', :foreign_key => 'from_id'
  belongs_to :to_page,   :class_name => 'Page', :foreign_key => 'to_id'
  
  has_many :link_words
  has_many :words, :through => :link_words
  
end
