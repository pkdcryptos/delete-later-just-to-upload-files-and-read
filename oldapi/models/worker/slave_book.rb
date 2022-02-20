module Worker
  class SlaveBook

    def initialize(run_cache_thread=true)
	
	 
      @managers = {}
      #@managers_mini = {}
      @deletesasks = {}
      @deletesbids = {}
      @deletesasksIterator = {}
      @deletesbidsIterator = {}
      

      if run_cache_thread
        cache_thread = Thread.new do
          loop do
            sleep 0.3
            #cache_book used to serve api calls,  cache_book_mini used to serve pusher calls for deltas
            cache_book
            #cache_book_mini
          end
        end
      end
    end

    def process(payload, metadata, delivery_info)
	
	  Rails.logger.debug "received to slave_book: #{payload.inspect}"
      @payload = Hashie::Mash.new payload
      
	  Rails.cache.write "ktio:#{@payload.order.market}:depth:OBTimeSlave", Time.now
        
      
      case @payload.action
      when 'new'
        @managers.delete(@payload.market)
        #@managers_mini.delete(@payload.market)
        initialize_orderbook_manager(@payload.market)
        #initialize_orderbook_manager_mini(@payload.market)
      when 'add'
        book.add order
        #book_mini.add order
		Rails.cache.write "ktio:#{@payload.order.market}:depth:OBOidSlave", order.id
        
        
        
        
      when 'update'
        book.find(order).volume = order.volume # only volume would change
        
        #book_mini.find(order).volume = order.volume # only volume would change
        # update timestamp too
        #book_mini.find(order).timestamp = order.timestamp
       
                
        
      when 'remove'
        book.remove order
        #book_mini.remove order
        
      when 'removedelete'
        book.remove order
        #book_mini.remove order
        
        #Rails.logger.info "DBG: Delete asks for #{order.type} #{order.price}"
        
        # if order.type == 'ask'
        # @deletesasks[order.price]=DateTime.now.to_time.to_i
        # else
        # @deletesbids[order.price]=DateTime.now.to_time.to_i
        # end
        
        # #cleanup
        # @deletesasks.each do |key, value|      
	  			# if value < DateTime.now.ago(10).to_time.to_i 
	  			# @deletesasks.delete(key)
	  			# end
		# end
		# @deletesbids.each do |key, value|      
	  			# if value < DateTime.now.ago(10).to_time.to_i 
	  			# @deletesbids.delete(key)
	  			# end
		# end
        
        
        
        
                
        
      else
        raise ArgumentError, "Unknown action: #{@payload.action}"
      end
    rescue
      Rails.logger.error "Failed to process payload: #{$!}"
      Rails.logger.error $!.backtrace.join("\n")
    end

    def cache_book
      @managers.keys.each do |id|
        market = Market.find id
        Rails.cache.write "ktio:#{market}:depth:asks", get_depth(market, :ask)
        Rails.cache.write "ktio:#{market}:depth:bids", get_depth(market, :bid)
        Rails.logger.debug "SlaveBook (#{market}) updated"
       
      end
    rescue
      Rails.logger.error "Failed to cache book: #{$!}"
      Rails.logger.error $!.backtrace.join("\n")
    end
    
    def cache_book_mini
      @managers_mini.keys.each do |id|
        market = Market.find id
        Rails.cache.write "ktio:#{market}:depth:asks_mini", get_depth_mini(market, :ask)
        Rails.cache.write "ktio:#{market}:depth:bids_mini", get_depth_mini(market, :bid)
         
      end
    rescue
      Rails.logger.error "Failed to cache book: #{$!}"
      Rails.logger.error $!.backtrace.join("\n")
    end

    def order
      ::Matching::OrderBookManager.build_order @payload.order.to_h
    end

    def book
      manager.get_books(@payload.order.type.to_sym).first
    end
    def book_mini
      manager_mini.get_books(@payload.order.type.to_sym).first
    end

    def manager
      market = @payload.order.market
      @managers[market] || initialize_orderbook_manager(market)
    end
    
    def manager_mini
      market = @payload.order.market
      @managers_mini[market] || initialize_orderbook_manager_mini(market)
    end

    def initialize_orderbook_manager(market)
      @managers[market] = ::Matching::OrderBookManager.new(market, broadcast: false)
    end
    
    def initialize_orderbook_manager_mini(market)
      @managers_mini[market] = ::Matching::OrderBookManager.new(market, broadcast: false)
    end

    def get_depth(market, side)
      depth = Hash.new {|h, k| h[k] = 0 }
      price_group_fixed = market[:price_group_fixed]
      mode  = side == :ask ? BigDecimal::ROUND_UP : BigDecimal::ROUND_DOWN
      noOfEntriesToSend=1
      @managers[market.id].send("#{side}_orders").limit_orders.each do |price, orders|
        noOfEntriesToSend=noOfEntriesToSend+1
        break if noOfEntriesToSend>100
        price = price.round(price_group_fixed, mode) if price_group_fixed
        depth[price] += orders.map(&:volume).sum
      end

      depth = depth.to_a
      depth.reverse! if side == :bid
      depth.to_h
    end
    
    def get_depth_mini(market, side)
      depth = Hash.new {|h, k| h[k] = 0 }
      price_group_fixed = market[:price_group_fixed]
      mode  = side == :ask ? BigDecimal::ROUND_UP : BigDecimal::ROUND_DOWN
      if side=='ask'
          @deletesasksIterator = @deletesasks
	      @deletesasksIterator.each do |key, value|      
	  			if value > DateTime.now.ago(10).to_time.to_i 
	  			depth[key]=0
	  			end
	  			#Rails.logger.info "DBG: ktio:#{market.id}:depth:asks_mini deletes #{@deletesasks.inspect}"
		  end
	  else
	  		@deletesbidsIterator = @deletesbids
	  		@deletesbidsIterator.each do |key, value|      
	  			if value > DateTime.now.ago(10).to_time.to_i 
	  			depth[key]=0
	  			end
	  			#Rails.logger.info "DBG: ktio:#{market.id}:depth:asks_mini deletes #{@deletesbids.inspect}"
		  end
	  end
	 
	  
      @managers_mini[market.id].send("#{side}_orders").limit_orders.each do |price, orders|
        # have this price added to depth, if any of orders had timestamp in last 1 minute
        max_timestamp = orders.map(&:timestamp).max
        minuteago = DateTime.now.ago(10).to_time.to_i
        if max_timestamp>= minuteago
	        price = price.round(price_group_fixed, mode) if price_group_fixed
	        depth[price] += orders.map(&:volume).sum
	        #depth[price] = "#{depth[price]} TS: #{max_timestamp} MINUTEAGO: #{minuteago}"
       end
      end
      
      
#       #add all stoplimt orders to the depth
#       type = side == :ask ? 'OrderAsk' : 'OrderBid'
#       orders = Order.where(currency: market.code).where(type: type).where(isReadyForMatching: 0).pluck(:price, :volume)
#       ##Rails.logger.info "DBG: market #{market.code} get_depth_mini #{orders.inspect}"      
#       orders.each do |price, volume|
#       price = price.round(price_group_fixed, mode) if price_group_fixed
#       depth[price] += volume
#       end
#       
#       depth = depth.sort

      depth = depth.to_a
      depth.reverse! if side == :bid
      depth
    end

  end
end

