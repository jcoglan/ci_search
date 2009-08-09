class CreateHiddenNodeToPages < ActiveRecord::Migration
  def self.up
    create_table :hidden_node_to_pages do |t|
      t.belongs_to :hidden_node
      t.belongs_to :page
      t.float :strength, :null => false
    end
    add_index :hidden_node_to_pages, :hidden_node_id
    add_index :hidden_node_to_pages, :page_id
  end

  def self.down
    drop_table :hidden_node_to_pages
  end
end
