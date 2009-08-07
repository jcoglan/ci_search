class CreateWordLocations < ActiveRecord::Migration
  def self.up
    create_table :word_locations do |t|
      t.belongs_to :page
      t.belongs_to :word
      t.integer :location, :null => false
    end
    add_index :word_locations, :page_id
    add_index :word_locations, :word_id
  end

  def self.down
    drop_table :word_locations
  end
end
