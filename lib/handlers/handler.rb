


class PocketsphinxServer::Handler

  attr_reader :recognizer, :config

  def initialize(server, config={})
    @config = config
    @server = server
    @recognizer = PocketsphinxServer::Recognizer.new(server, config.fetch('recognizer', {}))
  end
  
  # Can this handler handle this request?
  def can_handle?(req)
    true
  end
  
  # Prepare the recognizer for this request (switch LM, etc)
  def prepare_rec(req)
  
  end
  
  # Postprocess an hypothesis string (e.g., make it prettyier)
  def postprocess_hypothesis(hyp)
    hyp
  end

  # Return a map of extra data for a hypothesis
  def get_hyp_extras(req, hyp)
    {}
  end

  def can_handle_fetch_lm?(req)
    false
  end
  
  def handle_fetch_lm(req)
  
  end

  def log(str)
    @server.logger.info str
  end
end
