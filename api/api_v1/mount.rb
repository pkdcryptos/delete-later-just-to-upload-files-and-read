require_relative 'errors'
require_relative 'validations'

module APIv1
  class Mount < Grape::API
    PREFIX = '/api'

    version 'v1', using: :path

    cascade false

    format :json
    default_format :json

    helpers ::APIv1::Helpers

    do_not_route_options!

    use APIv1::Auth::Middleware

    include Constraints
    include ExceptionHandlers

    before do
      header 'Access-Control-Allow-Origin', '*'
    end

    mount Members    
		mount Public
    mount Support
mount Tools

    base_path = Rails.env.production? ? "#{ENV['URL_SCHEMA']}://#{ENV['URL_HOST']}/#{PREFIX}" : PREFIX
    add_swagger_documentation base_path: base_path,
      mount_path: '/doc/swagger', api_version: 'v1',
      hide_documentation_path: true
  end
end
