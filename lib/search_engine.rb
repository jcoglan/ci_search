require 'uri'
require 'net/http'
require 'set'
require 'hpricot'

module SearchEngine
  IGNORE_WORDS = %w[the of to and a in is it]
  
  def self.db
    ActiveRecord::Base.connection
  end
  
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
    word_ids = entries.map(&:id)
    range = 0...(entries.size)
    
    query = <<-EOQ
      SELECT w0.page_id, #{ range.map { |i| "w#{i}.location" } * ', ' }
      FROM   #{ range.map { |i| "#{WordLocation.table_name} w#{i}" } * ', ' }
      WHERE  #{ ( range.each_cons(2).map { |a,b| "w#{a}.page_id = w#{b}.page_id" } +
                  word_ids.each_with_index.map { |id,i| "w#{i}.word_id = #{id}" } ) *
                "\n      AND    " }
    EOQ
    
    rows = db.execute(query).map do |result|
      [result[0].to_i] + range.map { |i| result[i+1].to_i }
    end
    [rows, word_ids]
  end
  
  def self.get_scored_list(rows, word_ids)
    total_scores = rows.inject({}) do |table, row|
      table[row[0]] = 0
      table
    end
    
    weights = [ [1.0,frequency_score(rows)],
                [1.5,location_score(rows)] ]
    
    weights.each do |(weight, scores)|
      total_scores.each_key do |url|
        total_scores[url] += weight * scores[url]
      end
    end
    
    total_scores
  end
  
  def self.frequency_score(rows)
    counts = rows.inject({}) { |table,row| table[row[0]] = 0; table }
    rows.each { |row| counts[row[0]] += 1 }
    normalize_scores(counts)
  end
  
  def self.location_score(rows)
    locations = rows.inject({}) { |table,row| table[row[0]] = 1_000_000; table }
    rows.each do |row|
      loc = row[1..-1].inject(0) { |a,b| a + b }
      locations[row[0]] = loc if loc < locations[row[0]]
    end
    normalize_scores(locations, true)
  end
  
  def self.get_url_name(id)
    Page.find(id).url
  end
  
  def self.query(q)
    rows, word_ids = *get_match_rows(q)
    scores = get_scored_list(rows, word_ids)
    ranked_scores = scores.map { |id,score| [score,id] }.sort_by { |r| r[0] }.reverse
    ranked_scores[0...10].each do |(score,id)|
      puts "%f\t%s" % [score, get_url_name(id)]
    end
  end
  
  def self.normalize_scores(scores, small_is_better = false)
    vsmall = 0.00001 # Avoid division by zero
    if small_is_better
      minscore = scores.values.min
      scores.inject({}) do |table,(u,l)|
        table[u] = minscore.to_f / [vsmall,l].max
        table
      end
    else
      maxscore = scores.values.max
      maxscore = vsmall if maxscore.zero?
      scores.inject({}) do |table,(u,c)|
        table[u] = c.to_f / maxscore
        table
      end
    end
  end
  
end

