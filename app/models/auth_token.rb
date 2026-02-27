class AuthToken < ApplicationRecord
  belongs_to :application
  
  validates :token, presence: true
  validates :request_id, presence: true, uniqueness: true
  
  # auth_data is already stored as text in database, Rails will handle JSON automatically
  # No need for serialize - just access it as Hash
  
  def used?
    used_at.present?
  end
  
  def mark_as_used!
    update!(used_at: Time.current)
  end
  
  # Override auth_data getter to parse stored data
  def auth_data
    data = read_attribute(:auth_data)
    
    # If already a Hash, return with string keys
    if data.is_a?(Hash)
      return data.deep_stringify_keys
    end
    
    return {} if data.nil? || data.empty?
    
    # Try to parse as JSON first
    begin
      return JSON.parse(data)
    rescue JSON::ParserError
      # If JSON parse fails, try to eval Ruby hash string (legacy format)
      begin
        # Use eval safely with binding - only for hash strings
        if data.start_with?('{') && data.include?('=>')
          parsed = eval(data)
          return parsed.deep_stringify_keys if parsed.is_a?(Hash)
        end
      rescue => e
        Rails.logger.error "Failed to parse auth_data: #{e.message}"
      end
    end
    
    {} # Return empty hash if all parsing fails
  end
  
  # Override auth_data setter to convert Hash to JSON string
  def auth_data=(value)
    write_attribute(:auth_data, value.is_a?(String) ? value : value.to_json)
  end
end
