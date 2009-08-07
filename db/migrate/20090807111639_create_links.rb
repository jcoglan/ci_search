class CreateLinks < ActiveRecord::Migration
  def self.up
    create_table :links do |t|
      t.integer :from_id, :null => false
      t.integer :to_id, :null => false
    end
    add_index :links, :from_id
    add_index :links, :to_id
  end

  def self.down
    drop_table :links
  end
end
