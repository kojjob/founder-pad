defmodule FounderPad.ApiKeys do
  use Ash.Domain

  resources do
    resource FounderPad.ApiKeys.ApiKey do
      define(:create_api_key, action: :create)
      define(:revoke_api_key, action: :revoke)
      define(:touch_api_key_last_used, action: :touch_last_used)
      define(:list_active_keys, action: :active)
      define(:list_keys_by_organisation, action: :by_organisation, args: [:organisation_id])
      define(:find_key_by_hash, action: :by_key_hash, args: [:hash])
    end

    resource FounderPad.ApiKeys.ApiKeyUsage do
      define(:create_usage, action: :create)
      define(:list_usage_by_key, action: :by_key, args: [:api_key_id])
    end
  end
end
