class CreatePageRanks < ActiveRecord::Migration
  def self.up
    create_table :page_ranks do |t|
      t.belongs_to :page
      t.float :score, :null => false
    end
    add_index :page_ranks, :page_id
  end

  def self.down
    drop_table :page_ranks
  end
end
