module Worker
  class OrderProcessor

    def initialize
      @cancel_queue = []
      create_cancel_thread
    end

    def process(payload, metadata, delivery_info)
      case payload['action']
      when 'cancel'
        unless check_and_cancel(payload['order'])
          @cancel_queue << payload['order']
        end
      else
        raise ArgumentError, "DBG: Unrecogonized action: #{payload['action']}"
      end
    rescue
      #todo temporarily disabled, but need to enable in production
      #SystemMailer.order_processor_error(payload, $!.message, $!.backtrace.join("\n")).deliver
	#Rails.logger.info "DBG: FATAL SystemMailer order_processor_error #{payload.inspect}, #{$!.message}, #{$!.backtrace.join("\n")}"
      raise $!
    end

    def check_and_cancel(attrs)
      retry_count = 5
      begin
        order = Order.find attrs['id']
        if order.volume.to_d == attrs['volume'].to_d  || (order.volume.to_d - attrs['volume'].to_d).abs <= 0.00000002 # all trades has been processed
          Ordering.new(order).cancel!
          #puts "Order##{order.id} cancelled because volumes not diffed."
          #Rails.logger.info "DBG: Order##{order.id}  cancelled  because volumes not diffed. retry_count: #{retry_count} #{order.volume.to_d} #{attrs['volume'].to_d}"
          true
        else
        	#Rails.logger.info "DBG: Order##{order.id} not cancelled  because volumes diffed. retry_count: #{retry_count} #{order.volume.to_d} #{attrs['volume'].to_d}"
          false
        end
      rescue ActiveRecord::StatementInvalid
        # in case: Mysql2::Error: Lock wait timeout exceeded
        if retry_count > 0
          sleep 0.5
          retry_count -= 1
          puts $!
          puts "Retry order.cancel! (#{retry_count} retry left) .."
          #Rails.logger.info "DBG: Retry order.cancel! (#{retry_count} retry left) .. retry_count: #{retry_count} #{order.volume.to_d} #{attrs['volume'].to_d}"
          retry
        else
          puts "Failed to cancel order##{order.id}"
          #Rails.logger.info "DBG: Failed to cancel order##{order.id} retry_count: #{retry_count} #{order.volume.to_d} #{attrs['volume'].to_d}"
          raise $!
        end
      end
    rescue Ordering::CancelOrderError
      puts "DBG: Skipped: #{$!}"
      true
    end

    def process_cancel_jobs
      queue = @cancel_queue
      @cancel_queue = []

      queue.each do |attrs|
        unless check_and_cancel(attrs)
          @cancel_queue << attrs
        end
      end

      #Rails.logger.info "DBG: Cancel queue size: #{@cancel_queue.size}"
    rescue
      #Rails.logger.info "DBG: Failed to process cancel job: #{$!}"
      Rails.logger.debug $!.backtrace.join("\n")
    end

    def create_cancel_thread
      Thread.new do
        loop do
          sleep 5
          process_cancel_jobs
        end
      end
    end

  end
end
