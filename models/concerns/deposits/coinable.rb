module Deposits
  module Coinable
    extend ActiveSupport::Concern

    included do
      validates_presence_of :payment_transaction_id
      validates_uniqueness_of :payment_transaction_id
      belongs_to :payment_transaction
    end

    def channel
      @channel ||= DepositChannel.find_by_key(self.class.name.demodulize.underscore)
    end

    def min_confirm?(confirmations)
			Rails.logger.info "DBG:TRACK_CONFIRMS: min_confirm check in coinable txid: #{self.txid}"
      update_confirmations(confirmations)
      confirmations >= channel.min_confirm && confirmations < channel.max_confirm
    end

    def max_confirm?(confirmations)
			Rails.logger.info "DBG:TRACK_CONFIRMS: max_confirm check in coinable txid: #{self.txid}"
      update_confirmations(confirmations)
      confirmations >= channel.max_confirm
    end

    def update_confirmations(confirmations)
			Rails.logger.info "DBG:TRACK_CONFIRMS: update_confirmations in coinable txid: #{self.txid}"
      if !self.new_record? && self.confirmations.to_s != confirmations.to_s
				Rails.logger.info "DBG:TRACK_CONFIRMS: update_confirmations, update_attribute in coinable txid: #{self.txid}"
        self.update_attribute(:confirmations, confirmations.to_s)
      end
    end

    

    def as_json(options = {})
      super(options).merge({
        txid: txid.blank? ? "" : txid[0..29],
        confirmations: payment_transaction.nil? ? 0 : payment_transaction.confirmations
      })
    end
  end
end
