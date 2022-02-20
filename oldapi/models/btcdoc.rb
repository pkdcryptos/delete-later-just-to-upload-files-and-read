class Btcdoc < ActiveRecord::Base

  belongs_to :member
  
  validates_presence_of :address



  private

  

end


