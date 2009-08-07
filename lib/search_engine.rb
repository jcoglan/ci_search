require 'uri'
require 'net/http'
require 'set'
require 'hpricot'

module SearchEngine
  IGNORE_WORDS = %w[the of to and a in is it]
  
  def self.crawl(pages, depth = 2)
    (0...depth).each do |i|
      newpages = Set.new
      pages.each do |page|
        response = Net::HTTP.get_response(URI.parse(page))
        unless response.code == '200'
          puts "Could not open #{ page }"
          next
        end
        doc = Hpricot.parse(response.body)
        add_to_index(page, doc)
        
        (doc / 'a').each do |link|
          next unless link.attributes.has_key?('href')
          url = URI.join(page, link['href']).to_s
          next if url =~ /'/
          url = url.split('#').first
          newpages.add(url) if url[0...4] == 'http' and not is_indexed?(url)
          link_text = get_text_only(link)
          add_link_ref(page, url, link_text)
        end
      end
      pages = newpages
    end
  end
  
  def self.add_to_index(url, doc)
    return if is_indexed?(url)
    puts "Indexing #{url}"
    
    # Get the individual words
    text = get_text_only(doc)
    words = separate_words(text)
    
    # Get the page object
    page = Page.find_or_create_by_url(url)
    
    # Link each word to this page
    words.each_with_index do |word,i|
      next if IGNORE_WORDS.include?(word)
      entry = Word.find_or_create_by_word(word)
      WordLocation.create(:page => page, :word => entry, :location => i)
    end
  end
  
  def self.get_text_only(element)
    element = element.to_s if Hpricot::Text === element
    return element.strip if String === element
    return '' unless element.respond_to?(:children)
    (element.children || []).inject('') do |str, child|
      str + get_text_only(child) + "\n"
    end
  end
  
  def self.separate_words(text)
    text.split(/\W+/).delete_if { |s| s == '' }.map { |s| s.downcase }
  end
  
  def self.is_indexed?(url)
    page = Page.find_by_url(url)
    return false if page.nil?
    # Check if it has actually been crawled
    page.word_locations.size > 0
  end
  
  def self.add_link_ref(url_from, url_to, link_text)
  #  puts "#{url_from} -> #{url_to}"
  end
  
  def self.get_match_rows(q)
    # Strings to build the query
    field_list = ['w0.page_id']
    table_list = []
    clause_list = []
    
    # Split the words by spaces
    words = q.split(/\s+/)
    
    # More efficient than book version: get
    # all the word IDs with one query
    entries = Word.find(:all, :conditions => ["word in (#{ words.map{'?'} * ',' })"] + words)
    ids = entries.map(&:id).each_with_index
    range = 0...(entries.size)
    
    query = <<-EOQ
      SELECT w0.page_id, #{ range.map { |i| "w#{i}.location" } * ', ' }
      FROM   #{ range.map { |i| "#{WordLocation.table_name} w#{i}" } * ', ' }
      WHERE  #{ ( range.each_cons(2).map { |a,b| "w#{a}.page_id = w#{b}.page_id" } +
                  ids.map { |id,i| "w#{i}.word_id = #{id}" } ) *
                "\n      AND    " }
    EOQ
    
    db.execute(query).map do |result|
      [result[0].to_i] + range.map { |i| result[i+1].to_i }
    end
  end
  
  def self.db
    ActiveRecord::Base.connection
  end
  
end

