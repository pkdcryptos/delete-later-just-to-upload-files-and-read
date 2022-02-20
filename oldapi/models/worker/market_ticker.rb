module Worker
  class MarketTicker

    FRESH_TRADES = 80

    def initialize
      @tickers = {}
      @trades  = {}

      Market.all.each do |market|
        initialize_market_data market
        
        
      end
    end

    def process(payload, metadata, delivery_info)
      trade = Traade.new payload
      #Rails.logger.info "DBG: MarketTicker received trade : #{trade.inspect}"
      update_ticker trade
      update_latest_trades trade
	  
	  
	  
      #Rails.logger.info "DBG: BETA: updated tickers and latest trades for trade #{trade.id}"
      
    end

    def update_ticker(trade)
      ticker        = @tickers[trade.market.id]
      ticker[:low]  = get_market_low trade.market.id, trade
      ticker[:high] = get_market_high trade.market.id, trade
      ticker[:last] = trade.price
      ticker[:price] = trade.price
      ticker[:close] = trade.price
      ticker[:lasttid] = trade.id
      #Rails.logger.info "DBG: update ticker #{ticker.inspect}"
      Rails.cache.write "ktio:#{trade.market.id}:ticker", ticker
	   #update h24_volume
	  h24_volume = Rails.cache.read("ktio:#{trade.market.id}:h24_volume") + trade.volume
	  write_h24_key "ktio:#{trade.market.id}:h24_volume", h24_volume, 24.hours	
	  
	  
      
    end

    def update_latest_trades(trade)
      trades = @trades[trade.market.id]
      trades.unshift(trade.for_global)
      trades.pop if trades.size > FRESH_TRADES
	  
	 

      Rails.cache.write "ktio:#{trade.market.id}:trades", trades
      
    end

    def initialize_market_data(market)
      trades = Traade.with_currency(market)    
      

      @trades[market.id] = trades.order('id desc').limit(FRESH_TRADES).map(&:for_global)
      Rails.cache.write "ktio:#{market.id}:trades", @trades[market.id]
      

      low_trade = initialize_market_low(market.id)
      high_trade = initialize_market_high(market.id)
	  
	  initialize_market_h24_volume(market.id)
	  
	  market = Market.find_by_id(market.id)
		startingprice = market.unit_info[:startingprice]

      @tickers[market.id] = {
        # low:  low_trade.try(:price)   || ::Trade::ZERO,
        # high: high_trade.try(:price)  || ::Trade::ZERO,
        # last: trades.last.try(:price) || ::Trade::ZERO,
        # price: trades.last.try(:price) || ::Trade::ZERO,
        # close: trades.last.try(:price) || ::Trade::ZERO,
        # lasttid: trades.last.try(:id) || ::Trade::ZERO
		
		low:  low_trade.try(:price)   || startingprice,
        high: high_trade.try(:price)  || startingprice,
        last: trades.last.try(:price) || startingprice,
        price: trades.last.try(:price) || startingprice,
        close: trades.last.try(:price) || startingprice,
        lasttid: trades.last.try(:id) || ::Trade::ZERO
		
		
      }
      Rails.cache.write "ktio:#{market.id}:ticker", @tickers[market.id]
      
      #initialize required 3 keys for every market
      Rails.cache.write "ktio:#{market}:lasttid", trades.last.try(:id) || 0
	  Rails.cache.write "ktio:#{market}:lastclose", trades.last.try(:price) || ::Trade::ZERO
	  Rails.cache.write "ktio:#{market}:ticker:open", market.startingprice
	  
    end

    private

    def get_market_low(market, trade)
      low_key = "ktio:#{market}:h24:low"
      low = Rails.cache.read(low_key)

      if low.nil?
        tradeFromTable = initialize_market_low(market)
		#Rails.logger.info "DBG: initialize_market_low output: #{tradeFromTable}"
		if tradeFromTable.nil?
        low = trade.price
		else
		low = tradeFromTable.price
		end
      elsif trade.price < low
        low = trade.price
        write_h24_key low_key, low
      end
	  #Rails.logger.info "DBG: In get_market_low market: #{market}  low: #{low}"
      low
    end

    def get_market_high(market, trade)
      high_key = "ktio:#{market}:h24:high"
      high = Rails.cache.read(high_key)

      if high.nil?
        trade = initialize_market_high(market)
        high = trade.price
      elsif trade.price > high
        high = trade.price
        write_h24_key high_key, high
      end

      high
    end

    def initialize_market_low(market)
      if low_trade = Traade.with_currency(market).h24.order('price asc').first
        ttl = low_trade.created_at.to_i + 24.hours - Time.now.to_i
        write_h24_key "ktio:#{market}:h24:low", low_trade.price, ttl
        low_trade
      end
    end

    def initialize_market_high(market)
      if high_trade = Traade.with_currency(market).h24.order('price desc').first
        ttl = high_trade.created_at.to_i + 24.hours - Time.now.to_i
        write_h24_key "ktio:#{market}:h24:high", high_trade.price, ttl
        high_trade
      end
    end
	
	def initialize_market_h24_volume(market)
      h24_volume = Traade.with_currency(market).h24.sum(:volume) || ZERO
	  write_h24_key "ktio:#{market}:h24_volume", h24_volume, 24.hours	 
    end

    def write_h24_key(key, value, ttl=24.hours)
      Rails.cache.write key, value, expires_in: ttl
      key = "#{key}" 
      value = "#{value}" 
      expires_in = "#{ttl}" 
      
    end

  end
end
