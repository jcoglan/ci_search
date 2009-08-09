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
    depth.times.each do |i|
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
    link = Link.create(
      :from_page => Page.find_or_create_by_url(url_from),
      :to_page   => Page.find_or_create_by_url(url_to)
    )
    
    separate_words(link_text).each do |word|
      next if IGNORE_WORDS.include?(word)
      entry = Word.find_or_create_by_word(word)
      LinkWord.create(:word => entry, :link => link)
    end
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
    
    weights = [ [1.0,location_score(rows)],
                [1.0,frequency_score(rows)],
                [1.0,pagerank_score(rows)],
                [1.0,link_text_score(rows,word_ids)] ]
    
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
  
  def self.distance_score(rows)
    # If there's only one word, everyone wins!
    return rows.inject({}) { |table,row| table[row[0]] = 1.0; table } if rows[0].length <= 2
    
    # Initialize the dictionary with large values
    mindistance = rows.inject({}) { |table,row| table[row[0]] = 1_000_000; table }
    
    rows.each do |row|
      dist = (2...row.length).map { |i| (row[i] - row[i-1]).abs }.inject(0) { |a,b| a + b }
      mindistance[row[0]] = dist if dist < mindistance[row[0]]
    end
    normalize_scores(mindistance, true)
  end
  
  def self.inbound_link_score(rows)
    unique_urls = Set.new(rows.map { |row| row[0] })
    inbound_count = unique_urls.inject({}) do |table, u|
      table[u] = Page.find(u).inbound_links.count
      table
    end
    normalize_scores(inbound_count, true)
  end
  
  def self.pagerank_score(rows)
    pageranks = rows.inject({}) do |table,row|
      table[row[0]] = Page.find(row[0], :include => :page_rank).page_rank.score
      table
    end
    maxrank = pageranks.values.max
    normalized_scores = pageranks.inject({}) do |table,(u,l)|
      table[u] = 1.0 / maxrank
      table
    end
    normalized_scores
  end
  
  def self.link_text_score(rows, word_ids)
    link_scores = rows.inject({}) { |table,row| table[row[0]] = 0; table }
    word_ids.each do |word_id|
      Word.find(word_id).links.each do |link|
        next unless link_scores.has_key?(link.to_id)
        pr = link.from_page.page_rank.score
        link_scores[link.to_id] += pr
      end
    end
    maxscore = link_scores.values.max
    normalized_scores = link_scores.inject({}) do |table,(u,l)|
      table[u] = 1.0 / maxscore
      table
    end
    normalized_scores
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
  
  def self.calculate_page_rank(iterations = 20)
    # Clear out the current table
    PageRank.delete_all
    
    # Initialize every URL with a PageRank of 1
    db.execute("insert into #{PageRank.table_name} (page_id, score) select id, 1.0 from #{Page.table_name}")
    
    iterations.times do |i|
      puts "Iteration #{i}"
      Page.find(:all).each do |page|
        pr = 0.15
        
        # Loop through all the pages that link to this one
        page.inbound_links.each do |link|
          linking_pr = link.from_page.page_rank.score
          # Get the total number of links from the linker
          linking_count = link.from_page.outbound_links.count
          
          pr += 0.85 * (linking_pr / linking_count)
        end
        
        page.page_rank.update_attributes(:score => pr)
      end
    end
  end
  
end

