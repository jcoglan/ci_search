class CreateWords < ActiveRecord::Migration
  def self.up
    create_table :words do |t|
      t.string :word, :limit => 100, :null => false
    end
    add_index :words, :word
  end

  def self.down
    drop_table :words
  end
end
