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
    puts "Indexing #{url}"
  end
  
  def self.get_text_only(link)
    nil
  end
  
  def self.is_indexed?(url)
    false
  end
  
  def self.add_link_ref(url_from, url_to, link_text)
  #  puts "#{url_from} -> #{url_to}"
  end
  
end

