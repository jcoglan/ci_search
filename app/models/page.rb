class Page < ActiveRecord::Base
  
  has_many :outbound_links, :class_name => 'Link', :foreign_key => 'from_id'
  has_many :inbound_links,  :class_name => 'Link', :foreign_key => 'to_id'
  
  has_many :word_locations
  has_many :words, :through => :word_locations
  
  has_one :page_rank
  
end
