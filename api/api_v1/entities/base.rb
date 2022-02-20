module APIv1
  module Entities
    class Base < Grape::Entity
      format_with(:iso8601) {|t| t.iso8601 if t }
      format_with(:decimal) {|d| d.to_s('F') if d }
      format_with(:timestamp) {|d| d.to_i if d }
      format_with(:timestamp1000) {|d| d.to_i*1000 if d }
      format_with(:uppercase) {|d| d.upcase if d }
      format_with(:capitalize) {|d| d.capitalize  if d }
    end
  end
end