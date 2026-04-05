defmodule FounderPad.Content.PostTag do
  use Ash.Resource,
    domain: FounderPad.Content,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("blog_post_tags")
    repo(FounderPad.Repo)
  end

  attributes do
    uuid_primary_key(:id)
    create_timestamp(:inserted_at)
  end

  relationships do
    belongs_to :post, FounderPad.Content.Post do
      allow_nil?(false)
    end

    belongs_to :tag, FounderPad.Content.Tag do
      allow_nil?(false)
    end
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      accept([:post_id, :tag_id])
    end
  end

  identities do
    identity(:unique_post_tag, [:post_id, :tag_id])
  end
end
