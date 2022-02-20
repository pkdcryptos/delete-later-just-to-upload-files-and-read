module Worker
  class TradeExecutor

    def process(payload, metadata, delivery_info)
      payload.symbolize_keys!
      ::Matching::Executor.new(payload).execute!
    rescue
      #todo temporarily disabled, but need to enable in production
      #SystemMailer.trade_execute_error(payload, $!.message, $!.backtrace.join("\n")).deliver
	#Rails.logger.info "DBG: FATAL SystemMailer trade_execute_error #{payload.inspect}, #{$!.message}, #{$!.backtrace.join("\n")}"

      raise $!
    end

  end
end
