class CreatePages < ActiveRecord::Migration
  def self.up
    create_table :pages do |t|
      t.string :url, :limit => 255, :null => false
    end
    add_index :pages, :url
  end

  def self.down
    drop_table :pages
  end
end
