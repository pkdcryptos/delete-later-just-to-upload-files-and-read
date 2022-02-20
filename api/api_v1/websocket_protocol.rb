module APIv1
  class WebSocketProtocol

    def initialize(socket, channel, logger)
      @socket = socket
      @channel = channel #FIXME: amqp should not be mixed into this class
      @logger = logger
    end

    def challenge
      @challenge = SecureRandom.urlsafe_base64(40)
      send :challenge, @challenge
    end

    def handle(message)
      @logger.debug message

      message = JSON.parse(message)
      key     = message.keys.first
      data    = message[key]

      case key.downcase
      when 'auth'
        access_key = data['access_key']
        token = APIToken.where(access_key: access_key).includes(:member).first
        result = verify_answer data['answer'], token

        if result
          subscribe_orders
          subscribe_trades token.member
          send :success, {message: "Authenticated."}
        else
          send :error, {message: "Authentication failed."}
        end
      else
      end
    rescue
      @logger.error "Error on handling message: #{$!}"
      @logger.error $!.backtrace.join("\n")
    end

    private

    def send(method, data)
      payload = JSON.dump({method => data})
      @logger.debug payload
      @socket.send payload
    end

    def verify_answer(answer, token)
      str = "#{token.access_key}#{@challenge}"
      answer == OpenSSL::HMAC.hexdigest('SHA256', token.secret_key, str)
    end

   


  end
end
