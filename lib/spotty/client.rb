require 'http'
require 'base64'
require 'webrick'
require 'multi_json'
require 'addressable'

class Spotty
  class Client
    SCOPES = [
      "playlist-read-private",
      "playlist-read-collaborative",
      "playlist-modify-public",
      "playlist-modify-private",
      "streaming",
      "user-follow-modify",
      "user-follow-read",
      "user-library-read",
      "user-library-modify",
      "user-read-private",
      "user-read-birthdate",
      "user-read-email",
      "user-top-read"
    ]

    def initialize
      refresh
    end

    def configure 
      require 'tty-prompt'
      prompt = TTY::Prompt.new

      prompt.puts "\nSpotty needs to be authorized as a Spotify Application to use Spotify's Web API. It only takes a minute to setup.\n\n"
      prompt.puts "First, create an new application at: \n\n"
      prompt.ok "    https://developer.spotify.com/my-applications\n"
      prompt.ask "Hit enter when you're ready to continue."

      config = {}
      config['id'] = prompt.ask "\nClient ID: " 
      config['secret'] = prompt.ask 'Client Secret: '

      port = rand((1025..9999))

      config['redirect'] = Addressable::URI.new(
        port: port,
        scheme: 'http',
        host: 'localhost',
      ).to_s

      url = Addressable::URI.new(
        scheme: 'https',
        path: '/authorize',
        host: 'accounts.spotify.com',
        query_values: {
          client_id: config['id'], 
          scope: SCOPES.join(' '),
          response_type: 'code',
          redirect_uri: config['redirect']
        }
      ).to_s

      prompt.puts "\nAdd the following URL to your application's list of callbacks:\n\n"
      prompt.ok "    #{config['redirect']}\n"
      prompt.ask "Remember to click 'Save' after adding the url. Hit enter when you're done."
      prompt.puts "Visit the following URL to finish authorizing Spotty:\n\n"
      prompt.ok "   #{url}\n"
      prompt.error "Waiting for authorization ..."

      server = WEBrick::HTTPServer.new :Port => port 

      server.mount_proc '/' do |req, res|
        if req.query['error']
          prompt.error req.query['error']
          res.body = req.query['error']
          server.shutdown
        elsif req.query['code']
          config['code'] = req.query['code']
          prompt.ok 'Authorization code received'
          res.body = 'Spotty has successfully authenticated! You can close this window'
          server.shutdown
        else
          res.body = 'Waiting for Spotify to send an authorization code ...'
        end
      end

      server.start

      unless config['code']
        raise 'Authorization failed: Spotify did not send an authorization code'
      end

      params = [config['id'],config['secret']]
      basic = Base64.strict_encode64(params.join(':'))
      client = HTTP.headers(Authorization: "Basic #{basic}")

      response = client.post('https://accounts.spotify.com/api/token', form: {
        grant_type: 'authorization_code',
        code: config['code'],
        redirect_uri: config['redirect']
      })

      if response.code != 200
        raise "Authorization failed: #{response.body}"
      end

      save response.parse.merge(
        'id': config['id'],
        'secret': config['secret']
      )
    end

    def method_missing method, *args, &block
      if @http.respond_to? method
        refresh
        @http.send method, *args, &block
      else
        super method, @args, &block
      end
    end

    private

    def save config
      config['created_at'] = Time.now
      path = File.expand_path '~/.spotty'
      File.write path, MultiJson.dump(config, pretty: true)
    end

    def refresh
      if @http.nil?
        path = File.expand_path '~/.spotty'
        
        configure unless File.exists? path
        @config = MultiJson.load(File.read(path))
        @config['created_at'] = Time.parse @config['created_at']

        @http = HTTP.headers(
          Authorization: "Bearer #{@config['access_token']}"
        )
      end

      if @config['created_at'] + @config['expires_in'] < Time.now
        params = [@config['id'],@config['secret']]
        basic = Base64.strict_encode64(params.join(':'))
        client = HTTP.headers(Authorization: "Basic #{basic}")

        response = client.post('https://accounts.spotify.com/api/token', form: {
          grant_type: 'refresh_token',
          refresh_token: @config['refresh_token']
        })

        if response.code != 200
          raise "Authorization failed: #{response.body}"
        end

        @config.merge! response.parse
        save @config

        @http = HTTP.headers(
          Authorization: "Bearer #{@config['access_token']}"
        )
      end
    end
  end
end