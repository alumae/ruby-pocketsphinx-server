
require 'handlers/handler'

class PocketsphinxServer::PGFHandler < PocketsphinxServer::Handler

  def initialize(server, config={})
    super
    @grammar_dir = config.fetch('grammar-dir', 'user_gfs')
  end

  def can_handle?(req)
    lm_name = req.params['lm']
    return (lm_name != nil) && (lm_name =~ /pgf$/)
  end

  def get_req_properties(req)
    input_lang = req.params['input-lang']
    if input_lang == nil
        input_lang = @config.fetch('gf', {}).fetch('default_input_lang', 'Est')
    end
    output_langs = req.params['output-lang']
    lm_name = req.params['lm']
    digest = MD5.hexdigest lm_name
    pgf_dir = @grammar_dir + '/' + digest
    pgf_basename = File.basename(URI.parse(lm_name).path, ".pgf")
    return input_lang, output_langs, pgf_dir, pgf_basename
  end
  
  def prepare_rec(req)
    puts "Using GF-based grammar"
    input_lang, output_langs, pgf_dir, pgf_basename = get_req_properties(req)
    fsg_file = pgf_dir + '/' + pgf_basename + input_lang + ".fsg"
    dict_file = pgf_dir + '/' + pgf_basename + input_lang + ".dict"
    if not File.exists? fsg_file
      raise IOError, "Grammar for lang #{input_lang} for #{lm_name} not available. Use /fetch-lm API call to upload it to the server"
    end
    if not File.exists? dict_file
        raise IOError, "Pronunciation dictionary for lang #{input_lang} for #{lm_name} not available. Use /fetch-lm API call to make it on the server"
    end
    @recognizer.set_fsg(fsg_file, dict_file)      
  end

  def get_hyp_extras(req, hyp)
    input_lang, output_langs, pgf_dir, pgf_basename = get_req_properties(req)
    linearizations = []
    if not output_langs.nil?
      output_langs.split(",").each do |output_lang|
        log "Linearizing [#{hyp}] to lang #{output_lang}"
        outputs = `echo "parse -lang=#{pgf_basename + input_lang} \\"#{hyp}\\" | linearize -lang=#{pgf_basename + output_lang} | ps -bind" | gf --run #{pgf_dir + '/' + pgf_basename + '.pgf'}`
        output_lines = outputs.split("\n")
        if output_lines == []
          output_lines = [""]
        end
        output_lines.each do |output|
          log "LINEARIZED RESULT: " + output
          linearizations.push({:output => output, :lang => output_lang})
        end
      end
    end
    return {:linearizations => linearizations}    
  end

  def can_handle_fetch_lm?(req)
    lm_name = req.params['url']
    return (lm_name != nil) && (lm_name =~ /pgf$/)
  end

  def handle_fetch_lm(req)
    url = req.params['url']  
    input_langs = req.params['lang']
    if input_langs == nil
       input_langs = @config.fetch('gf', {}).fetch('default_input_lang', 'Est')
    end
    log "Fetching PGF from #{url}"
    digest = MD5.hexdigest url
    content = open(url).read
    pgf_dir = @grammar_dir + '/' + digest
    FileUtils.mkdir_p pgf_dir
    pgf_basename = File.basename(URI.parse(url).path, ".pgf")
    File.open(pgf_dir + '/' + pgf_basename + ".pgf", 'w') { |f|
        f.write(content)
    }
    log 'Extracting concrete grammars'
    `gf -make --output-format=jsgf --output-dir=#{pgf_dir} #{pgf_dir + '/' + pgf_basename + ".pgf"}` 
    if $? != 0
        raise "Failed to extract JSGF from PGF" 
    end

     input_langs.split(',').each do |lang|
      jsgf_file = pgf_dir + '/' + pgf_basename + lang + ".jsgf"
      fsg_file = pgf_dir + '/' + pgf_basename + lang + ".fsg"
      dict_file = pgf_dir + '/' + pgf_basename + lang + ".dict"
      log "Making finite state grammar for input language #{lang}"
      log "Converting JSGF.."
      `#{@config.fetch('convert-gf-jsgf')} #{jsgf_file}`
        if $? != 0
          raise "Failed to convert JSGF for lang #{lang}" 
        end
        log "Converting to FSG.."
        `#{@config.fetch('jsgf-to-fsg')} #{jsgf_file} #{fsg_file}`
        if $? != 0
          raise "Failed to convert JSGF to FSG for lang #{lang}" 
        end
        log "Making dictionary.."
        `cat #{fsg_file} | #{@config.fetch('fsg-to-dict')} > #{dict_file}`
        if $? != 0
          raise "Failed to make dictionary from FSG for lang #{lang}" 
        end
       
    end

    "Request completed"
  end
  
end

