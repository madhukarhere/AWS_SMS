# frozen_string_literal: true

class Aws_Sms
  attr_accessor :region, :access_key_id, :secret_access_key, :message, :phone_number, :sender_id,
                :acknowledgement, :delivery_status, :errors

  def initialize(region:, access_key_id:, secret_access_key:)
    self.region = region
    self.access_key_id = access_key_id
    self.secret_access_key = secret_access_key
    self.region = region || 'us-west-2'

    @sns_client = Aws::SNS::Client.new(region: self.region, access_key_id: self.access_key_id,
                                       secret_access_key: self.secret_access_key)
    self.delivery_status = false
    self.acknowledgement = "0"
    self.sender_id = 'AWS-SMS'
  end

  def send_SMS(phone_number:, message:)
    errors = []
    self.phone_number = phone_number
    self.message = message
    errors << 'Message cannot be blank' if message.blank?
    errors << 'Phone number cannot be blank' if phone_number.blank?
    errors << 'access_key_id not initialized' if access_key_id.blank?
    errors << 'secret_access_key not initialized' if secret_access_key.blank?
    errors << 'region not initialized' if region.blank?

    if phone_number.present?
      result, error = validate_phone_number(phone_number)
      errors << error unless result
    end

    if errors.count.positive?
      self.errors = errors
      return false
    end

    begin
      response = @sns_client.publish(phone_number: self.phone_number, message: self.message)
      if response.error.blank?
        self.delivery_status = true
        self.acknowledgement = response.message_id
      else
        self.errors = response.error
      end
    rescue StandardError => ex
      self.errors = ex
    end
    [delivery_status, self.errors]
  end

  private

  def validate_phone_number(phone_number)
    pinpoint = Aws::Pinpoint::Client.new
    query = { number_validate_request: { phone_number: phone_number } }
    response = pinpoint.phone_number_validate(query).number_validate_response.phone_type
    return [true, nil] if response == 'MOBILE'
    return [false, 'Invalid phone number'] if response == 'INVALID'
    [false, 'It is not a mobile number. SMS can be delivered only to valid mobile number']
  end
end

