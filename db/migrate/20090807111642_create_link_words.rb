class CreateLinkWords < ActiveRecord::Migration
  def self.up
    create_table :link_words do |t|
      t.belongs_to :word
      t.belongs_to :link
    end
    add_index :link_words, :word_id
    add_index :link_words, :link_id
  end

  def self.down
    drop_table :link_words
  end
end
