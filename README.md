netsol
======

This gem provides easy consumption of the NetSol Partners API (Version 6.8)

```ruby
require 'netsol'

ns = Netsol.new('12345678', 'test_password', :test)
# ns = Netsol.new('12345678', 'live_password', :live)

customers = ns.find_all_customers_for_partner
# => {:nic_handle=>"1234567P", :type=>"Individual", :login_name=>"1234567", :first_name=>"John", :last_name=>"Smith", :user_id=>"1234567"}, ...

domains = ns.find_all_domains_for_partner
# => {:auto_renew=>false, :product_id=>"WN.D.XXXXXXX", :domain_name=>"XXXXXX.COM", :customer_id=>"1234567", :product_type=>"Registration"}, ...
```
