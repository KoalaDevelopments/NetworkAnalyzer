# 0.1.0

* Initial scaffold: `NetworkAnalyzer` facade delegating to the registered
  platform implementation, endorsing `network_analyzer_android` and
  `network_analyzer_ios`.
* Bootstrap probe `getBridgeInfo()` returning `Result<BridgeInfo, Failure>`.
