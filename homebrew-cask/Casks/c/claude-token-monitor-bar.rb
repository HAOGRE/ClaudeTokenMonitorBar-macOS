cask "claude-token-monitor-bar" do
  version "1.2.1"
  sha256 "e75eed501c1574ee9a040d54d316601d0e9812e7b8693a7d5568abcf643c256f"

  url "https://github.com/HAOGRE/ClaudeTokenMonitorBar-macOS/releases/download/v#{version}/ClaudeTokenMonitorBar-v#{version}.dmg"
  name "ClaudeTokenMonitorBar"
  desc "Menu bar monitor for Claude Code token usage and costs"
  homepage "https://github.com/HAOGRE/ClaudeTokenMonitorBar-macOS"

  livecheck do
    url :url
    regex(/^v?(\d+(?:\.\d+)+)$/i)
  end

  depends_on macos: :sonoma

  app "ClaudeTokenMonitorBar.app"
end
