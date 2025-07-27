struct SillySet<Element: Hashable & Comparable>: SortedSet, RandomAccessCollection {
    typealias Indices = CountableRange<Int>

    class Storage {
        var v: [Element]
        var s: Set<Element>
        var extras: Set<Element> = []
    
        init(_ v: [Element]) { 
            self.v = v
            self.s = Set(v) 
        }
    
        func commit() {
            guard !extras.isEmpty else { return }
            s.formUnion(extras)
            v += extras
            v.sort()
            extras = []
        }
    }

    private var storage = Storage([])
    
    var startIndex: Int { return 0 }
    
    var endIndex: Int { return storage.s.count + storage.extras.count }
    
    // 复杂度：`O(n*log(n))`，此处 `n` 是从上一次 `subscript` 被调用以来插入被调用的次数。
    subscript(i: Int) -> Element {
        storage.commit()
        return storage.v[i]
    }
    
    // 复杂度：O(1)
    func contains(_ element: Element) -> Bool {
        return storage.s.contains(element) || storage.extras.contains(element)
    }
    
    // 复杂度：除非存储是共享的，否则为 O(1)
    mutating func insert(_ element: Element) -> (inserted: Bool, memberAfterInsert: Element) {
        if !isKnownUniquelyReferenced(&storage) {
            storage = Storage(storage.v)
        }
        if let i = storage.s.index(of: element) { return (false, storage.s[i]) }
        return storage.extras.insert(element)
    }
}
