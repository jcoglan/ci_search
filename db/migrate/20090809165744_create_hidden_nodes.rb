class CreateHiddenNodes < ActiveRecord::Migration
  def self.up
    create_table :hidden_nodes do |t|
      t.string :create_key, :limit => 255, :null => false
    end
  end

  def self.down
    drop_table :hidden_nodes
  end
end
