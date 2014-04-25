require 'net/https'
require 'erb'
require 'nokogiri'

class Netsol
  
  CONFIG = {
    :host => {
      :test => 'partners.pte.networksolutions.com',
      :live => 'partners.networksolutions.com'
    },
    :api => {
      :availability => {
        :path => '/invoke/vpp/AvailabilityService',
        :port => 8010
      },
      :transaction  => {
        :path => '/invoke/vpp/TransactionService',
        :port => 8020
      }
    }
  }

  def initialize(user, pass, mode = :live)
    environments = [:test, :live]
    unless environments.include? mode
      raise "mode is invalid, must be #{environments.map(&:inspect).join(' or ')}"
    end

    @user,@pass,@mode = user,pass,mode
    @host = CONFIG[:host][@mode]
  end

  def find_all_customers_for_partner
    response = transmit(CONFIG[:api][:transaction], request_body)

    customers = Nokogiri::XML(response.body, &:noblanks).xpath('//Customer').map do |c|
      type = c.children.first.name
      data = {
        :type => type,
        :user_id => c.xpath("#{type}/UserID/text()")[0].to_s,
        :nic_handle => c.xpath("#{type}/NicHandle/text()")[0].to_s,
        :login_name => c.xpath("#{type}/LoginName/text()")[0].to_s
      }

      case data[:type]
      when 'Individual'
        data.merge!(
          :first_name => c.xpath("#{type}/FirstName/text()")[0].to_s,
          :last_name => c.xpath("#{type}/LastName/text()")[0].to_s
        )
      when 'Business'
        data.merge!(
          :company_name => c.xpath("#{type}/CompanyName/text()")[0].to_s,
          :legal_contact => {
            :first_name => c.xpath("#{type}/LegalContactFirstName/text()")[0].to_s,
            :last_name => c.xpath("#{type}/LegalContactLastName/text()")[0].to_s
          }
        )
      end

      data
    end
  end

  def find_all_domains_for_partner
    response = transmit(CONFIG[:api][:transaction], request_body)
    
    domains = Nokogiri::XML(response.body, &:noblanks).xpath('//Domain').map do |domain|
      {
        :product_id  => domain.xpath('ProductID/text()')[0].to_s,
        :domain_name => domain.xpath('DomainName/text()')[0].to_s,
        :customer_id => domain.xpath('CustomerID/text()')[0].to_s,
        :product_type => domain.xpath('ProductType/text()')[0].to_s,
        :auto_renew => (domain.xpath('AutoRenew/text()')[0].to_s == 'Y')
      }
    end
  end

  def modify_registration
    raise 'Not yet implemented'
    # @domain_name = nil
    # @customer_id = nil
    # @auto_renew  = nil
  end

  def create_individual
    raise 'Not yet implemented'
    # @individual = {
    #   :login_name  => nil,
    #   :password    => nil,
    #   :first_name  => nil,
    #   :middle_name => nil,
    #   :last_name   => nil,
    #   :address => {
    #     :line_1       => nil,
    #     :city         => nil,
    #     :state        => nil,
    #     :post_code    => nil,
    #     :country_code => nil
    #   },
    #   :phone => nil,
    #   :fax   => nil,
    #   :email => nil,
    #   :auth => {
    #     :question => nil,
    #     :answer   => nil
    #   }
    # }
  end

private

  def transmit(location, body)
    https = Net::HTTP.new(@host, location[:port])
    https.use_ssl = true
    https.verify_mode = OpenSSL::SSL::VERIFY_NONE
    response = https.start{ |http| http.post(location[:path], body) }
    raise "Response returned code #{response.code}: #{response.msg}." unless response.code == '200'

    response
  end

  def request_body
    method = caller[0][/`([^']*)'/, 1]

    ERB.new(File.read("xml/#{method}.xml.erb")).result(binding)
  end

  def header
    @header_xml ||= ERB.new(File.read("xml/header.xml.erb")).result(binding)
  end

end
