module Worker
  class Kline1m

  
  def initialize
      @runtimeTrades = {}
  end
  
  def redis
      @r ||= KlineDB.redis
  end
  
    def process(payload, metadata, delivery_info)
      @trade = Trade.new payload
      create_global_keys_kline1m 
    end
    

    
    def create_global_keys_kline1m
        lasttid = @trade.id  
		
		Rails.logger.info "DBG: KLINE-WRITER: kline1m received trade : #{@trade.inspect}"		  
    	
		tradeMarket="#{@trade.baseAsset}#{@trade.quoteAsset}"
		
    	
    	lastclose = @trade.price.to_f
    	#trade_time = (@trade.tradetime/1000).to_i
		trade_time = Time.now.to_i
    	Rails.cache.write "ktio:#{tradeMarket}:lastclose", lastclose
    	t1m = (trade_time/60).to_i*60
    	t1mlast = t1m-60
    	t1mlast1 = t1m-120
    	t1mlast2 = t1m-180
    	t1mlast3 = t1m-240
    	key1mlast = "ktio:#{tradeMarket}:1m:#{t1mlast}"
    	key1mlast1 = "ktio:#{tradeMarket}:1m:#{t1mlast1}"
    	key1mlast2 = "ktio:#{tradeMarket}:1m:#{t1mlast2}"
    	key1mlast3 = "ktio:#{tradeMarket}:1m:#{t1mlast3}"
    	
    	
    	runtimeKey = "#{tradeMarket}_#{t1m.to_i}"
    	runtimeKeyLast = "#{tradeMarket}_#{t1mlast.to_i}"
    	@runtimeTrades[runtimeKey] ||= []
    	@runtimeTrades[runtimeKey].push lastclose.to_f  
    	o = @runtimeTrades[runtimeKey].first.to_f
        h = @runtimeTrades[runtimeKey].max.to_f
        l = @runtimeTrades[runtimeKey].min.to_f
         
		if tradeMarket=='p2pbtc'
		    Rails.logger.info "DBG: KLINE-WRITER: #{tradeMarket}"
			v = @runtimeTrades[runtimeKey].sum.round(16)
		else
			v = @runtimeTrades[runtimeKey].sum.round(8)
		end
		
		
		Rails.logger.info "DBG: KLINE-WRITER: close : #{lastclose.to_f }"
		Rails.logger.info "DBG: KLINE-WRITER: v : #{v.inspect}"		
        
        @runtimeTrades.delete(runtimeKeyLast)   
        #Rails.logger.info "DBG: KLINE-WRITER: Kline1m deletes runTimeKey #{runtimeKeyLast} if exists"	     
        
    	#1m pusher    	 
    	key1m = "ktio:#{tradeMarket}:1m:#{t1m}"    
    	c = lastclose  
		if tradeMarket=='p2pbtc'
		o = o * 10000000000000000
		h = h * 10000000000000000
		l = l * 10000000000000000
		c = c * 10000000000000000
		v = v * 10000000000000000
		end
		
    	out = [t1m, o, h, l, c, v, lasttid]
    	Rails.cache.write key1m, [t1m, o, h, l, c, v, lasttid], expires_in: 60.minutes   
    	#Rails.logger.info "DBG: KLINE-WRITER: Kline1m writes key #{key1m}, tid: #{@trade.id}, value: #{out}"	
		
		#Rails.logger.info "DBG: KLINE-WRITER: kline1m completed trade : #{lasttid}"
    	
    	
    	
    end


  end
end
