cask "gridmove" do
  version "1.6.5"
  sha256 "c26ab51e2659902d5166023ff3765b93ee697cd0188da3e0de83c070e1233165"

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
