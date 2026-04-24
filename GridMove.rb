cask "gridmove" do
  version "1.6.6"
  sha256 "ca0432cf04fdb069aa22a25c3434a6292a1b3d0decd73ef2c7b08968afcd4b32"

  url "https://github.com/mirtlecn/GridMoveForMac/releases/download/v#{version}/GridMove.arm64.dmg",
      verified: "github.com/mirtlecn/GridMoveForMac/releases/download/"
  name "GridMove"
  desc "Move and snap windows into custom layouts"
  homepage "https://github.com/mirtlecn/GridMoveForMac"

  livecheck do
    url :url
    strategy :github_latest
  end

  depends_on arch: :arm64
  depends_on macos: ">= :sonoma"

  app "GridMove.app"

  zap trash: [
    "~/.config/GridMove",
  ]

  caveats do
    unsigned_accessibility
  end
end
