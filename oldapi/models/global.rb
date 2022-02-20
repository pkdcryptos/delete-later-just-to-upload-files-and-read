class Global
  ZERO = '0.0'.to_d
  NOTHING_ARRAY = YAML::dump([])
  LIMIT = 80

  class << self
    def channel
      "market-global-ticker"
    end

    def trigger(event, data)
      Pusher.trigger_async(channel, event, data)
    end

    def daemon_statuses
      Rails.cache.fetch('ktio:daemons:statuses', expires_in: 3.minutes) do
		Daemons::Rails::Monitoring.statuses
	  end
    end
  end


  def initialize(currency)
    @currency = currency
  end

  def channel_update
    "market-#{@currency}-global-update-ob"
  end
  
  def channel_update_mini
    "market-#{@currency}-global-update-mini-ob"
  end
  
  def channel_trades
    "market-#{@currency}-global-trades-tb"
  end
  
  
  

  attr_accessor :currency

  def self.[](market)
    if market.is_a? Market
      self.new(market.id)
    else
      self.new(market)
    end
  end

  def key(key, interval=5)
    seconds  = Time.now.to_i
    time_key = seconds - (seconds % interval)
    "ktio:#{@currency}:#{key}:#{time_key}"
  end

  def asks
    Rails.cache.read("ktio:#{currency}:depth:asks") || []
  end

  def bids
    Rails.cache.read("ktio:#{currency}:depth:bids") || []
  end
  

  def asks_mini
    Rails.cache.read("ktio:#{currency}:depth:asks_mini") || []
  end

  def bids_mini
    Rails.cache.read("ktio:#{currency}:depth:bids_mini") || []
  end

  def default_ticker
    {
	
	low: ZERO, high: ZERO, last: ZERO, price: ZERO, close: ZERO, volume: ZERO
	}
  end

  def ticker
    ticker           = Rails.cache.read("ktio:#{currency}:ticker") || default_ticker
    open = Rails.cache.read("ktio:#{currency}:ticker:open") || ticker[:last]
    #best_buy_price   = bids.first && bids.first[0] || ZERO
    #best_sell_price  = asks.first && asks.first[0] || ZERO
	
    
    
    ticker.merge({
      status: 1,
      open: open,
      volume: h24_volume,
      tradedMoney: h24_volume,
      quoteVolume: h24_volume,
      #sell: best_sell_price,
      #buy: best_buy_price,
      at: at
    })
  end

  def h24_volume
    if Rails.cache.read("ktio:#{@currency}:h24_volume").nil? || Rails.cache.read("ktio:#{@currency}:lastclose").nil?
	ZERO
	else
    h24_volumeVal = Rails.cache.read("ktio:#{@currency}:h24_volume") * Rails.cache.read("ktio:#{@currency}:lastclose")
	h24_volumeVal || ZERO
	end
    # Rails.cache.fetch key('h24_volume', 5), expires_in: 24.hours do
      # Traade.with_currency(currency).h24.sum(:volume) || ZERO
    # end
  end

  def trades
    output = Rails.cache.read("ktio:#{currency}:trades") || []
    #Rails.logger.info "DBG: trades function output : #{output.inspect}"
    output
  end

  def trigger_orderbook
    asksKeys = asks.nil? || asks.empty? ? [] : asks.keys
      bidsKeys = bids.nil? || bids.empty? ? [] : bids.keys 
	  
    data = {time: Time.now.to_i, mstime: Time.now,   market: currency, OBOidMaster: Rails.cache.read("ktio:#{currency}:depth:OBOidMaster") || '',  OBTimeMaster: Rails.cache.read("ktio:#{currency}:depth:OBTimeMaster") || '', OBOidSlave: Rails.cache.read("ktio:#{currency}:depth:OBOidSlave") || '',  OBTimeSlave: Rails.cache.read("ktio:#{currency}:depth:OBTimeSlave") || '',  asks: asks, bids: bids, asksKeys: asksKeys, bidsKeys: bidsKeys}
    Pusher.trigger_async(channel_update, "update", data)
    
  end
  def trigger_orderbook_mini
    data = {time: Time.now.to_i, mstime_mini: Time.now,  market: currency, OBOidMaster: Rails.cache.read("ktio:#{currency}:depth:OBOidMaster") || '',  OBTimeMaster: Rails.cache.read("ktio:#{currency}:depth:OBTimeMaster") || '', OBOidSlave: Rails.cache.read("ktio:#{currency}:depth:OBOidSlave") || '',  OBTimeSlave: Rails.cache.read("ktio:#{currency}:depth:OBTimeSlave") || '', asks: asks_mini, bids: bids_mini, asksKeys: asks_mini.keys, bidsKeys: bids_mini.keys}
    #Pusher.trigger_async(channel_update_mini, "update", data)
    
  end

  def trigger_trades(trades)
    #Rails.logger.info "DBG:  trigger_trades market #{currency} channel_trades #{channel_trades} trades : #{trades}"
    Pusher.trigger_async(channel_trades, "trades", time: Time.now.to_i, market: currency, trades: trades)
  end

  def at
    @at ||= DateTime.now.to_i
  end
  

  
  
  
end
