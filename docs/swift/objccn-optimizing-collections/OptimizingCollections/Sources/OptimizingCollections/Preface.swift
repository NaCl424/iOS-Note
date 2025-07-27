#if os(macOS) || os(iOS) || os(watchOS) || os(tvOS)
import Darwin // 为了支持 arc4random_uniform()
#elseif os(Linux)
import Glibc // 为了支持 random()
#endif

extension Sequence {
    public func shuffled() -> [Iterator.Element] {
        var contents = Array(self)
        for i in 0 ..< contents.count - 1 {
            #if os(macOS) || os(iOS) || os(watchOS) || os(tvOS)
                // FIXME: 数组元素数量超过 2^32 时会挂
                let j = i + Int(arc4random_uniform(UInt32(contents.count - i)))
            #elseif os(Linux)
                // FIXME: 这里存在模偏差（modulo bias）的问题。 
                // 另外，应该通过调用 `srandom` 来为 `random` 配置随机种子。
                let j = i + random() % (contents.count - i)
            #endif
            if i != j {
                contents.swapAt(i, j)
            }
        }
        return contents
    }
}
