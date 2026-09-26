# frozen_string_literal: true

# Data that comes directly from the repo and is hardcoded
module Repo
  def self.build_repo
    {
      BagSlots: [
        {},
        { IsOverworld: true },
        { IsMedicine: true },
        { IsCandy: true },
        { IsEvolution: true },
        { IsTM: true },
        { IsOverworld: true },
        { IsOverworld: true },
        { IsOverworld: true },
        { IsBerry: true, IsHeld: true },
        { IsGem: true, IsHeld: true },
        { IsHerb: true, IsHeld: true },
        { IsClothing: true, IsHeld: true },
        { IsHeld: true },
        { IsPokeball: true },
        { CanSell: true },
        { CanTrade: true }
      ]
    }
  end
end
