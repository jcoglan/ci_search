require 'config/environment'

namespace :crawler do
  task :run do
    pages = ['http://kiwitobes.com/wiki/Categorical_list_of_programming_languages.html']
    SearchEngine.crawl(pages)
  end
  
  task :pagerank do
    SearchEngine.calculate_page_rank
  end
end

