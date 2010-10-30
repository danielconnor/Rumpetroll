require 'rubygems'
require 'oauth'
require 'json'

OAuthTokens = Struct.new(:request_token, :request_secret, :request_verifier, :access_token, :access_secret)

class TwitterApp
  
  attr_reader :key,:secret,:options
  attr_accessor :default_callback
  
  def initialize(key,secret,callback,options={})
    @key = key
    @secret = secret
    @default_callback = callback
    @options = {
      :site=>"https://api.twitter.com"
    }.merge(options)
  end
  
end

class TwitterAuthorization
  
  attr_reader :tokens,:authorize_url,:screen_name,:user_id

  def initialize(app,tokens=nil)
    
    @app      = app
    @tokens   = tokens || OAuthTokens.new()
    @consumer = OAuth::Consumer.new(app.key,app.secret,app.options)
    
  end
  
  def generate_authorize_url(options={})
    @authorize_url = nil
    options[:oauth_callback] ||= @app.default_callback
    request_token = @consumer.get_request_token( options )
    @tokens.request_token = request_token.token
    @tokens.request_secret = request_token.secret
    @authorize_url = request_token.authorize_url
  end
    
  def authorize(request_token=nil,request_verifier=nil)
    @tokens.request_token     = request_token || @tokens.request_token
    @tokens.request_verifier  = request_verifier || @tokens.request_verifier
    access_token != nil
  end
  
  def restore_session(token,secret)
    @tokens.access_token = token
    @tokens.access_secret = secret
    access_token
  end
      
  def request(*args)
    at = access_token
    at.request(*args) if at
  end
  
  def authorized?
    @access_token != nil
  end

  def get(path, headers={})
    headers.merge!("User-Agent" => "rumpetroll")
    oauth_response = access_token.get("/1#{path}", headers)
    return oauth_response.body
  end

  def post(path, body = '', headers={})
    headers.merge!("User-Agent" => "rumpetroll")
    oauth_response = access_token.post("/1#{path}",body, headers)
    return oauth_response.body
  end
    
  private
    
    def access_token
      @access_token ||= begin
        if @tokens.access_token && @tokens.access_secret
          at = OAuth::AccessToken.new(@consumer, @tokens.access_token, @tokens.access_secret)
          params = JSON.parse(at.get("/1/account/verify_credentials.json", {"User-Agent" => "rumpetroll"}).body)
          if params["error"] 
            at = nil
          end
        elsif @tokens.request_token && @tokens.request_secret && @tokens.request_verifier
          request_token = OAuth::RequestToken.new(@consumer, @tokens.request_token, @tokens.request_secret )
          at = request_token.get_access_token(:oauth_verifier => @tokens.request_verifier) rescue nil          
        end
        
        if at
          @tokens.access_token = at.token
          @tokens.access_secret = at.secret
          @screen_name = at.params[:screen_name] || params['screen_name']
          @user_id = at.params[:user_id] || params['id']
        end
        
        at
      end
                        
    end
  
end
