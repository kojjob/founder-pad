defmodule FounderPad.Referrals do
  use Ash.Domain

  resources do
    resource FounderPad.Referrals.Referral do
      define(:create_referral, action: :create)
      define(:list_referrals, action: :read)
      define(:get_referral_by_code, action: :by_code, args: [:code])
      define(:list_referrals_by_referrer, action: :by_referrer, args: [:referrer_id])
      define(:complete_referral, action: :complete)
    end
  end
end
