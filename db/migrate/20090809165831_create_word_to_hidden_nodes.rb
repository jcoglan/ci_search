class CreateWordToHiddenNodes < ActiveRecord::Migration
  def self.up
    create_table :word_to_hidden_nodes do |t|
      t.belongs_to :word
      t.belongs_to :hidden_node
      t.float :strength, :null => false
    end
    add_index :word_to_hidden_nodes, :word_id
    add_index :word_to_hidden_nodes, :hidden_node_id
  end

  def self.down
    drop_table :word_to_hidden_nodes
  end
end
