class NeuralNet
  
  def self.dtanh(y)
    1.0 - y*y
  end
  
  def self.get_link(from_id, to_id, layer)
    res = (layer == 0) ?
          WordToHiddenNode.find_by_word_id_and_hidden_node_id(from_id, to_id) :
          HiddenNodeToPage.find_by_hidden_node_id_and_page_id(from_id, to_id)
  end
  
  def self.get_strength(from_id, to_id, layer)
    res = get_link(from_id, to_id, layer)
    if res.nil?
      return (layer == 0) ? -0.2 : 0.0
    end
    res.strength
  end
  
  def self.set_strength(from_id, to_id, layer, strength)
    res = get_link(from_id, to_id, layer)
    if res.nil?
      if layer == 0
        WordToHiddenNode.create(:word_id        => from_id,
                                :hidden_node_id => to_id,
                                :strength       => strength)
      else
        HiddenNodeToPage.create(:hidden_node_id => from_id,
                                :page_id        => to_id,
                                :strength       => strength)
      end
    else
      res.update_attributes(:strength => strength)
    end
  end
  
  def self.generate_hidden_node(word_ids, urls)
    return nil if word_ids.size > 3
    # Check if we already created a node for this set of words
    create_key = word_ids * '_'
    res = HiddenNode.find_by_create_key(create_key)
    
    # If not, create it
    if res.nil?
      hidden_id = HiddenNode.create(:create_key => create_key).id
      # Put in some default weights
      word_ids.each do |word_id|
        set_strength(word_id, hidden_id, 0, 1.0/word_ids.size)
      end
      urls.each do |url_id|
        set_strength(hidden_id, url_id, 1, 0.1)
      end
    end
  end
  
  def self.get_all_hidden_ids(word_ids, url_ids)
    l1 = {}
    word_ids.each do |word_id|
      WordToHiddenNode.find(:all, :conditions => ['word_id = ?', word_id]).each do |res|
        l1[res.hidden_node_id] = 1
      end
    end
    url_ids.each do |url_id|
      HiddenNodeToPage.find(:all, :conditions => ['page_id = ?', url_id]).each do |res|
        l1[res.hidden_node_id] = 1
      end
    end
    l1.keys
  end
  
  def setup_network(word_ids, url_ids)
    # value lists
    @word_ids   = word_ids
    @hidden_ids = self.class.get_all_hidden_ids(word_ids, url_ids)
    @url_ids    = url_ids
    
    # node outputs
    @ai = [1.0] * @word_ids.size
    @ah = [1.0] * @hidden_ids.size
    @ao = [1.0] * @url_ids.size
    
    # create weights matrix
    @wi = @word_ids.map do |word_id|
      @hidden_ids.map do |hidden_id|
        self.class.get_strength(word_id, hidden_id, 0)
      end
    end
    @wo = @hidden_ids.map do |hidden_id|
      @url_ids.map do |url_id|
        self.class.get_strength(hidden_id, url_id, 1)
      end
    end
  end
  
  def feed_forward
    # the only inputs are the query words
    @word_ids.size.times { |i| @ai[i] = 1.0 }
    
    # hidden activations
    @hidden_ids.size.times do |j|
      sum = 0.0
      @word_ids.size.times do |i|
        sum += @ai[i] * @wi[i][j]
      end
      @ah[j] = Math.tanh(sum)
    end
    
    # output activations
    @url_ids.size.times do |k|
      sum = 0.0
      @hidden_ids.size.times do |j|
        sum += @ah[j] * @wo[j][k]
      end
      @ao[k] = Math.tanh(sum)
    end
    
    @ao.dup
  end
  
  def get_result(word_ids, url_ids)
    setup_network(word_ids, url_ids)
    feed_forward
  end
  
  def back_propagate(targets, n = 0.5)
    # calculate errors for output
    output_deltas = [0.0] * @url_ids.size
    @url_ids.size.times do |k|
      error = targets[k] - @ao[k]
      output_deltas[k] = self.class.dtanh(@ao[k]) * error
    end
    
    # calculate errors for hidden layer
    hidden_deltas = [0.0] * @hidden_ids.size
    @hidden_ids.size.times do |j|
      error = 0.0
      @url_ids.size.times do |k|
        error += output_deltas[k] * @wo[j][k]
      end
      hidden_deltas[j] = self.class.dtanh(@ah[j]) * error
    end
    
    # update output weights
    @hidden_ids.size.times do |j|
      @url_ids.size.times do |k|
        change = output_deltas[k] * @ah[j]
        @wo[j][k] = @wo[j][k] + n * change
      end
    end
    
    # update input weights
    @word_ids.size.times do |i|
      @hidden_ids.size.times do |j|
        change = hidden_deltas[j] * @ai[i]
        @wi[i][j] = @wi[i][j] + n * change
      end
    end
  end
  
  def train_query(word_ids, url_ids, selected_url)
    # generate a hidden node if necessary
    self.class.generate_hidden_node(word_ids, url_ids)
    
    setup_network(word_ids, url_ids)
    feed_forward
    targets = [0.0] * url_ids.size
    targets[url_ids.index(selected_url)] = 1.0
    error = back_propagate(targets)
    update_database
  end
  
  def update_database
    # set them to database values
    @word_ids.size.times do |i|
      @hidden_ids.size.times do |j|
        self.class.set_strength(@word_ids[i], @hidden_ids[j], 0, @wi[i][j])
      end
    end
    @hidden_ids.size.times do |j|
      @url_ids.size.times do |k|
        self.class.set_strength(@hidden_ids[j], @url_ids[k], 1, @wo[j][k])
      end
    end
  end
  
end

