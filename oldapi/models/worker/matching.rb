module Worker
  class Matching

    class DryrunError < StandardError
      attr :engine

      def initialize(engine)
        @engine = engine
      end
    end

    def initialize(options={})
      @options = options
      reload 'all'
    end

    def process(payload, metadata, delivery_info)
      payload.symbolize_keys!

      case payload[:action]
      when 'submit'
        submit build_order(payload[:order])
      when 'cancel'
        #Rails.logger.info "DBG: cancel received by user #{payload.inspect}"
        cancel build_order(payload[:order])
      when 'reload'
        reload payload[:market]
      else
        Rails.logger.fatal "Unknown action: #{payload[:action]}"
      end
    end

    def submit(order)
      #Rails.logger.info "DBG: submit sending to engine.rb from matching.rb"
      engines[order.market.id].submit(order)
    end

    def cancel(order)
      #Rails.logger.info "DBG: cancel sending to engine.rb from matching.rb"
      engines[order.market.id].cancel(order)
    end

    def reload(market)
      if market == 'all'
		#Rails.logger.info "DBG:ENGINE reload all markets"
        Market.all.each {|market| 
			initialize_engine market 
		}
        #Rails.logger.info "DBG:ENGINE All engines reloaded."
      else
        initialize_engine Market.find(market)
        #Rails.logger.info "DBG: #{market.id} engine reloaded."
      end
	
    rescue DryrunError => e
      # stop started engines
	  engines.each {|id, engine| engine.shift_gears(:dryrun) unless engine == e.engine }
	  Rails.logger.fatal "DBG:ENGINE #{market} engine failed to start. Matched during dryrun: "
      e.engine.queue.each do |trade|
        #Rails.logger.info "DBG: #{trade[1].inspect}"
      end
    end

    def build_order(attrs)
      ::Matching::OrderBookManager.build_order attrs
    end

    def initialize_engine(market)
	   #Rails.logger.info "DBG:ENGINE #{market.id} initialize_engine "
	#before starting engine, clean the cache book created by slave_book
	  depthClean = Hash.new {|h, k| h[k] = 0 }
      depthClean = depthClean.to_a      
	  Rails.cache.write "ktio:#{market.id}:depth:asks", depthClean.to_h
      Rails.cache.write "ktio:#{market.id}:depth:bids", depthClean.to_h
	  
	  
      create_engine market
      load_orders   market
      start_engine  market
    end

    def create_engine(market)
	  #Rails.logger.info "DBG:ENGINE #{market.id} create engine "
      engines[market.id] = ::Matching::Engine.new(market, @options)
    end

    def load_orders(market)
	   #Rails.logger.info "DBG:ENGINE #{market.id} loading orders "
      ::Order.active.with_currency(market.id).order('id asc').each do |order|
        submit build_order(order.to_matching_attributes)
      end
    end

    def start_engine(market)
	  #Rails.logger.info "DBG:ENGINE #{market.id} start_engine "
      engine = engines[market.id]
      if engine.mode == :dryrun
        if engine.queue.empty?
		  #Rails.logger.info "DBG:ENGINE #{market.id} engine queue empty going to shift gears run"      
          engine.shift_gears :run
        else
          accept = ENV['ACCEPT_MINUTES'] ? ENV['ACCEPT_MINUTES'].to_i : 30
          order_ids = engine.queue
            .map {|args| [args[1][:ask_id], args[1][:bid_id]] }
            .flatten.uniq

          orders = Order.where('created_at < ?', accept.minutes.ago).where(id: order_ids)
          if orders.exists?
            # there're very old orders matched, need human intervention
			#Rails.logger.info "DBG:ENGINE #{market.id} very orders matched raise DrurunError" 
            raise DryrunError, engine
          else
            # only buffered orders matched, just publish trades and continue
            engine.queue.each {|args| AMQPQueue.enqueue(*args) }
			#Rails.logger.info "DBG:ENGINE #{market.id} only buffered orders matched shiftgear run"
            engine.shift_gears :run
          end
        end
      else
        #Rails.logger.info "DBG:ENGINE #{market.id} engine already started. mode=#{engine.mode}"
      end
    end

    def engines
      @engines ||= {}
    end

    # dump limit orderbook
    def on_usr1
      engines.each do |id, eng|
        dump_file = File.join('/', 'tmp', "limit_orderbook_#{id}")
        limit_orders = eng.limit_orders

        File.open(dump_file, 'w') do |f|
          f.puts "ASK"
          limit_orders[:ask].keys.reverse.each do |k|
            f.puts k.to_s('F')
            limit_orders[:ask][k].each {|o| f.puts "\t#{o.label}" }
          end
          f.puts "-"*40
          limit_orders[:bid].keys.reverse.each do |k|
            f.puts k.to_s('F')
            limit_orders[:bid][k].each {|o| f.puts "\t#{o.label}" }
          end
          f.puts "BID"
        end

        puts "#{id} limit orderbook dumped to #{dump_file}."
      end
    end

    # dump market orderbook
    def on_usr2
      engines.each do |id, eng|
        dump_file = File.join('/', 'tmp', "market_orderbook_#{id}")
        market_orders = eng.market_orders

        File.open(dump_file, 'w') do |f|
          f.puts "ASK"
          market_orders[:ask].each {|o| f.puts "\t#{o.label}" }
          f.puts "-"*40
          market_orders[:bid].each {|o| f.puts "\t#{o.label}" }
          f.puts "BID"
        end

        puts "#{id} market orderbook dumped to #{dump_file}."
      end
    end

  end
end
