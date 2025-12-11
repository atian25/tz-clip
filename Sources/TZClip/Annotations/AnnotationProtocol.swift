import Cocoa

protocol Annotation {
    var id: UUID { get }
    var type: AnnotationType { get }
    var color: NSColor { get set }
    var lineWidth: CGFloat { get set }
    var bounds: CGRect { get }
    func draw(in context: CGContext)
    func contains(point: CGPoint) -> Bool
    func move(by translation: CGPoint) -> Annotation
}
