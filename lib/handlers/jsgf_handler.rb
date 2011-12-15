
require 'handlers/handler'

class PocketsphinxServer::JSGFHandler < PocketsphinxServer::Handler

  def initialize(server, config={})
    super
    @grammar_dir = config.fetch('grammar-dir', 'user_grammars')
  end
  
  def can_handle?(req)
    lm_name = req.params['lm']
    return (lm_name != nil) && (lm_name =~ /jsgf$/)
  end

  def prepare_rec(req)
    lm_name = req.params['lm']
    log("Using JSGF-based grammar")
    dict_file = dict_file_from_url(lm_name)
    fsg_file = fsg_file_from_url(lm_name)
    if not File.exists? fsg_file
      raise IOError, "Language model #{lm_name} not available. Use /fetch-lm API call to upload it to the server"
    end
    if not File.exists? dict_file
      raise IOError, "Pronunciation dictionary for #{lm_name} not available. Use /fetch-lm API call to make it on the server"
    end
    @recognizer.set_fsg(fsg_file, dict_file)      
    log("Loaded requested JSGF model from #{fsg_file}")
    
  end
  
  def can_handle_fetch_lm?(req)
    lm_name = req.params['url']
    if lm_name == nil
      # backward compability
      lm_name = req.params['lm']
    end
    return (lm_name != nil) && (lm_name =~ /jsgf$/)
  end
  
  def handle_fetch_lm(req)
    url = req.params['url']  
    if url == nil
      # backward compability
      url = req.params['lm']
    end
    log "Fetching JSGF grammar from #{url}"
    digest = MD5.hexdigest url
    content = open(url).read
    jsgf_file =  @grammar_dir + "/#{digest}.jsgf"
    fsg_file =  fsg_file_from_url(url)
    dict_file =  dict_file_from_url(url)
    File.open(jsgf_file, 'w') { |f|
        f.write(content)
    }
    log "Converting to FSG.."
    `#{@config['jsgf-to-fsg']} #{jsgf_file} #{fsg_file}`
    if $? != 0
        raise "Failed to convert JSGF to FSG" 
    end
    log "Making dictionary.."
    `cat #{fsg_file} | #{@config['fsg-to-dict']} > #{dict_file}`
    if $? != 0
        raise "Failed to make dictionary from FSG" 
    end
    "Request completed"
  end
  
  def fsg_file_from_url(url)
    digest = MD5.hexdigest url
    return @grammar_dir + "/#{digest}.fsg"
  end

  def dict_file_from_url(url)
    digest = MD5.hexdigest url
    return @grammar_dir + "/#{digest}.dict"
  end
  
  
  
end

