require 'wormhole'

module Fatboy
  class Wormhole

    def initialize
      @credentials = {}
      @mutex = Mutex.new
    end

    def resolve(id_or_alias)
      case id_or_alias
      when /^\d+$/
        id_or_alias
      else
        id = ::Wormhole::KNOWN_ACCOUNTS[id_or_alias]
        id or raise "Unknown AWS account #{id_or_alias.inspect}"
      end
    end

    def get_credentials(account_id)
      @mutex.synchronize do
        @credentials[account_id] ||= ::Wormhole::AWSSDKV2Credentials.new(account_id: account_id)
      end
    end

    def resolve_and_get_credentials(id_or_alias)
      get_credentials(resolve(id_or_alias))
    end

  end
end
