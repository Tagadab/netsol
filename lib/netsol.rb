require 'net/https'
require 'haml'
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

  # This is to split the lookup request into smaller requests
  # (NetSol blocks requests which are too long)
  def lookup_domain(domain_names)
    result = {}
    result[:domains] = {}

    group_array(domain_names, per_group = 100).each do |domain_names_100|
      result[:domains].merge!(_lookup_domain(domain_names_100)[:domains])
    end

    result
  end
  
  def _lookup_domain(domain_names)
    @domain_names = domain_names
    response = Nokogiri::XML(transmit(CONFIG[:api][:transaction], request_body).body, &:noblanks)

    status = response.xpath('/LookupResponse/Body/Status')
    status_code = status.xpath('StatusCode/text()')[0].to_s.to_i
    status_desc = status.xpath('Description/text()')[0].to_s
    success_codes = [11702]

    raise "Unable to modify registration: [#{status_code}] #{status_desc}" unless success_codes.include?(status_code)

    domains = {}
    
    response.xpath('/LookupResponse/Body/Domain').each do |de|
      domains[de.xpath('DomainNameProperties/text()')[0].to_s] =
        de.xpath('HostData').map{ |host| host.xpath('HostName/text()')[0].to_s }
    end

    {
      :status => {
        :code => status_code,
        :message => status_desc
      },
      :domains => domains
    }
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
        :auto_renew => (domain.xpath('AutoRenew/text()')[0].to_s == 'Y'),
        :domain_protect => domain.xpath('DomainProtect')[0].attr('Selection'),
        :purchase_date => domain.xpath('PurchaseDate')[0].child.text,
        :expiration_date => domain.xpath('ExpirationDate')[0].child.text
      }
    end
  end

  def modify_registration(customer_id, domain_name, auto_renew)
    @customer_id,@domain_name,@auto_renew = customer_id,domain_name,auto_renew
    response = Nokogiri::XML(transmit(CONFIG[:api][:transaction], request_body).body, &:noblanks)
    
    status = response.xpath('/OrderResponse/Body/Order/Status')
    status_code = status.xpath('StatusCode/text()')[0].to_s.to_i
    status_desc = status.xpath('Description/text()')[0].to_s
    success_codes = [7000]

    raise "Unable to modify registration: [#{status_code}] #{status_desc}" unless success_codes.include?(status_code)

    {
      :status => {
        :code => status_code,
        :message => status_desc
      },
      :reference_number => response.xpath('/OrderResponse/Body/Order/ReferenceNumber/text()')[0].to_s,
      :order_id => response.xpath('/OrderResponse/Body/Order/OrderID/text()')[0].to_s
    }
  end

  def create_individual(individual)
    @individual = {
      :login_name  => nil,
      :password    => nil,
      :first_name  => nil,
      :middle_name => nil,
      :last_name   => nil,
      :address => {
        :line_1       => nil,
        :city         => nil,
        :state        => nil,
        :post_code    => nil,
        :country_code => nil
      },
      :phone => nil,
      :fax   => nil,
      :email => nil,
      :auth => {
        :question => nil,
        :answer   => nil
      }
    }.merge(individual)

    response = Nokogiri::XML(transmit(CONFIG[:api][:transaction], request_body).body, &:noblanks)

    status = response.xpath('/UserResponse/Body/Status')
    status_code = status.xpath('StatusCode/text()')[0].to_s.to_i
    status_desc = status.xpath('Description/text()')[0].to_s
    success_codes = [5700, 5703]

    raise "Unable to create individual: [#{status_code}] #{status_desc}" unless success_codes.include?(status_code)
    
    {
      :status => {
        :code => status_code,
        :message => status_desc
      },
      :user_id => response.xpath('/UserResponse/Body/UserID/text()')[0].to_s.to_i,
      :login_name => response.xpath('/UserResponse/Body/LoginName/text()')[0].to_s
    }
  end

  def create_registration(customer_id, domain, purchase_period)
    @customer_id = customer_id
    @domain = {
      :name => domain,
      :purchase_period => purchase_period,
    }

    response = Nokogiri::XML(transmit(CONFIG[:api][:transaction], request_body).body, &:noblanks)

    status = response.xpath('/OrderResponse/Body/Order/Status')
    status_code = status.xpath('StatusCode/text()')[0].to_s.to_i
    status_desc = status.xpath('Description/text()')[0].to_s
    success_codes = [7000]

    raise "Unable to create registration: [#{status_code}] #{status_desc}" unless success_codes.include?(status_code)
    
    {
      :status => {
        :code => status_code,
        :message => status_desc
      },
      :order_id => response.xpath('/OrderResponse/Body/Order/OrderID/text()')[0].to_s.to_i,
      :price => response.xpath('/OrderResponse/Body/Order/Price/text()')[0].to_s.to_f
    }
  end

private

  def root
    @@root ||= File.expand_path('../..', __FILE__)
  end

  def transmit(location, body)
    https = Net::HTTP.new(@host, location[:port])
    https.use_ssl = true
    https.read_timeout = 5 * 60
    https.verify_mode = OpenSSL::SSL::VERIFY_NONE
    response = https.start{ |http| http.post(location[:path], body) }
    raise "Response returned code #{response.code}: #{response.msg}." unless response.code == '200'

    response
  end

  def request_body
    method = caller[0][/`([^']*)'/, 1]

    Haml::Engine.new(File.read("#{root}/xml/#{method}.haml")).render(binding)
  end

  def header
    @header_xml ||= Haml::Engine.new(File.read("#{root}/xml/_header.haml")).render(binding)
  end

  def auth
    @auth_xml ||= Haml::Engine.new(File.read("#{root}/xml/_auth.haml")).render(binding)
  end

  # This is necessary as including activesupport (outside of rails) is a nightmare prior to v3.0
  def group_array(array, per_group)
    container = []
    array.each do |item|
      if container.last && container.last.size < per_group
        container.last << item
      else
        container << [item]
      end
    end

    container
  end

end
