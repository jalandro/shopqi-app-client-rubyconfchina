#encoding: utf-8
#ruby orders.rb this_is_the_api_key_foo_foo_foo0 this_is_the_password_foo_foo_foo
require "rubygems"
require "bundler/setup"

require "ap"
require "active_support/all"
require "shopkit"

api_key = ARGV[0] # https://rubyconfchina-shop.shopqi.com/admin/api_clients
password = ARGV[1]
Shopkit.setup url: 'https://rubyconfchina-shop.shopqi.com', login: api_key, password: password
Shopkit.auto_traversal = true # 获取所有的分页记录

orders = Shopkit.orders(financial_status: 'paid').select {|order| order['total_price'] > 10 } # 只要已支付订单，并排除测试订单

products = {} # product_id => quantity_sum
orders.each do |order|
  order['line_items'].each do |item| # 销售量
    product_id = item['product_id']
    products[product_id] ||= 0
    products[product_id] += item['quantity'].to_i
  end
end
total_price = orders.map {|order| order['total_price'].to_i}.sum
alipay = (total_price - total_price*0.012).to_i
puts "售出: #{products.map {|id, value| "#{Shopkit.product(id)['title']}: #{value} 张"}.join(';  ')}"
puts "总计: #{total_price}; 扣除支付宝手续费: #{alipay}\n" # 26383, 26066

#ap orders.first # 可以看下还需要哪些属性

puts "序号\t订单号\temail\t姓名(备注)\t门票数量\t是否公司票\t金额\t创建时间"
orders.each_with_index do |order, index|
  name = (order['note'] || order['customer']['name']).gsub("\r\n",',')
  email = order['email']
  size = order['line_items'].inject(0) {|sum, item| sum += item['quantity']; sum}
  is_company = order['line_items'].any? {|item| item['title'] =~ /公司票/}
  price = order['total_price']
  created_at = Date.parse(order['created_at']).to_s(:db)

  puts "#{index+1}\t#{order['name']}\t#{email}\t#{name}\t#{size}\t#{is_company}\t#{price}\t#{created_at}"
end
