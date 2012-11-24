#encoding: utf-8
require "rubygems"
require "bundler/setup"

require "ap"
require "active_support/all"
require "shopkit"

api_key = ARGV[0] # https://rubyconfchina-shop.shopqi.com/admin/api_clients
password = ARGV[1]
only_summary = (ARGV[2] == 'summary')

Shopkit.setup url: 'https://rubyconfchina-shop.shopqi.com', login: api_key, password: password
Shopkit.auto_traversal = true # 获取所有的分页记录

orders = Shopkit.orders(financial_status: 'paid').select {|order| order['total_price'] > 10 } # 只要已支付订单，并排除测试订单
refunded_orders = Shopkit.orders(financial_status: 'refunded').select {|order| order['total_price'] > 10 }

products = {} # product_id => quantity_sum
orders.each do |order|
  order['line_items'].each do |item| # 销售量
    product_id = item['product_id']
    products[product_id] ||= 0
    products[product_id] += item['quantity'].to_i
  end
end

alipay_fee = 0.012  # 支付宝收款费率
tax_fee = 0.076     # 税款费率
express_fee = 22    # 顺丰快递

total_price = orders.map{|order| order['total_price'].to_i}.sum
refunded_total_price = refunded_orders.map{|order| order['total_price'].to_i}.sum 
refunded_fee = refunded_total_price * alipay_fee
alipay_total_fee = total_price * alipay_fee
alipay = total_price - alipay_total_fee - refunded_fee

total_quantity = 400 # 门票总数
selled = products.values.sum

##### 公司票手续费 #####
company_orders = orders.select do |order|
  order['id'] != 501 and order['line_items'].any?{|item| item['title'] =~ /公司票/} # 排除 intridea 公司
end
express = company_orders.size * express_fee
company_quantities = company_orders.map do |order|
  order['line_items'].map{|item| item['quantity']}.sum
end.sum
tax = company_orders.map{|order| order['total_price'].to_i }.sum * tax_fee
company_fee = express + tax

##### 学生票手续费 #####
student = (990 * tax_fee + express_fee) + (1086.24 * tax_fee + express_fee)

##### 非系统下单公司票手续费 #####
out_company = 600 * tax_fee + express_fee

##### 销售情况统计 #####
puts "售出: #{selled} 张"
products.each do |id, value|
  puts "\t#{Shopkit.product(id)['title']}: #{value} 张"
end
puts "库存: #{total_quantity - selled} 张\n\n"

puts "总计: #{total_price} 元"
puts "支付宝收款手续费: #{alipay_total_fee.round(2)} 元"
puts "退款: #{refunded_orders.size} 笔; 金额 #{refunded_total_price} 元; 手续费 #{refunded_fee.round(2)} 元"
puts "总收入(扣除支付宝收款和退款手续费): #{alipay.round(2)} 元\n\n"

puts "公司票手续费(不含intridea)"
puts "订单数: #{company_orders.size} 笔; 票数 #{company_quantities} 张"
puts "快递费: #{express} 元"
puts "税款: #{tax} 元"
puts "小计(税款和快递费): #{company_fee} 元\n\n"

puts "学生票手续费(2笔,含税款和快递费): #{student.round(2)} 元\n\n"
puts "非系统下单公司票手续费(1笔,含税款和快递费): #{out_company.round(2)} 元\n\n"

puts "结算(总收入 - 公司票手续费 - 学生票手续费): #{(alipay - company_fee - student - out_company).round(2)} 元\n\n"

#ap orders.first # 可以看下还需要哪些属性

##### 列表订单明细 #####
unless only_summary
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
end
