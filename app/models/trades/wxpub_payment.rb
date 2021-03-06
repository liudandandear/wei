class WxpubPayment < Payment
  TRADE_SUCCESS_CODE = 'SUCCESS'

  def notify_url
    "#{APP_CONFIG['domain']}/payments/wx_notify"
  end

  def fill_pay_data(openid, config_name)
    generate_payment_no

    content = {
        out_trade_no: payment_no,
        total_fee: (total_fee * 100).to_i,
        spbill_create_ip: '127.0.0.1',
        trade_type: 'JSAPI',
        body: order.title,
        notify_url: notify_url,
        openid: openid
    }

    pay_config = WxpubPayConfig.fetch config_name
    result = WxPay::Service.invoke_unifiedorder content,
                                                pay_config.as_json.symbolize_keys
    if result.success?
      js_pay_params = {
          prepayid: result['prepay_id'],
          noncestr: result['nonce_str'],
          key: pay_config.key
      }
      pay_params = WxPay::Service.generate_js_pay_req(
          js_pay_params,
          appid: pay_config.appid
      )

      self.pay_data = pay_params.to_json
    else
      Rails.logger.info result.to_s
    end
  end

  def generate_payment_no
    self.payment_no = "WXPUB-#{order.order_no}-#{Time.now.to_i.to_s[5, 10]}"
  end

  def to_api_json
    {
        id: id,
        order_id: order_id,
        pay_data: pay_data
    }
  end

  def self.generate(options={})
    openid = options.delete(:openid)
    cfg = options.delete :pay_config_name

    pay_config = WxpubPayConfig.fetch cfg
    options[:pay_res_id] = pay_config.id

    payment = self.new options
    payment.fill_pay_data(openid, cfg)

    payment
  end

  def notify_verify?(notify_params)
    WxPay::Sign.verify?(notify_params) &&
        notify_params[:return_code] == TRADE_SUCCESS_CODE &&
        notify_params[:result_code] == TRADE_SUCCESS_CODE
  end


end