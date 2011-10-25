require 'devise_password_sharing_extension/hooks/password_sharing'

module Devise
  module Models
    module PasswordSharing
      extend ActiveSupport::Concern

      module ClassMethods
        Devise::Models.config(self, :enable_banning)
        Devise::Models.config(self, :geoip_database)
        Devise::Models.config(self, :time_frame)
        Devise::Models.config(self, :number_of_cities)
        Devise::Models.config(self, :white_listed_ips)
      end

      included do
        has_many :login_events, :class_name => 'DevisePasswordSharingExtension::LoginEvent'

        @@white_listed_ips = YAML::load(File.read(Rails.root.join('config', 'white_listed_ips.yml')))
      end

      def create_login_event!(request)
        unless @@white_listed_ips.include?(request.remote_ip)
          database = GeoIP.new(self.class.geoip_database)
          geo = database.city(request.remote_ip)

          login_events.create!(
            :ip_address => request.remote_ip,
            :latitude => geo.latitude,
            :longitude => geo.longitude,
            :city => geo.city_name,
            :country_code => geo.country_code2,
            :region_name => geo.region_name)
        end
      end

      def ban_for_password_sharing!
        return unless self.class.enable_banning
        self.banned_for_password_sharing_at = Time.now
        save(:validate => false)
      end

      def password_sharing?
        return true unless banned_for_password_sharing_at.nil?
        login_events.grouped_by_city(self.class.time_frame).any? do |g|
          g.count >= self.class.number_of_cities
        end
      end
    end
  end
end
