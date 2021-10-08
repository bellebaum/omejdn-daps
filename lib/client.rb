# frozen_string_literal: true

# OAuth client helper class
class Client
  attr_accessor :client_id, :redirect_uri, :name,
                :allowed_scopes, :attributes

  def self.find_by_id(client_id)
    load_clients.each do |client|
      return client if client_id == client.client_id
    end
    nil
  end

  def self.build_client_from_config(conf_string)
    client = Client.new
    client.client_id = conf_string['client_id']
    client.redirect_uri = conf_string['redirect_uri']
    client.name = conf_string['name']
    client.attributes = conf_string['attributes']
    client.allowed_scopes = conf_string['allowed_scopes']
    client
  end

  def self.load_clients
    clients = []
    Config.client_config.each do |ccnf|
      clients << build_client_from_config(ccnf)
    end
    clients
  end

  def self.from_json(json)
    client = Client.new
    client.client_id = json['client_id']
    client.name = json['name']
    client.attributes = json['attributes']
    client.allowed_scopes = json['allowed_scopes']
    client.redirect_uri = json['redirect_uri']
    client
  end

  def self.extract_jwt_cid(jwt)
    begin
      jwt_dec, jwt_hdr = JWT.decode(jwt, nil, false) # Decode without verify
      return nil unless jwt_dec['sub'] == jwt_dec['iss']
      return nil unless %w[RS256 RS512 ES256 ES512].include? jwt_hdr['alg']
    rescue StandardError => e
      puts "Error decoding JWT #{jwt}: #{e}"
      return nil
    end
    [jwt_hdr['alg'], jwt_dec['sub']]
  end

  def self.find_by_jwt(jwt)
    clients = load_clients
    puts "looking for client of #{jwt}" if ENV['APP_ENV'] != 'production'
    jwt_alg, jwt_cid = extract_jwt_cid jwt
    return nil if jwt_cid.nil?

    clients.each do |client|
      next unless client.client_id == jwt_cid

      puts "Client #{jwt_cid} found"
      # Try verify
      aud = ENV['OMEJDN_JWT_AUD_OVERRIDE'] || ENV['HOST'] || Config.base_config['host']
      JWT.decode jwt, client.certificate&.public_key, true,
                 { nbf_leeway: 30, aud: aud, verify_aud: true, algorithm: jwt_alg }
      return client
    rescue StandardError => e
      puts "Tried #{client.name}: #{e}" if ENV['APP_ENV'] != 'production'
      return nil
    end
    puts "ERROR: Client #{jwt_cid} does not exist"
    nil
  end

  def to_dict
    {
      'client_id' => @client_id,
      'name' => @name,
      'redirect_uri' => @redirect_uri,
      'allowed_scopes' => @allowed_scopes,
      'attributes' => @attributes
    }
  end

  def allowed_scoped_attributes(scopes)
    attrs = []
    Config.scope_mapping_config.each do |scope|
      next unless scopes.include?(scope[0]) && allowed_scopes.include?(scope[0])

      attrs += scope[1]
    end
    attrs
  end

  def certificate_file
    "keys/#{Base64.urlsafe_encode64(@client_id)}.cert"
  end

  def certificate
    begin
      filename = certificate_file
      cert = OpenSSL::X509::Certificate.new File.read filename
      now = Time.now
      return cert unless cert.not_after < now || cert.not_before > now
    rescue StandardError => e
      p "Unable to load key ``#{filename}'': #{e}"
    end
    nil
  end

  def certificate=(new_cert)
    # delete the certificate if set to nil
    filename = certificate_file
    if new_cert.nil?
      File.delete filename if File.exist? filename
      return
    end
    File.open(filename, 'w') { |file| file.write(new_cert) }
  end
end
