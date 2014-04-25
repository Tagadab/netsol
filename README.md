netsol
======

NetSol Partners API Gem

```ruby
require 'netsol'

ns = Netsol.new('12345678', 'test_password', :test)
# ns = Netsol.new('12345678', 'live_password', :live)
domains = ns.find_all_domains_for_partner
# => {:auto_renew=>false, :product_id=>"WN.D.XXXXXXX", :domain_name=>"XXXXXX.COM", :customer_id=>"1234567", :product_type=>"Registration"}, ...
```
