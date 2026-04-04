defmodule FounderPad.System do
  use Ash.Domain

  resources do
    resource FounderPad.System.Incident do
      define :create_incident, action: :create
      define :update_incident, action: :update
      define :resolve_incident, action: :resolve
      define :list_active_incidents, action: :active
      define :list_recent_incidents, action: :recent
    end
  end
end
