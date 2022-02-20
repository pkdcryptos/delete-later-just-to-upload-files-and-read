class Bpitoken < ActiveRecord::Base
  paranoid

  belongs_to :member
  
  serialize :trusted_ip_list

  validates_presence_of :access_key, :secret_key

  before_validation :generate_keys, on: :create

  

 
  def expired?
    expire_at && expire_at < Time.now
  end

  def in_scopes?(ary)
    return true if ary.blank?
    return true if self[:scopes] == 'all'
    (ary & scopes).present?
  end

  def allow_ip?(ip)
    trusted_ip_list.blank? || trusted_ip_list.include?(ip)
    #for time being beta purpose, allow all ip address
    true
  end

  def ip_whitelist=(list)
    self.trusted_ip_list = list.split(/,\s*/)
  end

  def ip_whitelist
    trusted_ip_list.try(:join, ',')
  end

  def scopes
    self[:scopes] ? self[:scopes].split(/\s+/) : []
  end

  private

  def generate_keys
    begin
      #self.access_key = APIv1::Auth::Utils.generate_access_key
			self.access_key = 1
    end while Bpitoken.where(access_key: access_key).any?

    begin
      #self.secret_key = APIv1::Auth::Utils.generate_secret_key
			self.secret_key = 1
    end while Bpitoken.where(secret_key: secret_key).any?
  end

end


