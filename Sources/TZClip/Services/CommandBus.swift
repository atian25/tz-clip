import Cocoa

class CommandBus {
    let getImage: () -> NSImage?
    let onUndo: () -> Void
    let onRedo: () -> Void
    let onDeleteSelected: () -> Void
    let onClose: () -> Void
    let onSave: (NSImage) -> Void
    let onCopy: (NSImage) -> Void
    let onPin: (NSImage?) -> Void
    let onOCR: (NSImage?) -> Void
    let onScrollShot: (NSImage?) -> Void

    init(getImage: @escaping () -> NSImage?, onUndo: @escaping () -> Void, onRedo: @escaping () -> Void, onDeleteSelected: @escaping () -> Void, onClose: @escaping () -> Void, onSave: @escaping (NSImage) -> Void, onCopy: @escaping (NSImage) -> Void, onPin: @escaping (NSImage?) -> Void, onOCR: @escaping (NSImage?) -> Void, onScrollShot: @escaping (NSImage?) -> Void) {
        self.getImage = getImage
        self.onUndo = onUndo
        self.onRedo = onRedo
        self.onDeleteSelected = onDeleteSelected
        self.onClose = onClose
        self.onSave = onSave
        self.onCopy = onCopy
        self.onPin = onPin
        self.onOCR = onOCR
        self.onScrollShot = onScrollShot
    }

    convenience init(getImage: @escaping () -> NSImage?, onUndo: @escaping () -> Void, onClose: @escaping () -> Void, onSave: @escaping (NSImage) -> Void, onCopy: @escaping (NSImage) -> Void) {
        self.init(getImage: getImage, onUndo: onUndo, onRedo: {}, onDeleteSelected: {}, onClose: onClose, onSave: onSave, onCopy: onCopy, onPin: { _ in }, onOCR: { _ in }, onScrollShot: { _ in })
    }

    func execute(action: ToolbarAction) {
        switch action {
        case .undo:
            onUndo()
        case .redo:
            onRedo()
        case .delete:
            onDeleteSelected()
        case .close:
            onClose()
        case .save:
            guard let image = getImage() else { return }
            onSave(image)
        case .copy:
            guard let image = getImage() else { return }
            onCopy(image)
        }
    }
    func executeApp(_ command: AppCommand) {
        let image = getImage()
        switch command {
        case .pin:
            onPin(image)
        case .ocr:
            onOCR(image)
        case .scrollShot:
            onScrollShot(image)
        }
    }
}
