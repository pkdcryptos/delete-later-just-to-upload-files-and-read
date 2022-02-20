module Worker
  class Kline5m

  
  def initialize
      
  end
  
  def redis
      @r ||= KlineDB.redis
  end
  
    def process(payload, metadata, delivery_info)
      @trade = Trade.new payload
      #Rails.logger.info "DBG: KLINE-WRITER: prepare Received trade : #{@trade.inspect}"
      create_global_keys_kline5m 
    end
    

    
    def create_global_keys_kline5m
        lasttid = @trade.id  
		
		#Rails.logger.info "DBG: KLINE-WRITER: kline5m received trade : #{lasttid}"		  
    	
	  
    	
    	trade_time = (@trade.tradetime/1000).to_i		
    	t1m = (trade_time/60).to_i*60
    	t1mlast = t1m-60
    	t1mlast1 = t1m-120
    	t1mlast2 = t1m-180
    	t1mlast3 = t1m-240
    	key1mlast = "ktio:#{@trade.market}:1m:#{t1mlast}"
    	key1mlast1 = "ktio:#{@trade.market}:1m:#{t1mlast1}"
    	key1mlast2 = "ktio:#{@trade.market}:1m:#{t1mlast2}"
    	key1mlast3 = "ktio:#{@trade.market}:1m:#{t1mlast3}"        
    	#1m pusher    	 
    	key1m = "ktio:#{@trade.market}:1m:#{t1m}"    	
  	   	
    	
    	#5m pusher
    	t5m = (trade_time/(5*60)).to_i*5*60
    	key5m = "ktio:#{@trade.market}:5m:#{t5m}"		
    	#Rails.logger.info "DBG: KLINE-WRITER: Kline5m prepare 5m starting process for tradeid: #{@trade.id}"
    	tsarray=[]	    
	    tsarray.push(Rails.cache.read key1mlast3) if Rails.cache.exist?(key1mlast3) && t1mlast3 >= t5m
	    tsarray.push(Rails.cache.read key1mlast2) if Rails.cache.exist?(key1mlast2) && t1mlast2 >= t5m
	    tsarray.push(Rails.cache.read key1mlast1) if Rails.cache.exist?(key1mlast1) && t1mlast1 >= t5m
	    tsarray.push(Rails.cache.read key1mlast) if Rails.cache.exist?(key1mlast) && t1mlast >= t5m
    	tsarray.push(Rails.cache.read key1m) if t1m >= t5m
    	st, _, high, low, _, volumes, tids = tsarray.transpose
    	starray = st.map{|t| Time.at(t)}
  		output5m = [t5m, tsarray.first[1], high.max, low.min, tsarray.last[4], volumes.sum.round(8), lasttid]	  		
    	#Rails.logger.info "DBG: KLINE-WRITER: Kline5m prepare 5m final array to calculate: t5m #{t5m} #{Time.at(t5m)} tsarray times :  #{starray.inspect} tsarray timestamps #{st.inspect} "    	
    	Rails.cache.write key5m, output5m, expires_in: 60.minutes 
  		#Rails.logger.info "DBG: KLINE-WRITER: Kline5m writes key #{key5m}, tid: #{@trade.id}, value: #{output5m}"	
	 
    	
    	#Rails.logger.info "DBG: KLINE-WRITER: kline5m completed trade : #{lasttid}"
    	
    	
    end


  end
end
