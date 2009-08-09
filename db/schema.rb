# This file is auto-generated from the current state of the database. Instead of editing this file, 
# please use the migrations feature of Active Record to incrementally modify your database, and
# then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your database schema. If you need
# to create the application database on another system, you should be using db:schema:load, not running
# all the migrations from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended to check this file into your version control system.

ActiveRecord::Schema.define(:version => 20090809145038) do

  create_table "link_words", :force => true do |t|
    t.integer "word_id"
    t.integer "link_id"
  end

  add_index "link_words", ["link_id"], :name => "index_link_words_on_link_id"
  add_index "link_words", ["word_id"], :name => "index_link_words_on_word_id"

  create_table "links", :force => true do |t|
    t.integer "from_id", :null => false
    t.integer "to_id",   :null => false
  end

  add_index "links", ["from_id"], :name => "index_links_on_from_id"
  add_index "links", ["to_id"], :name => "index_links_on_to_id"

  create_table "page_ranks", :force => true do |t|
    t.integer "page_id"
    t.float   "score",   :null => false
  end

  add_index "page_ranks", ["page_id"], :name => "index_page_ranks_on_page_id"

  create_table "pages", :force => true do |t|
    t.string "url", :null => false
  end

  add_index "pages", ["url"], :name => "index_pages_on_url"

  create_table "word_locations", :force => true do |t|
    t.integer "page_id"
    t.integer "word_id"
    t.integer "location", :null => false
  end

  add_index "word_locations", ["page_id"], :name => "index_word_locations_on_page_id"
  add_index "word_locations", ["word_id"], :name => "index_word_locations_on_word_id"

  create_table "words", :force => true do |t|
    t.string "word", :limit => 100, :null => false
  end

  add_index "words", ["word"], :name => "index_words_on_word"

end
