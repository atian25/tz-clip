import Cocoa

struct ToolConfig {
    var color: NSColor = .red
    var lineWidth: CGFloat = 4
    var isBold: Bool = false
    var isFilled: Bool = false
    var isRounded: Bool = false
    var outlineStyle: Int = 0
    var outlineColor: NSColor = .black
    var fontName: String = "System Default"
    var textBackgroundColor: NSColor? = nil
}

struct ToolState {
    var currentTool: AnnotationType = .select
    private var configs: [AnnotationType: ToolConfig] = [:]
    
    mutating func setConfig(_ cfg: ToolConfig, for tool: AnnotationType) {
        configs[tool] = cfg
    }
    func config(for tool: AnnotationType) -> ToolConfig {
        if let c = configs[tool] { return c }
        var cfg = ToolConfig()
        if tool == .text || tool == .counter { cfg.lineWidth = 18 }
        return cfg
    }
    mutating func updateCurrent(_ apply: (inout ToolConfig) -> Void) {
        var cfg = config(for: currentTool)
        apply(&cfg)
        setConfig(cfg, for: currentTool)
    }
}
